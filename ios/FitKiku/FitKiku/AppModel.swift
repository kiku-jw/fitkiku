// SPDX-License-Identifier: MPL-2.0

import Combine
import Foundation
import UIKit

@MainActor
final class AppModel: ObservableObject {
    @Published var serverAddress: String
    @Published var pairingCode = ""
    @Published private(set) var pendingAgentConsent: PendingAgentConsent?
    @Published private(set) var pendingLegacyPairing: PendingLegacyPairing?
    @Published private(set) var isPaired = false
    @Published private(set) var localCredentialCleanupPending = false
    @Published private(set) var healthAccessRequested = false
    @Published private(set) var isBusy = false
    @Published private(set) var today: DaySummary?
    @Published private(set) var yesterday: DaySummary?
    @Published private(set) var lastResults: [DaySyncResult] = []
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var deliveryStatus: DeviceDeliveryStatus?
    @Published private(set) var deliveryStatusError: String?
    @Published private(set) var privateShareURL: URL?
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?

    private enum DefaultsKey {
        static let serverAddress = "healthkit.server-address"
        static let healthAccessRequested = "healthkit.access-requested"
        static let lastSyncAt = "healthkit.last-sync-at"
        static let localCredentialCleanupPending = "healthkit.local-credential-cleanup-pending"
    }

    private let defaults: UserDefaults
    private let keychain: KeychainStore
    private let deleteCredential: () throws -> Void
    private let transport: any AppTransport
    private let health: (any HealthDataReading)?
    private let coordinator: SyncCoordinator?
    private let protectedDataAvailable: @Sendable () async -> Bool
    private let setupError: String?
    private let syntheticDemoRuntime: Bool
    private var restored = false
    private var observersInstalled = false

    private static let hostedServiceURL = URL(string: "https://fitkiku-origin.kikuai.dev")!

    var isSyntheticDemo: Bool { syntheticDemoRuntime }
    var canDeleteAccount: Bool { isPaired && deliveryStatus?.canDeleteAccount == true }
    var demoScrollTarget: String?
    var shouldExpandDeliveryForDemo = false

    #if DEBUG
    private init(syntheticDemoDefaults defaults: UserDefaults) {
        self.defaults = defaults
        keychain = KeychainStore(service: "com.kikuai.fitkiku.synthetic-demo")
        deleteCredential = {}
        transport = SyntheticDemoTransport()
        health = nil
        coordinator = nil
        protectedDataAvailable = { true }
        setupError = nil
        syntheticDemoRuntime = true
        serverAddress = ""
    }
    #endif

    init(
        defaults: UserDefaults = .standard,
        keychain: KeychainStore = KeychainStore(),
        credentialCleanup: (() throws -> Void)? = nil,
        transport: any AppTransport = APIClient(),
        healthReader: (any HealthDataReading)? = nil,
        outbox: ProtectedOutbox? = nil,
        stateStore: SyncStateStore? = nil,
        installHealthObserversAtLaunch: Bool = true,
        protectedDataAvailable: @escaping @Sendable () async -> Bool = {
            await MainActor.run { UIApplication.shared.isProtectedDataAvailable }
        }
    ) {
        self.defaults = defaults
        self.keychain = keychain
        deleteCredential = credentialCleanup ?? { try keychain.deleteCredential() }
        self.transport = transport
        self.protectedDataAvailable = protectedDataAvailable
        syntheticDemoRuntime = false
        let storedServerAddress = defaults.string(forKey: DefaultsKey.serverAddress) ?? ""
        serverAddress = storedServerAddress

        do {
            let health: any HealthDataReading
            if let healthReader {
                health = healthReader
            } else {
                health = try HealthKitClient()
            }
            let outbox = try outbox ?? ProtectedOutbox()
            self.health = health
            let coordinator = SyncCoordinator(
                health: health,
                transport: transport,
                stateStore: stateStore ?? SyncStateStore(),
                outbox: outbox,
                configuration: defaults.bool(
                    forKey: DefaultsKey.localCredentialCleanupPending
                )
                    ? nil
                    : Self.launchConfiguration(
                        keychain: keychain,
                        serverAddress: storedServerAddress
                    )
            )
            self.coordinator = coordinator
            setupError = nil
            if installHealthObserversAtLaunch {
                Self.installObservers(
                    health: health,
                    coordinator: coordinator,
                    protectedDataAvailable: protectedDataAvailable
                )
                observersInstalled = true
            }
        } catch {
            health = nil
            coordinator = nil
            setupError = error.localizedDescription
        }
    }

