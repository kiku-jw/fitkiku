// SPDX-License-Identifier: MPL-2.0

import XCTest
@testable import FitKiku

private actor FakeHealthReader: HealthDataReading {
    func requestAuthorization() async throws {}

    func readDay(_ dayStart: Date) async -> DaySummary {
        DaySummary(
            localDate: AppDate.localDate(dayStart),
            steps: 3210,
            stepsCoverage: .complete,
            sleepIntervals: [],
            sleepCoverage: .unknown,
            sources: []
        )
    }

    nonisolated func installObservers(onChange _: @escaping @Sendable () async -> Void) {}
    func enableBackgroundDelivery() async throws {}
    func stopObservers() async {}
}

private actor LostResponseTransport: HealthTransport {
    private let lostDate: String
    private var didLoseResponse = false
    private var captured: [HealthSnapshotPayload] = []

    init(lostDate: String) {
        self.lostDate = lostDate
    }

    func pair(baseURL _: URL, code _: String, installationID _: String) async throws -> String {
        "credential"
    }

    func ingest(
        baseURL _: URL,
        credential _: String,
        snapshot: HealthSnapshotPayload
    ) async throws -> String {
        captured.append(snapshot)
        if snapshot.localDate == lostDate, !didLoseResponse {
            didLoseResponse = true
            throw APIClientError.transport
        }
        return snapshot.localDate == lostDate ? "duplicate" : "created"
    }

    func snapshots(for localDate: String) -> [HealthSnapshotPayload] {
        captured.filter { $0.localDate == localDate }
    }
}

private actor StaleRevisionTransport: HealthTransport {
    private let staleDate: String
    private var captured: [HealthSnapshotPayload] = []

    init(staleDate: String) {
        self.staleDate = staleDate
    }

    func pair(baseURL _: URL, code _: String, installationID _: String) async throws -> String {
        "credential"
    }

    func ingest(
        baseURL _: URL,
        credential _: String,
        snapshot: HealthSnapshotPayload
    ) async throws -> String {
        captured.append(snapshot)
        if snapshot.localDate == staleDate, snapshot.syncRevision < 16 {
            return "stale_revision"
        }
        return "created"
    }

    func revisions(for localDate: String) -> [Int] {
        captured.filter { $0.localDate == localDate }.map(\.syncRevision)
    }
}

private final class ObserverEventProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [String] = []

    func record(_ event: String) {
        lock.lock()
        events.append(event)
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}

final class SyncCoordinatorTests: XCTestCase {
    func testHealthObserverCompletesAfterSuccessfulCatchUp() async {
        let probe = ObserverEventProbe()

        HealthObserverUpdateHandler.handle(
            error: nil,
            onChange: { probe.record("change") },
            completion: { probe.record("completion") }
        )

        for _ in 0 ..< 100 where probe.snapshot().count < 2 {
            await Task.yield()
        }
        XCTAssertEqual(probe.snapshot(), ["change", "completion"])
    }

    func testHealthObserverErrorCompletesWithoutRunningCatchUp() {
        let probe = ObserverEventProbe()

        HealthObserverUpdateHandler.handle(
            error: APIClientError.transport,
            onChange: { probe.record("change") },
            completion: { probe.record("completion") }
        )

        XCTAssertEqual(probe.snapshot(), ["completion"])
    }

    func testLookbackRejectsMoreThanSevenDaysBeforeHealthReadOrUpload() async throws {
        let reference = try XCTUnwrap(AppDate.parseTimestamp("2026-08-02T12:00:00Z"))
        let localDate = AppDate.localDate(reference)
        let transport = LostResponseTransport(lostDate: localDate)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let suiteName = "FitKikuTests.\(UUID().uuidString)"
        defer {
            try? FileManager.default.removeItem(at: directory)
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        let coordinator = SyncCoordinator(
            health: FakeHealthReader(),
            transport: transport,
            stateStore: SyncStateStore(suiteName: suiteName, storageKey: "confirmed"),
            outbox: try ProtectedOutbox(directory: directory)
        )
        await coordinator.configure(
            SyncConfiguration(
                baseURL: try XCTUnwrap(URL(string: "https://fitkiku.example")),
                credential: "synthetic-credential",
                installationID: "fixture-installation-0001"
            )
        )

        let result = await coordinator.synchronize(referenceDate: reference, lookbackDays: 8)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.outcome, .failed)
        XCTAssertTrue(result.first?.message?.contains("between one and seven days") == true)
        let uploadAttempts = await transport.snapshots(for: localDate)
        XCTAssertTrue(uploadAttempts.isEmpty)
    }

