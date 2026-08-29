// SPDX-License-Identifier: MPL-2.0

import Foundation

enum SyncCoordinatorError: LocalizedError {
    case notConfigured
    case invalidLookback
    case invalidUploadAttempts
    case unexpectedOutcome

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            String(localized: "Pair the app before syncing.")
        case .invalidLookback:
            String(localized: "Sync history must be between one and seven days.")
        case .invalidUploadAttempts:
            String(localized: "Upload attempts must be between one and ten.")
        case .unexpectedOutcome:
            String(localized: "The server could not confirm the daily update.")
        }
    }
}

struct SyncConfiguration: Sendable {
    let baseURL: URL
    let credential: String
    let installationID: String
}

enum SyncPlanner {
    static func nextPending(
        summary: DaySummary,
        confirmed: ConfirmedDayState?
    ) throws -> PendingDay? {
        let digest = try summary.contentDigest()
        if digest == confirmed?.contentDigest {
            return nil
        }
        return PendingDay(summary: summary.normalized, revision: (confirmed?.revision ?? 0) + 1)
    }
}

actor SyncCoordinator {
    private let health: any HealthDataReading
    private let transport: any HealthTransport
    private let stateStore: SyncStateStore
    private let outbox: ProtectedOutbox
    private var configuration: SyncConfiguration?
    private var running = false

    init(
        health: any HealthDataReading,
        transport: any HealthTransport = APIClient(),
        stateStore: SyncStateStore = SyncStateStore(),
        outbox: ProtectedOutbox,
        configuration: SyncConfiguration? = nil
    ) {
        self.health = health
        self.transport = transport
        self.stateStore = stateStore
        self.outbox = outbox
        self.configuration = configuration
    }

    func configure(_ configuration: SyncConfiguration) {
        self.configuration = configuration
    }

    func synchronize(
        referenceDate: Date = Date(),
        lookbackDays: Int = 3,
        maxUploadAttempts: Int = 10,
        stopAfterPendingRecovery: Bool = false
    ) async -> [DaySyncResult] {
        guard let configuration else {
            return [
                DaySyncResult(
                    localDate: AppDate.localDate(referenceDate),
                    outcome: .failed,
                    message: SyncCoordinatorError.notConfigured.localizedDescription
                )
            ]
        }
        guard (1 ... 7).contains(lookbackDays) else {
            return [
                DaySyncResult(
                    localDate: AppDate.localDate(referenceDate),
                    outcome: .failed,
                    message: SyncCoordinatorError.invalidLookback.localizedDescription
                )
            ]
        }
        guard (1 ... 10).contains(maxUploadAttempts) else {
            return [
                DaySyncResult(
                    localDate: AppDate.localDate(referenceDate),
                    outcome: .failed,
                    message: SyncCoordinatorError.invalidUploadAttempts.localizedDescription
                )
            ]
        }
        guard !running else { return [] }
        running = true
        defer { running = false }

        var results: [DaySyncResult] = []
        for offset in 0 ..< lookbackDays {
            let dayStart = AppDate.addingDays(-offset, to: referenceDate)
            results.append(
                await synchronizeDay(
                    dayStart,
                    configuration: configuration,
                    maxUploadAttempts: maxUploadAttempts,
                    stopAfterPendingRecovery: stopAfterPendingRecovery
                )
            )
        }
        return results
    }

    func enableBackgroundDelivery() async throws {
        guard configuration != nil else {
            throw SyncCoordinatorError.notConfigured
        }
        try await health.enableBackgroundDelivery()
    }

    func disconnect() async throws {
        configuration = nil
        await health.stopObservers()
        try await outbox.clear()
        await stateStore.clear()
    }

    private func synchronizeDay(
        _ dayStart: Date,
        configuration: SyncConfiguration,
        maxUploadAttempts: Int,
        stopAfterPendingRecovery: Bool
    ) async -> DaySyncResult {
        let localDate = AppDate.localDate(dayStart)
        var resumedOutcome: DaySyncResult.Outcome?
        do {
            if let pending = try await outbox.pending(for: localDate) {
                let resumed = try await upload(
                    pending,
                    configuration: configuration,
                    maxAttempts: maxUploadAttempts
                )
                resumedOutcome = resumed.outcome
                try await confirm(resumed.pending)
                if stopAfterPendingRecovery {
                    return DaySyncResult(
                        localDate: localDate,
                        outcome: resumed.outcome,
                        message: nil
                    )
                }
            }

            let summary = await health.readDay(dayStart)
            let confirmed = await stateStore.state(for: localDate)
            guard let pending = try SyncPlanner.nextPending(
                summary: summary,
                confirmed: confirmed
            ) else {
                return DaySyncResult(
                    localDate: localDate,
                    outcome: resumedOutcome ?? .unchanged,
                    message: nil
                )
            }

            try await outbox.save(pending)
            let uploaded = try await upload(
                pending,
                configuration: configuration,
                maxAttempts: maxUploadAttempts
            )
            try await confirm(uploaded.pending)
            return DaySyncResult(localDate: localDate, outcome: uploaded.outcome, message: nil)
        } catch {
            let queued = (try? await outbox.pending(for: localDate)) != nil
            return DaySyncResult(
                localDate: localDate,
                outcome: queued ? .queued : .failed,
                message: queued
                    ? String(localized: "Queued on this iPhone after sync failed. FitKiku will retry when it gets another opportunity.")
                    : String(localized: "Sync failed before the update could be queued. Open FitKiku and try again.")
            )
        }
    }

    private func upload(
        _ pending: PendingDay,
        configuration: SyncConfiguration,
        maxAttempts: Int
    ) async throws -> (pending: PendingDay, outcome: DaySyncResult.Outcome) {
        var candidate = pending
        for attempt in 0 ..< maxAttempts {
            let outcome = try await send(candidate, configuration: configuration)
            switch outcome {
            case "created":
                return (candidate, .created)
            case "replaced":
                return (candidate, .replaced)
            case "duplicate":
                return (candidate, .duplicate)
            case "stale_revision":
                guard candidate.revision <= Int.max / 2 else {
                    throw SyncCoordinatorError.unexpectedOutcome
                }
                candidate = PendingDay(
                    summary: candidate.summary,
                    revision: max(candidate.revision + 1, candidate.revision * 2)
                )
                try await outbox.save(candidate)
                if attempt == maxAttempts - 1 {
                    throw SyncCoordinatorError.unexpectedOutcome
                }
            default:
                throw SyncCoordinatorError.unexpectedOutcome
            }
        }
        throw SyncCoordinatorError.unexpectedOutcome
    }

    private func send(
        _ pending: PendingDay,
        configuration: SyncConfiguration
    ) async throws -> String {
        let unsigned = try pending.summary.unsignedSnapshot(
            installationID: configuration.installationID,
            revision: pending.revision,
            generatedAt: Date()
        )
        let signed = try SnapshotSigner.sign(unsigned, credential: configuration.credential)
        return try await transport.ingest(
            baseURL: configuration.baseURL,
            credential: configuration.credential,
            snapshot: signed
        )
    }

    private func confirm(_ pending: PendingDay) async throws {
        let digest = try pending.summary.contentDigest()
        try await stateStore.confirm(
            ConfirmedDayState(contentDigest: digest, revision: pending.revision),
            for: pending.summary.localDate
        )
        try await outbox.remove(localDate: pending.summary.localDate)
    }
}