    func restore() async {
        guard !syntheticDemoRuntime else { return }
        if restored {
            await refreshAfterForeground()
            return
        }
        restored = true
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil
        localCredentialCleanupPending = defaults.bool(
            forKey: DefaultsKey.localCredentialCleanupPending
        )
        if localCredentialCleanupPending {
            await retryLocalCredentialCleanup()
            guard !localCredentialCleanupPending else {
                restored = false
                return
            }
        }
        if let setupError {
            errorMessage = setupError
            return
        }
        healthAccessRequested = defaults.bool(forKey: DefaultsKey.healthAccessRequested)
        lastSyncAt = defaults.object(forKey: DefaultsKey.lastSyncAt) as? Date
        do {
            guard let credential = try keychain.credential(),
                  !serverAddress.isEmpty,
                  let coordinator
            else {
                return
            }
            let baseURL = try APIClient.validatedBaseURL(serverAddress)
            let installationID = try keychain.installationID()
            await coordinator.configure(
                SyncConfiguration(
                    baseURL: baseURL,
                    credential: credential,
                    installationID: installationID
                )
            )
            isPaired = true
            privateShareURL = try keychain.privateShareURL()
            if healthAccessRequested {
                await registerObservers()
            }
            await refreshDeliveryStatus()
            if healthAccessRequested {
                await refreshSummaries()
                await syncNow()
            }
        } catch {
            restored = false
            errorMessage = error.localizedDescription
        }
    }

    func openPairLink(_ url: URL) async {
        await loadPairingInput(url.absoluteString)
    }

    func beginHostedConnection() async {
        guard !localCredentialCleanupPending else {
            errorMessage = String(localized: "Finish removing the revoked local credential before connecting again.")
            return
        }
        guard !isPaired, !isBusy else { return }
        clearPendingPairing()
        isBusy = true
        errorMessage = nil
        statusMessage = nil
        defer { isBusy = false }

        do {
            let link = try await transport.issuePublicAgentGrant(
                baseURL: Self.hostedServiceURL,
                agentName: String(localized: "FitKiku private ChatGPT link")
            )
            let preview = try await transport.previewAgentGrant(
                baseURL: link.baseURL,
                pairingToken: link.pairingToken
            )
            pendingAgentConsent = PendingAgentConsent(
                baseURL: link.baseURL,
                pairingToken: link.pairingToken,
                preview: preview,
                createsPrivateShareLink: true
            )
            statusMessage = String(localized: "Review the private read-only connection before approving.")
        } catch {
            clearPendingPairing()
            errorMessage = error.localizedDescription
        }
    }

    func loadPairingInput(_ value: String) async {
        guard !localCredentialCleanupPending else {
            errorMessage = String(localized: "Finish removing the revoked local credential before connecting again.")
            return
        }
        guard !isPaired else {
            errorMessage = String(localized: "Disconnect the current server before opening another Pair Link.")
            return
        }
        guard !isBusy else { return }
        clearPendingPairing()
        isBusy = true
        errorMessage = nil
        statusMessage = nil
        defer { isBusy = false }

        do {
            guard let payload = try PairingPayload.parse(value) else {
                throw PairingPayloadError.invalidPayload
            }
            switch payload {
            case let .agent(link):
                let preview = try await transport.previewAgentGrant(
                    baseURL: link.baseURL,
                    pairingToken: link.pairingToken
                )
                pendingAgentConsent = PendingAgentConsent(
                    baseURL: link.baseURL,
                    pairingToken: link.pairingToken,
                    preview: preview,
                    createsPrivateShareLink: false
                )
                statusMessage = String(localized: "Review the claimed agent and disclosures before approving.")
            case let .legacy(link):
                pendingLegacyPairing = PendingLegacyPairing(
                    baseURL: link.baseURL,
                    code: link.code
                )
                statusMessage = String(localized: "A legacy recovery link was loaded. Review the server before pairing.")
            }
        } catch {
            clearPendingPairing()
            errorMessage = error.localizedDescription
        }
    }