    func testOutboxWriteFailureReportsPreQueueFailureWithoutUpload() async throws {
        let reference = try XCTUnwrap(AppDate.parseTimestamp("2026-08-02T12:00:00Z"))
        let localDate = AppDate.localDate(reference)
        let transport = LostResponseTransport(lostDate: localDate)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let suiteName = "FitKikuTests.\(UUID().uuidString)"
        defer {
            try? FileManager.default.removeItem(at: directory)
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        let outbox = try ProtectedOutbox(directory: directory)
        try FileManager.default.removeItem(at: directory)
        try Data().write(to: directory)
        let coordinator = SyncCoordinator(
            health: FakeHealthReader(),
            transport: transport,
            stateStore: SyncStateStore(suiteName: suiteName, storageKey: "confirmed"),
            outbox: outbox
        )
        await coordinator.configure(
            SyncConfiguration(
                baseURL: try XCTUnwrap(URL(string: "https://fitkiku.example")),
                credential: "synthetic-credential",
                installationID: "fixture-installation-0001"
            )
        )

        let result = await coordinator.synchronize(referenceDate: reference, lookbackDays: 1)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.outcome, .failed)
        XCTAssertTrue(result.first?.message?.contains("before the update could be queued") == true)
        let uploadAttempts = await transport.snapshots(for: localDate)
        XCTAssertTrue(uploadAttempts.isEmpty)
    }

    func testLostResponseRetriesSameRevisionAndIdempotencyKey() async throws {
        let reference = try XCTUnwrap(AppDate.parseTimestamp("2026-08-02T12:00:00Z"))
        let lostDate = AppDate.localDate(reference)
        let transport = LostResponseTransport(lostDate: lostDate)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let suiteName = "FitKikuTests.\(UUID().uuidString)"
        defer {
            try? FileManager.default.removeItem(at: directory)
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        let outbox = try ProtectedOutbox(directory: directory)
        let coordinator = SyncCoordinator(
            health: FakeHealthReader(),
            transport: transport,
            stateStore: SyncStateStore(suiteName: suiteName, storageKey: "confirmed"),
            outbox: outbox
        )
        await coordinator.configure(
            SyncConfiguration(
                baseURL: try XCTUnwrap(URL(string: "https://fitkiku.example")),
                credential: "synthetic-credential",
                installationID: "fixture-installation-0001"
            )
        )

        let first = await coordinator.synchronize(referenceDate: reference)
        XCTAssertEqual(first.first?.outcome, .queued)
        XCTAssertTrue(first.first?.message?.contains("Queued on this iPhone") == true)
        let queuedPending = try await outbox.pending(for: lostDate)
        XCTAssertNotNil(queuedPending)
        let second = await coordinator.synchronize(referenceDate: reference)
        XCTAssertEqual(second.first?.outcome, .duplicate)
        let clearedPending = try await outbox.pending(for: lostDate)
        XCTAssertNil(clearedPending)

        let attempts = await transport.snapshots(for: lostDate)
        XCTAssertEqual(attempts.count, 2)
        XCTAssertEqual(attempts[0].syncRevision, attempts[1].syncRevision)
        XCTAssertEqual(attempts[0].idempotencyKey, attempts[1].idempotencyKey)
    }

    func testMissingLocalRevisionStateRecoversMonotonically() async throws {
        let reference = try XCTUnwrap(AppDate.parseTimestamp("2026-08-02T12:00:00Z"))
        let staleDate = AppDate.localDate(reference)
        let transport = StaleRevisionTransport(staleDate: staleDate)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let suiteName = "FitKikuTests.\(UUID().uuidString)"
        defer {
            try? FileManager.default.removeItem(at: directory)
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        let coordinator = SyncCoordinator(
            health: FakeHealthReader(),
            transport: transport,
            stateStore: SyncStateStore(suiteName: suiteName, storageKey: "confirmed"),
            outbox: try ProtectedOutbox(directory: directory)
        )
        await coordinator.configure(
            SyncConfiguration(
                baseURL: try XCTUnwrap(URL(string: "https://fitkiku.example")),
                credential: "synthetic-credential",
                installationID: "fixture-installation-0001"
            )
        )

        let results = await coordinator.synchronize(referenceDate: reference)
        XCTAssertEqual(results.first?.outcome, .created)
        let revisions = await transport.revisions(for: staleDate)
        XCTAssertEqual(revisions, [1, 2, 4, 8, 16])
    }
}