    func cancelPendingPairing() {
        clearPendingPairing()
        errorMessage = nil
        statusMessage = String(localized: "Connection request cancelled.")
    }

    func approveAgentPairing() async {
        guard let consent = pendingAgentConsent else { return }
        guard let coordinator else {
            errorMessage = setupError ?? String(localized: "The native health client is unavailable.")
            return
        }
        isBusy = true
        errorMessage = nil
        statusMessage = nil
        defer { isBusy = false }

        do {
            let installationID = try keychain.installationID()
            let credential = try await transport.pairAgent(
                baseURL: consent.baseURL,
                pairingToken: consent.pairingToken,
                installationID: installationID,
                timezone: consent.preview.requiresTimezone == true
                    ? AppDate.timezoneIdentifier
                    : nil
            )
            try await completePairing(
                baseURL: consent.baseURL,
                credential: credential,
                installationID: installationID,
                coordinator: coordinator
            )
            clearPendingPairing()
            if consent.createsPrivateShareLink {
                do {
                    try await rotatePrivateShareLinkUsingStoredDevice()
                    statusMessage = String(localized: "Connected. Allow Apple Health next, then copy your private ChatGPT prompt.")
                } catch {
                    errorMessage = String(
                        format: String(localized: "Connected, but the private ChatGPT link could not be created. Try again below. %@"),
                        locale: Locale.current,
                        error.localizedDescription
                    )
                }
            } else {
                statusMessage = String(localized: "Connected. You can now review and grant Apple Health read access.")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createPrivateShareLink() async {
        guard isPaired, !isBusy else { return }
        isBusy = true
        errorMessage = nil
        statusMessage = nil
        defer { isBusy = false }
        do {
            try await rotatePrivateShareLinkUsingStoredDevice()
            statusMessage = String(localized: "Private ChatGPT link created. Keep it private; anyone with it can read your recent Steps and Sleep.")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revokePrivateShareLink() async {
        guard isPaired, privateShareURL != nil, !isBusy else { return }
        isBusy = true
        errorMessage = nil
        statusMessage = nil
        defer { isBusy = false }
        do {
            guard let credential = try keychain.credential() else {
                throw APIClientError.invalidResponse
            }
            let baseURL = try APIClient.validatedBaseURL(serverAddress)
            let installationID = try keychain.installationID()
            let outcome = try await transport.revokeDeviceShareLink(
                baseURL: baseURL,
                credential: credential,
                installationID: installationID
            )
            guard outcome == "revoked" else { throw APIClientError.invalidResponse }
            privateShareURL = nil
            try keychain.deletePrivateShareURL()
            statusMessage = String(localized: "Private ChatGPT link revoked. The iPhone connection remains active.")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func approveLegacyPairing() async {
        guard let pendingLegacyPairing else { return }
        await pairLegacy(
            baseURL: pendingLegacyPairing.baseURL,
            code: pendingLegacyPairing.code
        )
    }

    func pairLegacyManually() async {
        guard !localCredentialCleanupPending else {
            errorMessage = String(localized: "Finish removing the revoked local credential before connecting again.")
            return
        }
        do {
            let baseURL = try APIClient.validatedBaseURL(serverAddress)
            await pairLegacy(baseURL: baseURL, code: pairingCode)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestHealthAccess() async {
        guard let health else {
            errorMessage = setupError ?? String(localized: "Apple Health is unavailable on this device.")
            return
        }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await health.requestAuthorization()
            healthAccessRequested = true
            defaults.set(true, forKey: DefaultsKey.healthAccessRequested)
            statusMessage = isPaired
                ? String(localized: "Health access was requested. Apple keeps read-denial status private.")
                : String(localized: "Health access was requested. Connect a server later to sync.")
            await registerObservers()
            await refreshSummaries()
            if isPaired {
                isBusy = false
                await syncNow()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func syncNow() async {
        guard isPaired, healthAccessRequested, let coordinator else {
            errorMessage = String(localized: "Connect the app and request Apple Health access before syncing.")
            return
        }
        isBusy = true
        errorMessage = nil
        statusMessage = nil
        defer { isBusy = false }
        let results = await coordinator.synchronize(lookbackDays: 7)
        lastResults = results
        await refreshSummaries()
        await refreshDeliveryStatus()

        let failures = results.filter { $0.outcome == .failed }
        let queued = results.filter { $0.outcome == .queued }
        if let failure = failures.first {
            errorMessage = failure.message ?? String(localized: "Sync failed.")
        } else if let firstQueued = queued.first {
            errorMessage = firstQueued.message
                ?? String(localized: "One or more days are queued on this iPhone and will be retried.")
        } else if !results.isEmpty {
            let confirmedAt = Date()
            lastSyncAt = confirmedAt
            defaults.set(confirmedAt, forKey: DefaultsKey.lastSyncAt)
            let changed = results.filter { $0.outcome != .unchanged }.count
            statusMessage = changed == 0
                ? String(localized: "FitKiku is already up to date.")
                : String(
                    format: String(localized: "Server check: %@ days; %@ updates confirmed."),
                    locale: Locale.current,
                    String(results.count),
                    String(changed)
                )
        }
    }

    func disconnect() async {
        await endConnection(deleteServerData: false)
    }

    func deleteAccount() async {
        guard canDeleteAccount else { return }
        await endConnection(deleteServerData: true)
    }

    private func endConnection(deleteServerData: Bool) async {
        guard isPaired else { return }
        isBusy = true
        errorMessage = nil
        statusMessage = nil
        defer { isBusy = false }

        let credential: String
        let baseURL: URL
        let installationID: String
        do {
            guard let storedCredential = try keychain.credential() else {
                throw APIClientError.invalidResponse
            }
            credential = storedCredential
            baseURL = try APIClient.validatedBaseURL(serverAddress)
            installationID = try keychain.installationID()
        } catch {
            errorMessage = deleteServerData
                ? String(
                    format: String(localized: "Server data was not deleted. This iPhone remains connected; try again. %@"),
                    locale: Locale.current,
                    error.localizedDescription
                )
                : String(
                    format: String(localized: "Server access was not revoked. This iPhone remains connected; try again. %@"),
                    locale: Locale.current,
                    error.localizedDescription
                )
            return
        }

        do {
            let outcome: String
            let expectedOutcome: String
            if deleteServerData {
                outcome = try await transport.deleteAccount(
                    baseURL: baseURL,
                    credential: credential,
                    installationID: installationID
                )
                expectedOutcome = "deleted"
            } else {
                outcome = try await transport.revokeDevice(
                    baseURL: baseURL,
                    credential: credential,
                    installationID: installationID
                )
                expectedOutcome = "revoked"
            }
            guard outcome == expectedOutcome else {
                throw APIClientError.invalidResponse
            }
        } catch {
            errorMessage = deleteServerData
                ? String(
                    format: String(localized: "Server data was not deleted. This iPhone remains connected; try again. %@"),
                    locale: Locale.current,
                    error.localizedDescription
                )
                : String(
                    format: String(localized: "Server access was not revoked. This iPhone remains connected; try again. %@"),
                    locale: Locale.current,
                    error.localizedDescription
                )
            return
        }

        defaults.set(true, forKey: DefaultsKey.localCredentialCleanupPending)
        localCredentialCleanupPending = true
        isPaired = false
        clearPendingPairing()
        today = nil
        yesterday = nil
        lastResults = []
        lastSyncAt = nil
        deliveryStatus = nil
        deliveryStatusError = nil
        privateShareURL = nil
        defaults.removeObject(forKey: DefaultsKey.lastSyncAt)
        do {
            try await finishRevokedLocalCleanup()
            finishLocalCredentialCleanup()
            statusMessage = deleteServerData
                ? String(localized: "FitKiku server data and local protected data were deleted. Apple Health was unchanged.")
                : String(localized: "Server access was revoked and local protected data was removed.")
        } catch {
            errorMessage = deleteServerData
                ? String(
                    format: String(localized: "FitKiku server data was deleted. Local protected-data cleanup is still pending; retry below. %@"),
                    locale: Locale.current,
                    error.localizedDescription
                )
                : String(
                    format: String(localized: "Server access was revoked. Local protected-data cleanup is still pending; retry below. %@"),
                    locale: Locale.current,
                    error.localizedDescription
                )
        }
    }

    func retryLocalCredentialCleanup() async {
        guard localCredentialCleanupPending
            || defaults.bool(forKey: DefaultsKey.localCredentialCleanupPending)
        else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        localCredentialCleanupPending = true
        do {
            try await finishRevokedLocalCleanup()
            finishLocalCredentialCleanup()
            statusMessage = String(localized: "Local protected data for the ended connection was removed.")
        } catch {
            errorMessage = String(
                format: String(localized: "Server access has already ended, but local protected-data cleanup is still pending. %@"),
                locale: Locale.current,
                error.localizedDescription
            )
        }
    }

    private func pairLegacy(baseURL: URL, code: String) async {
        guard let coordinator else {
            errorMessage = setupError ?? String(localized: "The native health client is unavailable.")
            return
        }
        isBusy = true
        errorMessage = nil
        statusMessage = nil
        defer { isBusy = false }

        do {
            let installationID = try keychain.installationID()
            let credential = try await transport.pair(
                baseURL: baseURL,
                code: code,
                installationID: installationID
            )
            try await completePairing(
                baseURL: baseURL,
                credential: credential,
                installationID: installationID,
                coordinator: coordinator
            )
            pairingCode = ""
            clearPendingPairing()
            statusMessage = String(localized: "Connected through recovery setup. Review Apple Health access next.")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func completePairing(
        baseURL: URL,
        credential: String,
        installationID: String,
        coordinator: SyncCoordinator
    ) async throws {
        try keychain.saveCredential(credential)
        defaults.set(baseURL.absoluteString, forKey: DefaultsKey.serverAddress)
        serverAddress = baseURL.absoluteString
        await coordinator.configure(
            SyncConfiguration(
                baseURL: baseURL,
                credential: credential,
                installationID: installationID
            )
        )
        isPaired = true
        privateShareURL = nil
        try? keychain.deletePrivateShareURL()
        await refreshDeliveryStatus()
        if healthAccessRequested {
            await registerObservers()
            await syncNow()
        }
    }

    private func clearPendingPairing() {
        pendingAgentConsent = nil
        pendingLegacyPairing = nil
    }

    func refreshDeliveryStatus() async {
        guard isPaired else {
            deliveryStatus = nil
            deliveryStatusError = nil
            return
        }
        do {
            guard let credential = try keychain.credential() else {
                throw APIClientError.invalidResponse
            }
            let baseURL = try APIClient.validatedBaseURL(serverAddress)
            let installationID = try keychain.installationID()
            deliveryStatus = try await transport.deviceStatus(
                baseURL: baseURL,
                credential: credential,
                installationID: installationID
            )
            deliveryStatusError = nil
        } catch {
            deliveryStatusError = String(
                format: String(localized: "Delivery status is unavailable. %@"),
                locale: Locale.current,
                error.localizedDescription
            )
        }
    }

    private func finishLocalCredentialCleanup() {
        defaults.removeObject(forKey: DefaultsKey.localCredentialCleanupPending)
        localCredentialCleanupPending = false
        privateShareURL = nil
    }

    private func finishRevokedLocalCleanup() async throws {
        if let coordinator {
            do {
                try await coordinator.disconnect()
            } catch {
                observersInstalled = false
                throw error
            }
        }
        observersInstalled = false
        try deleteCredential()
        try keychain.deletePrivateShareURL()
    }

    private func rotatePrivateShareLinkUsingStoredDevice() async throws {
        guard let credential = try keychain.credential() else {
            throw APIClientError.invalidResponse
        }
        let baseURL = try APIClient.validatedBaseURL(serverAddress)
        let installationID = try keychain.installationID()
        let shareURL = try await transport.rotateDeviceShareLink(
            baseURL: baseURL,
            credential: credential,
            installationID: installationID
        )
        try keychain.savePrivateShareURL(shareURL)
        privateShareURL = shareURL
    }

    private func registerObservers() async {
        guard isPaired, healthAccessRequested, let health, let coordinator else { return }
        if !observersInstalled {
            Self.installObservers(
                health: health,
                coordinator: coordinator,
                protectedDataAvailable: protectedDataAvailable
            )
            observersInstalled = true
        }
        do {
            try await coordinator.enableBackgroundDelivery()
        } catch {
            observersInstalled = false
            statusMessage = String(localized: "Background delivery could not be registered. Manual sync remains available.")
        }
    }

    private static func installObservers(
        health: any HealthDataReading,
        coordinator: SyncCoordinator,
        protectedDataAvailable: @escaping @Sendable () async -> Bool
    ) {
        health.installObservers { [weak coordinator] in
            guard let coordinator, await protectedDataAvailable() else { return }
            _ = await coordinator.synchronize(
                lookbackDays: 2,
                maxUploadAttempts: 1,
                stopAfterPendingRecovery: true
            )
        }
    }

    private static func launchConfiguration(
        keychain: KeychainStore,
        serverAddress: String
    ) -> SyncConfiguration? {
        guard !serverAddress.isEmpty else { return nil }
        do {
            guard let credential = try keychain.credential() else { return nil }
            return SyncConfiguration(
                baseURL: try APIClient.validatedBaseURL(serverAddress),
                credential: credential,
                installationID: try keychain.installationID()
            )
        } catch {
            return nil
        }
    }

    private func refreshAfterForeground() async {
        guard !localCredentialCleanupPending,
              setupError == nil,
              isPaired,
              healthAccessRequested,
              !isBusy
        else { return }
        isBusy = true
        await registerObservers()
        await syncNow()
    }

    private func refreshSummaries(referenceDate: Date = Date()) async {
        guard let health else { return }
        async let todayRead = health.readDay(AppDate.dayStart(referenceDate))
        async let yesterdayRead = health.readDay(AppDate.addingDays(-1, to: referenceDate))
        let (today, yesterday) = await (todayRead, yesterdayRead)
        self.today = today
        self.yesterday = yesterday
    }
}

#if DEBUG
enum DemoScenario: String, CaseIterable, Sendable {
    case firstRun = "first-run"
    case consent
    case current
    case partial
    case unavailable
    case revoked
    case expired
    case healthEmpty = "health-empty"

    static func from(environment: [String: String]) -> DemoScenario? {
        environment["FITKIKU_DEMO_SCENARIO"].flatMap(Self.init(rawValue:))
    }
}

extension AppModel {
    private convenience init(syntheticDemo scenario: DemoScenario) {
        let suiteName = "com.kikuai.fitkiku.synthetic-demo.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        self.init(syntheticDemoDefaults: defaults)
        apply(syntheticDemo: scenario)
    }

    static func syntheticDemo(_ scenario: DemoScenario) -> AppModel {
        AppModel(syntheticDemo: scenario)
    }

    private func apply(syntheticDemo scenario: DemoScenario) {
        switch scenario {
        case .firstRun:
            break
        case .consent:
            pendingAgentConsent = PendingAgentConsent(
                baseURL: URL(string: "https://health.example")!,
                pairingToken: "synthetic-demo-token-not-a-credential",
                preview: AgentGrantPreview(
                    assertedAgentName: String(localized: "FitKiku private ChatGPT link"),
                    serverOrigin: "https://health.example",
                    scopes: [.steps, .sleep],
                    expiresAt: "2026-04-08T18:00:00Z",
                    retentionDisclosure:
                        "Daily summaries are retained until deletion is requested. "
                        + "Revoking stops future access but does not delete stored summaries.",
                    aiProcessingDisclosure: "Your approved agent may send these summaries to its configured AI provider.",
                    requiresTimezone: true
                ),
                createsPrivateShareLink: true
            )
        case .current:
            configureConnectedDemo(freshness: .current, partial: false)
            statusMessage = String(localized: "FitKiku is up to date.")
        case .partial:
            configureConnectedDemo(freshness: .stale, partial: true)
            demoScrollTarget = "yesterday"
            shouldExpandDeliveryForDemo = true
            statusMessage = String(localized: "Recent delivery needs attention.")
        case .unavailable:
            configureConnectedDemo(freshness: .unknown, partial: false)
            demoScrollTarget = "yesterday"
            shouldExpandDeliveryForDemo = true
            deliveryStatus = nil
            deliveryStatusError = String(localized: "Delivery status is unavailable. Try again when you're online.")
        case .revoked:
            localCredentialCleanupPending = true
            statusMessage = String(localized: "Server access is already revoked.")
        case .expired:
            errorMessage = String(localized: "This Pair Link has expired. Ask your agent for a new link.")
        case .healthEmpty:
            healthAccessRequested = true
            statusMessage = String(localized: "No Apple Health summary is available yet. Missing data stays Unknown.")
        }
    }

    private func configureConnectedDemo(
        freshness: DeviceDataFreshness,
        partial: Bool
    ) {
        let currentDate = Date(timeIntervalSince1970: 1_775_600_000)
        let previousDate = Date(timeIntervalSince1970: 1_775_513_600)
        serverAddress = "https://health.example"
        isPaired = true
        privateShareURL = URL(
            string: "https://kikuai.dev/fitkiku-health/demo-not-a-real-link"
        )
        healthAccessRequested = true
        demoScrollTarget = "summaries"
        today = Self.syntheticSummary(
            localDate: "2026-04-08",
            steps: 8_240,
            sleepStart: "2026-04-07T21:30:00Z",
            sleepEnd: "2026-04-08T05:10:00Z",
            sleepCoverage: partial ? .partial : .complete
        )
        yesterday = Self.syntheticSummary(
            localDate: "2026-04-07",
            steps: 7_180,
            sleepStart: "2026-04-06T22:05:00Z",
            sleepEnd: "2026-04-07T05:20:00Z",
            sleepCoverage: .complete
        )
        lastSyncAt = currentDate
        deliveryStatus = DeviceDeliveryStatus(
            lastServerReceivedAt: currentDate,
            lastAgentFetchedAt: freshness == .current && !partial
                ? currentDate.addingTimeInterval(60)
                : previousDate,
            latestLocalDate: "2026-04-08",
            lastDeviceGeneratedAt: currentDate,
            latestCoverage: HealthCoverage(
                steps: .complete,
                sleep: partial ? .partial : .complete
            ),
            missingLocalDates: partial ? ["2026-04-06"] : [],
            dataFreshness: freshness,
            canDeleteAccount: true
        )
    }

    private static func syntheticSummary(
        localDate: String,
        steps: Int,
        sleepStart: String,
        sleepEnd: String,
        sleepCoverage: CoverageState
    ) -> DaySummary {
        DaySummary(
            localDate: localDate,
            steps: steps,
            stepsCoverage: .complete,
            sleepIntervals: [
                SleepIntervalPayload(
                    start: sleepStart,
                    end: sleepEnd,
                    category: .asleepUnspecified
                ),
            ],
            sleepCoverage: sleepCoverage,
            sources: [
                HealthSourcePayload(
                    name: "Synthetic Watch",
                    bundleIdentifier: "example.synthetic.watch",
                    productType: "Synthetic"
                ),
            ]
        )
    }
}

private struct SyntheticDemoTransport: AppTransport {
    func issuePublicAgentGrant(baseURL _: URL, agentName _: String) async throws -> AgentPairingLink {
        throw APIClientError.transport
    }

    func pair(baseURL _: URL, code _: String, installationID _: String) async throws -> String {
        throw APIClientError.transport
    }

    func ingest(
        baseURL _: URL,
        credential _: String,
        snapshot _: HealthSnapshotPayload
    ) async throws -> String {
        throw APIClientError.transport
    }

    func previewAgentGrant(
        baseURL _: URL,
        pairingToken _: String
    ) async throws -> AgentGrantPreview {
        throw APIClientError.transport
    }

    func pairAgent(
        baseURL _: URL,
        pairingToken _: String,
        installationID _: String,
        timezone _: String?
    ) async throws -> String {
        throw APIClientError.transport
    }

    func revokeDevice(
        baseURL _: URL,
        credential _: String,
        installationID _: String
    ) async throws -> String {
        throw APIClientError.transport
    }

    func deleteAccount(
        baseURL _: URL,
        credential _: String,
        installationID _: String
    ) async throws -> String {
        throw APIClientError.transport
    }

    func deviceStatus(
        baseURL _: URL,
        credential _: String,
        installationID _: String
    ) async throws -> DeviceDeliveryStatus {
        throw APIClientError.transport
    }

    func rotateDeviceShareLink(
        baseURL _: URL,
        credential _: String,
        installationID _: String
    ) async throws -> URL {
        throw APIClientError.transport
    }

    func revokeDeviceShareLink(
        baseURL _: URL,
        credential _: String,
        installationID _: String
    ) async throws -> String {
        throw APIClientError.transport
    }
}
#endif

struct PendingAgentConsent: Equatable, Sendable {
    let baseURL: URL
    let pairingToken: String
    let preview: AgentGrantPreview
    let createsPrivateShareLink: Bool
}

struct PendingLegacyPairing: Equatable, Sendable {
    let baseURL: URL
    let code: String
}
