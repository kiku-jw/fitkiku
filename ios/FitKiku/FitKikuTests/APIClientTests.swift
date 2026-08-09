import XCTest
@testable import FitKiku

private final class MalformedResponseURLProtocol: URLProtocol {
    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: 200,
                  httpVersion: nil,
                  headerFields: ["Content-Type": "application/json"]
              )
        else {
            client?.urlProtocol(self, didFailWithError: APIClientError.transport)
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private actor PairingTestHealthReader: HealthDataReading {
    private var observerStartCount = 0
    private var dayReadCount = 0

    func requestAuthorization() async throws {}

    func readDay(_ dayStart: Date) async -> DaySummary {
        dayReadCount += 1
        return DaySummary(
            localDate: AppDate.localDate(dayStart),
            steps: nil,
            stepsCoverage: .unknown,
            sleepIntervals: [],
            sleepCoverage: .unknown,
            sources: []
        )
    }

    func startObservers(onChange _: @escaping @Sendable () async -> Void) async throws {
        observerStartCount += 1
    }

    func stopObservers() async {}

    func observerStarts() -> Int {
        observerStartCount
    }

    func dayReads() -> Int {
        dayReadCount
    }
}

private actor PairingTestTransport: AppTransport {
    private var previewCount = 0
    private var agentPairCount = 0
    private var revokeCount = 0
    private var statusCount = 0
    private var ingestCount = 0
    private var revokeFails = true
    private var ingestFails = false
    private var shouldBlockDeviceStatus = false
    private var deviceStatusContinuation: CheckedContinuation<Void, Never>?

    func pair(baseURL _: URL, code _: String, installationID _: String) async throws -> String {
        "legacy-device-credential"
    }

    func ingest(
        baseURL _: URL,
        credential _: String,
        snapshot _: HealthSnapshotPayload
    ) async throws -> String {
        ingestCount += 1
        if ingestFails {
            throw APIClientError.transport
        }
        return "created"
    }

    func previewAgentGrant(
        baseURL: URL,
        pairingToken _: String
    ) async throws -> AgentGrantPreview {
        previewCount += 1
        return AgentGrantPreview(
            assertedAgentName: "Test Agent",
            serverOrigin: baseURL.absoluteString,
            scopes: [.steps, .sleep],
            expiresAt: "2099-08-02T12:00:00Z",
            retentionDisclosure: "Daily summaries are retained until revocation.",
            aiProcessingDisclosure: "The agent may send summaries to its configured AI provider."
        )
    }

    func pairAgent(
        baseURL _: URL,
        pairingToken _: String,
        installationID _: String
    ) async throws -> String {
        agentPairCount += 1
        return "agent-device-credential"
    }

    func revokeDevice(
        baseURL _: URL,
        credential _: String,
        installationID _: String
    ) async throws -> String {
        revokeCount += 1
        if revokeFails {
            throw APIClientError.transport
        }
        return "revoked"
    }

    func deviceStatus(
        baseURL _: URL,
        credential _: String,
        installationID _: String
    ) async throws -> DeviceDeliveryStatus {
        statusCount += 1
        if shouldBlockDeviceStatus {
            await withCheckedContinuation { continuation in
                deviceStatusContinuation = continuation
            }
        }
        return DeviceDeliveryStatus(
            lastServerReceivedAt: Date(timeIntervalSince1970: 1_775_000_000),
            lastAgentFetchedAt: Date(timeIntervalSince1970: 1_775_000_060),
            latestLocalDate: "2026-08-02",
            lastDeviceGeneratedAt: Date(timeIntervalSince1970: 1_774_999_940),
            latestCoverage: HealthCoverage(steps: .complete, sleep: .partial),
            missingLocalDates: ["2026-08-01"],
            dataFreshness: .current
        )
    }

    func allowRevocation() {
        revokeFails = false
    }

    func failIngest() {
        ingestFails = true
    }

    func blockDeviceStatus() {
        shouldBlockDeviceStatus = true
    }

    func releaseDeviceStatus() {
        shouldBlockDeviceStatus = false
        deviceStatusContinuation?.resume()
        deviceStatusContinuation = nil
    }

    func counts() -> (preview: Int, pair: Int, revoke: Int, status: Int, ingest: Int) {
        (previewCount, agentPairCount, revokeCount, statusCount, ingestCount)
    }
}

@MainActor
private final class FailOnceCredentialCleanup {
    private(set) var attempts = 0

    func run() throws {
        attempts += 1
        if attempts == 1 {
            throw APIClientError.transport
        }
    }
}

final class APIClientTests: XCTestCase {
    private let validToken = "abcdefghijklmnopqrstuvwxyzABCDEFG_0123456789-abcd"

    func testBaseURLRequiresHTTPSAndServerRoot() throws {
        XCTAssertEqual(
            try APIClient.validatedBaseURL("https://FitKiku.Example/", allowInsecureLocalhost: false)
                .absoluteString,
            "https://fitkiku.example"
        )
        XCTAssertThrowsError(
            try APIClient.validatedBaseURL("http://fitkiku.example", allowInsecureLocalhost: false)
        )
        XCTAssertThrowsError(
            try APIClient.validatedBaseURL(
                "https://user:secret@fitkiku.example",
                allowInsecureLocalhost: false
            )
        )
        XCTAssertThrowsError(
            try APIClient.validatedBaseURL(
                "https://fitkiku.example/prefix",
                allowInsecureLocalhost: false
            )
        )
    }

    func testDebugLocalhostExceptionIsExplicit() throws {
        XCTAssertEqual(
            try APIClient.validatedBaseURL(
                "http://127.0.0.1:8000",
                allowInsecureLocalhost: true
            ).absoluteString,
            "http://127.0.0.1:8000"
        )
        XCTAssertThrowsError(
            try APIClient.validatedBaseURL(
                "http://192.168.1.10:8000",
                allowInsecureLocalhost: true
            )
        )
    }

    func testLegacyPairRequestUsesBackendInstallationKey() throws {
        let data = try CanonicalJSON.encoder().encode(
            PairRequest(
                code: "12345678",
                installationID: "fixture-installation-0001",
                appVersion: "native/1.0"
            )
        )
        let object = try jsonObject(data)
        XCTAssertEqual(object["installation_id"] as? String, "fixture-installation-0001")
        XCTAssertEqual(object["app_version"] as? String, "native/1.0")
        XCTAssertNil(object["installation_i_d"])
    }

    func testAgentPreviewRequestContainsOnlyOpaqueToken() throws {
        let baseURL = try APIClient.validatedBaseURL("https://fitkiku.example")
        let request = try APIClient().makeAgentPreviewRequest(
            baseURL: baseURL,
            pairingToken: validToken
        )
        let object = try jsonObject(XCTUnwrap(request.httpBody))

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/healthkit/agent-grants/preview")
        XCTAssertEqual(Set(object.keys), ["pairing_token"])
        XCTAssertEqual(object["pairing_token"] as? String, validToken)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testAgentPreviewDecodesBackendSnakeCaseContract() throws {
        let data = Data(
            """
            {
              "asserted_agent_name": "Claimed Agent",
              "agent_identity_verified": false,
              "server_origin": "https://fitkiku.example",
              "scopes": ["steps", "sleep"],
              "expires_at": "2099-08-02T12:00:00Z",
              "retention_disclosure": "Stored until revoked.",
              "ai_processing_disclosure": "Processed by the configured model provider."
            }
            """.utf8
        )

        let preview = try CanonicalJSON.decoder().decode(AgentGrantPreview.self, from: data)

        XCTAssertEqual(preview.assertedAgentName, "Claimed Agent")
        XCTAssertEqual(preview.serverOrigin, "https://fitkiku.example")
        XCTAssertEqual(preview.scopes, [.steps, .sleep])
        XCTAssertEqual(preview.expiresAt, "2099-08-02T12:00:00Z")
    }

    func testAgentPreviewMapsMalformedJSONToInvalidResponse() async throws {
        let client = APIClient(session: malformedResponseSession())
        let baseURL = try APIClient.validatedBaseURL("https://fitkiku.example")

        do {
            _ = try await client.previewAgentGrant(
                baseURL: baseURL,
                pairingToken: validToken
            )
            XCTFail("Expected malformed preview JSON to be rejected")
        } catch let error as APIClientError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testAgentPairRequestAddsInstallationOnlyAfterApproval() throws {
        let baseURL = try APIClient.validatedBaseURL("https://fitkiku.example")
        let request = try APIClient().makeAgentPairRequest(
            baseURL: baseURL,
            pairingToken: validToken,
            installationID: "fixture-installation-0001"
        )
        let object = try jsonObject(XCTUnwrap(request.httpBody))

        XCTAssertEqual(request.url?.path, "/healthkit/agent-pair")
        XCTAssertEqual(
            Set(object.keys),
            ["pairing_token", "installation_id", "app_version"]
        )
        XCTAssertEqual(object["pairing_token"] as? String, validToken)
        XCTAssertEqual(object["installation_id"] as? String, "fixture-installation-0001")
        XCTAssertEqual(object["app_version"] as? String, "native/1.0")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testDeviceRevokeRequestIsAuthenticatedAndScopedToInstallation() throws {
        let baseURL = try APIClient.validatedBaseURL("https://fitkiku.example")
        let request = try APIClient().makeDeviceRevokeRequest(
            baseURL: baseURL,
            credential: "synthetic-device-credential",
            installationID: "fixture-installation-0001"
        )
        let object = try jsonObject(XCTUnwrap(request.httpBody))

        XCTAssertEqual(request.url?.path, "/healthkit/device/revoke")
        XCTAssertEqual(Set(object.keys), ["installation_id"])
        XCTAssertEqual(object["installation_id"] as? String, "fixture-installation-0001")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer synthetic-device-credential"
        )
    }

    func testDeviceStatusRequestIsAuthenticatedReadOnlyAndScopedToInstallation() throws {
        let baseURL = try APIClient.validatedBaseURL("https://fitkiku.example")
        let request = try APIClient().makeDeviceStatusRequest(
            baseURL: baseURL,
            credential: "synthetic-device-credential",
            installationID: "fixture-installation-0001"
        )
        let components = try XCTUnwrap(
            URLComponents(
                url: XCTUnwrap(request.url),
                resolvingAgainstBaseURL: false
            )
        )

        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(components.path, "/healthkit/device/status")
        XCTAssertEqual(
            components.queryItems,
            [URLQueryItem(name: "installation_id", value: "fixture-installation-0001")]
        )
        XCTAssertNil(request.httpBody)
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer synthetic-device-credential"
        )
    }

    func testDeviceStatusDecodesBackendSnakeCaseContract() throws {
        let data = Data(
            """
            {
              "last_server_received_at": "2026-08-02T12:00:00Z",
              "last_agent_fetched_at": null,
              "latest_local_date": "2026-08-02",
              "last_device_generated_at": "2026-08-02T11:59:00Z",
              "latest_coverage": {"steps": "complete", "sleep": "partial"},
              "missing_local_dates": ["2026-08-01"],
              "data_freshness": "current"
            }
            """.utf8
        )

        let status = try CanonicalJSON.decoder().decode(DeviceStatusResponse.self, from: data)

        XCTAssertEqual(status.lastServerReceivedAt, "2026-08-02T12:00:00Z")
        XCTAssertNil(status.lastAgentFetchedAt)
        XCTAssertEqual(status.latestLocalDate, "2026-08-02")
        XCTAssertEqual(status.latestCoverage, HealthCoverage(steps: .complete, sleep: .partial))
        XCTAssertEqual(status.missingLocalDates, ["2026-08-01"])
        XCTAssertEqual(status.dataFreshness, .current)
    }

    func testDeviceStatusMapsMalformedJSONToInvalidResponse() async throws {
        let client = APIClient(session: malformedResponseSession())
        let baseURL = try APIClient.validatedBaseURL("https://fitkiku.example")

        do {
            _ = try await client.deviceStatus(
                baseURL: baseURL,
                credential: "synthetic-device-credential",
                installationID: "fixture-installation-0001"
            )
            XCTFail("Expected malformed device status JSON to be rejected")
        } catch let error as APIClientError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testDeviceStatusRejectsMalformedTimestamps() throws {
        let client = APIClient()
        let valid = DeviceStatusResponse(
            lastServerReceivedAt: "2026-08-02T12:00:00Z",
            lastAgentFetchedAt: nil,
            latestLocalDate: "2026-08-02",
            lastDeviceGeneratedAt: "2026-08-02T11:59:00Z",
            latestCoverage: HealthCoverage(steps: .complete, sleep: .unknown),
            missingLocalDates: ["2026-08-01"],
            dataFreshness: .current
        )
        let parsed = try client.validatedDeviceStatus(valid)

        XCTAssertNotNil(parsed.lastServerReceivedAt)
        XCTAssertNil(parsed.lastAgentFetchedAt)
        XCTAssertEqual(parsed.latestLocalDate, "2026-08-02")
        XCTAssertEqual(parsed.dataFreshness, .current)
        XCTAssertThrowsError(
            try client.validatedDeviceStatus(
                DeviceStatusResponse(
                    lastServerReceivedAt: "not-a-timestamp",
                    lastAgentFetchedAt: nil,
                    latestLocalDate: "2026-08-02",
                    lastDeviceGeneratedAt: "2026-08-02T11:59:00Z",
                    latestCoverage: HealthCoverage(steps: .complete, sleep: .unknown),
                    missingLocalDates: [],
                    dataFreshness: .current
                )
            )
        )
        XCTAssertThrowsError(
            try client.validatedDeviceStatus(
                DeviceStatusResponse(
                    lastServerReceivedAt: nil,
                    lastAgentFetchedAt: nil,
                    latestLocalDate: "2026-02-30",
                    lastDeviceGeneratedAt: nil,
                    latestCoverage: nil,
                    missingLocalDates: [],
                    dataFreshness: .unknown
                )
            )
        )
    }

    func testPreviewMustMatchCanonicalOriginScopesAndFutureExpiry() throws {
        let client = APIClient()
        let baseURL = try APIClient.validatedBaseURL("https://fitkiku.example")
        let valid = AgentGrantPreview(
            assertedAgentName: "Claimed Agent",
            serverOrigin: "https://FITKIKU.example/",
            scopes: [.sleep, .steps],
            expiresAt: "2099-08-02T12:00:00.000Z",
            retentionDisclosure: "Stored until revoked.",
            aiProcessingDisclosure: "Processed by the configured model provider."
        )

        XCTAssertEqual(try client.validatedAgentPreview(valid, for: baseURL), valid)

        let wrongOrigin = AgentGrantPreview(
            assertedAgentName: valid.assertedAgentName,
            serverOrigin: "https://attacker.example",
            scopes: valid.scopes,
            expiresAt: valid.expiresAt,
            retentionDisclosure: valid.retentionDisclosure,
            aiProcessingDisclosure: valid.aiProcessingDisclosure
        )
        XCTAssertThrowsError(try client.validatedAgentPreview(wrongOrigin, for: baseURL))

        let wrongScopes = AgentGrantPreview(
            assertedAgentName: valid.assertedAgentName,
            serverOrigin: valid.serverOrigin,
            scopes: [.steps],
            expiresAt: valid.expiresAt,
            retentionDisclosure: valid.retentionDisclosure,
            aiProcessingDisclosure: valid.aiProcessingDisclosure
        )
        XCTAssertThrowsError(try client.validatedAgentPreview(wrongScopes, for: baseURL))

        let expired = AgentGrantPreview(
            assertedAgentName: valid.assertedAgentName,
            serverOrigin: valid.serverOrigin,
            scopes: valid.scopes,
            expiresAt: "2020-01-01T00:00:00Z",
            retentionDisclosure: valid.retentionDisclosure,
            aiProcessingDisclosure: valid.aiProcessingDisclosure
        )
        XCTAssertThrowsError(try client.validatedAgentPreview(expired, for: baseURL))
    }

    func testRedirectDelegateRejectsEveryRedirectWithoutNetworkIO() throws {
        let originalURL = try XCTUnwrap(URL(string: "https://fitkiku.example/healthkit/pair"))
        let redirectURL = try XCTUnwrap(URL(string: "https://attacker.example/capture"))
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: originalURL,
                statusCode: 302,
                httpVersion: nil,
                headerFields: ["Location": redirectURL.absoluteString]
            )
        )
        let configuration = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let task = session.dataTask(with: originalURL)
        defer { task.cancel() }

        var decision: URLRequest? = URLRequest(url: redirectURL)
        RejectRedirectDelegate().urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: response,
            newRequest: URLRequest(url: redirectURL)
        ) { request in
            decision = request
        }

        XCTAssertNil(decision)
    }

    func testAgentPairLinkParsesOpaqueToken() throws {
        let payload = try XCTUnwrap(
            PairingPayload.parse(agentLink(token: validToken))
        )
        guard case let .agent(link) = payload else {
            return XCTFail("Expected agent Pair Link")
        }
        XCTAssertEqual(link.baseURL.absoluteString, "https://fitkiku.example")
        XCTAssertEqual(link.pairingToken, validToken)
    }

    func testLegacyPairLinkStillParsesAsRecoveryFallback() throws {
        let payload = try XCTUnwrap(
            PairingPayload.parse(
                "fitkiku-health://pair?server=https%3A%2F%2Ffitkiku.example&code=12345678"
            )
        )
        guard case let .legacy(link) = payload else {
            return XCTFail("Expected legacy Pair Link")
        }
        XCTAssertEqual(link.baseURL.absoluteString, "https://fitkiku.example")
        XCTAssertEqual(link.code, "12345678")
    }

    func testPairLinkRejectsMalformedAmbiguousAndMixedInputs() {
        let shortToken = String(repeating: "a", count: 42)
        let oversizedToken = String(repeating: "a", count: 129)
        let invalidLinks = [
            "https://pair?server=https%3A%2F%2Ffitkiku.example&token=\(validToken)",
            "fitkiku-health://connect?server=https%3A%2F%2Ffitkiku.example&token=\(validToken)",
            "fitkiku-health://user@pair?server=https%3A%2F%2Ffitkiku.example&token=\(validToken)",
            "fitkiku-health://pair/path?server=https%3A%2F%2Ffitkiku.example&token=\(validToken)",
            "fitkiku-health://pair?server=https%3A%2F%2Ffitkiku.example&token=\(validToken)#fragment",
            "fitkiku-health://pair?server=https%3A%2F%2Ffitkiku.example&token=\(validToken)&token=\(validToken)",
            "fitkiku-health://pair?server=https%3A%2F%2Ffitkiku.example&server=https%3A%2F%2Fother.example&token=\(validToken)",
            "fitkiku-health://pair?server=https%3A%2F%2Ffitkiku.example&token=\(validToken)&code=12345678",
            "fitkiku-health://pair?server=https%3A%2F%2Ffitkiku.example&token=\(validToken)&extra=1",
            "fitkiku-health://pair?server=http%3A%2F%2Ffitkiku.example&token=\(validToken)",
            "fitkiku-health://pair?server=https%3A%2F%2Fuser%40fitkiku.example&token=\(validToken)",
            "fitkiku-health://pair?server=https%3A%2F%2Ffitkiku.example%2Fprefix&token=\(validToken)",
            agentLink(token: shortToken),
            agentLink(token: oversizedToken),
            agentLink(token: "\(validToken)%2B"),
        ]

        for value in invalidLinks {
            XCTAssertThrowsError(try PairingPayload.parse(value), "Accepted invalid link: \(value)")
        }
    }

    @MainActor
    func testOpeningAgentLinkOnlyPreviewsAndCancelClearsInMemoryToken() async throws {
        let harness = try makeModelHarness()
        defer { harness.cleanup() }

        await harness.model.loadPairingInput(agentLink(token: validToken))

        XCTAssertFalse(harness.model.isPaired)
        XCTAssertNil(try harness.keychain.credential())
        XCTAssertEqual(harness.model.pendingAgentConsent?.pairingToken, validToken)
        XCTAssertEqual(harness.model.pendingAgentConsent?.preview.assertedAgentName, "Test Agent")
        var counts = await harness.transport.counts()
        XCTAssertEqual(counts.preview, 1)
        XCTAssertEqual(counts.pair, 0)
        XCTAssertEqual(counts.status, 0)

        harness.model.cancelPendingPairing()
        XCTAssertNil(harness.model.pendingAgentConsent)
        counts = await harness.transport.counts()
        XCTAssertEqual(counts.pair, 0)
    }

    @MainActor
    func testDisconnectKeepsCredentialUntilServerRevocationSucceeds() async throws {
        let harness = try makeModelHarness()
        defer { harness.cleanup() }

        await harness.model.loadPairingInput(agentLink(token: validToken))
        await harness.model.approveAgentPairing()
        XCTAssertTrue(harness.model.isPaired)
        XCTAssertEqual(try harness.keychain.credential(), "agent-device-credential")
        XCTAssertNotNil(harness.model.deliveryStatus?.lastServerReceivedAt)
        XCTAssertNotNil(harness.model.deliveryStatus?.lastAgentFetchedAt)
        XCTAssertEqual(harness.model.deliveryStatus?.dataFreshness, .current)
        XCTAssertEqual(harness.model.deliveryStatus?.missingLocalDates, ["2026-08-01"])
        XCTAssertNil(harness.model.deliveryStatusError)

        await harness.model.disconnect()
        XCTAssertTrue(harness.model.isPaired)
        XCTAssertEqual(try harness.keychain.credential(), "agent-device-credential")
        XCTAssertTrue(harness.model.errorMessage?.contains("remains connected") == true)

        await harness.transport.allowRevocation()
        await harness.model.disconnect()
        XCTAssertFalse(harness.model.isPaired)
        XCTAssertNil(try harness.keychain.credential())
        XCTAssertNil(harness.model.deliveryStatus)
        XCTAssertNil(harness.model.deliveryStatusError)
        XCTAssertEqual(harness.model.statusMessage, "Server access was revoked and the local credential was removed.")
    }

    @MainActor
    func testSyncFailureShowsDurableQueuedStateWithoutClaimingSuccess() async throws {
        let harness = try makeModelHarness()
        defer { harness.cleanup() }

        await harness.model.loadPairingInput(agentLink(token: validToken))
        await harness.model.approveAgentPairing()
        await harness.transport.failIngest()
        await harness.model.requestHealthAccess()
        await harness.model.syncNow()

        XCTAssertEqual(harness.model.lastResults.count, 7)
        XCTAssertTrue(harness.model.lastResults.allSatisfy { $0.outcome == .queued })
        XCTAssertTrue(harness.model.errorMessage?.contains("Queued on this iPhone") == true)
        XCTAssertNil(harness.model.lastSyncAt)
        let queuedFiles = try FileManager.default.contentsOfDirectory(
            at: harness.outboxDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        XCTAssertEqual(queuedFiles.count, 7)
    }

    @MainActor
    func testRestoreRegistersObserversBeforeRemoteDeliveryStatusCompletes() async throws {
        let identifier = UUID().uuidString
        let suiteName = "FitKikuTests.\(identifier)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("https://fitkiku.example", forKey: "healthkit.server-address")
        defaults.set(true, forKey: "healthkit.access-requested")
        let keychain = KeychainStore(service: "com.kikuai.fitkiku.health.tests.\(identifier)")
        try keychain.saveCredential("restored-device-credential")
        _ = try keychain.installationID()
        let transport = PairingTestTransport()
        await transport.blockDeviceStatus()
        let health = PairingTestHealthReader()
        let outboxDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(identifier, isDirectory: true)
        let model = AppModel(
            defaults: defaults,
            keychain: keychain,
            transport: transport,
            healthReader: health,
            outbox: try ProtectedOutbox(directory: outboxDirectory),
            stateStore: SyncStateStore(suiteName: suiteName)
        )
        defer {
            try? keychain.deleteCredential()
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: outboxDirectory)
        }

        let restore = Task { await model.restore() }
        var statusCalls = 0
        for _ in 0 ..< 100 {
            statusCalls = await transport.counts().status
            if statusCalls == 1 { break }
            await Task.yield()
        }

        let observerStarts = await health.observerStarts()
        XCTAssertEqual(statusCalls, 1)
        XCTAssertEqual(observerStarts, 1)

        await transport.releaseDeviceStatus()
        await restore.value
    }

    @MainActor
    func testForegroundRestoreRunsBoundedCatchUpWithoutDuplicateUpload() async throws {
        let harness = try makeModelHarness()
        defer { harness.cleanup() }

        await harness.model.loadPairingInput(agentLink(token: validToken))
        await harness.model.approveAgentPairing()
        await harness.model.requestHealthAccess()
        await harness.model.restore()

        let readsBeforeForeground = await harness.health.dayReads()
        let observersBeforeForeground = await harness.health.observerStarts()
        let ingestsBeforeForeground = await harness.transport.counts().ingest

        await harness.model.restore()

        let readsAfterForeground = await harness.health.dayReads()
        let observersAfterForeground = await harness.health.observerStarts()
        let ingestsAfterForeground = await harness.transport.counts().ingest
        XCTAssertEqual(readsAfterForeground - readsBeforeForeground, 9)
        XCTAssertEqual(observersAfterForeground - observersBeforeForeground, 1)
        XCTAssertEqual(ingestsAfterForeground, ingestsBeforeForeground)
        XCTAssertTrue(harness.model.lastResults.allSatisfy { $0.outcome == .unchanged })
    }

    @MainActor
    func testRestoreCanRetryAfterAnEarlyLaunchFailure() async throws {
        let identifier = UUID().uuidString
        let suiteName = "FitKikuTests.\(identifier)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("not-a-server-origin", forKey: "healthkit.server-address")
        let keychain = KeychainStore(service: "com.kikuai.fitkiku.health.tests.\(identifier)")
        try keychain.saveCredential("restored-device-credential")
        _ = try keychain.installationID()
        let transport = PairingTestTransport()
        let outboxDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(identifier, isDirectory: true)
        let model = AppModel(
            defaults: defaults,
            keychain: keychain,
            transport: transport,
            healthReader: PairingTestHealthReader(),
            outbox: try ProtectedOutbox(directory: outboxDirectory),
            stateStore: SyncStateStore(suiteName: suiteName)
        )
        defer {
            try? keychain.deleteCredential()
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: outboxDirectory)
        }

        await model.restore()
        XCTAssertFalse(model.isPaired)
        XCTAssertNotNil(model.errorMessage)

        model.serverAddress = "https://fitkiku.example"
        await model.restore()

        XCTAssertTrue(model.isPaired)
        XCTAssertNil(model.errorMessage)
        let counts = await transport.counts()
        XCTAssertEqual(counts.status, 1)
    }

    @MainActor
    func testRestoreRetriesPendingCredentialCleanupAfterProtectedStateFailure() async throws {
        let identifier = UUID().uuidString
        let suiteName = "FitKikuTests.\(identifier)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(true, forKey: "healthkit.local-credential-cleanup-pending")
        let cleanup = FailOnceCredentialCleanup()
        let outboxDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(identifier, isDirectory: true)
        let model = AppModel(
            defaults: defaults,
            keychain: KeychainStore(
                service: "com.kikuai.fitkiku.health.tests.\(identifier)"
            ),
            credentialCleanup: cleanup.run,
            transport: PairingTestTransport(),
            healthReader: PairingTestHealthReader(),
            outbox: try ProtectedOutbox(directory: outboxDirectory),
            stateStore: SyncStateStore(suiteName: suiteName)
        )
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: outboxDirectory)
        }

        await model.restore()
        XCTAssertTrue(model.localCredentialCleanupPending)
        XCTAssertEqual(cleanup.attempts, 1)

        await model.restore()

        XCTAssertFalse(model.localCredentialCleanupPending)
        XCTAssertEqual(cleanup.attempts, 2)
        XCTAssertEqual(model.statusMessage, "The already-revoked local credential was removed.")
    }

    @MainActor
    func testSyntheticDemoScenarioParsingIsExplicit() {
        XCTAssertEqual(
            DemoScenario.from(environment: ["FITKIKU_DEMO_SCENARIO": "consent"]),
            .consent
        )
        XCTAssertNil(
            DemoScenario.from(environment: ["FITKIKU_DEMO_SCENARIO": "production"])
        )
        XCTAssertNil(DemoScenario.from(environment: [:]))
    }

    @MainActor
    func testSyntheticDemoRestoreDoesNotReplaceDeterministicState() async {
        let model = AppModel.syntheticDemo(.partial)
        let delivery = model.deliveryStatus

        await model.restore()

        XCTAssertTrue(model.isSyntheticDemo)
        XCTAssertTrue(model.isPaired)
        XCTAssertTrue(model.healthAccessRequested)
        XCTAssertEqual(model.demoScrollTarget, "yesterday")
        XCTAssertEqual(model.today?.localDate, "2026-04-08")
        XCTAssertEqual(model.deliveryStatus, delivery)
        XCTAssertEqual(model.deliveryStatus?.dataFreshness, .stale)
        XCTAssertEqual(model.deliveryStatus?.latestCoverage?.sleep, .partial)
        XCTAssertEqual(model.deliveryStatus?.missingLocalDates, ["2026-04-06"])
    }

    @MainActor
    func testSyntheticDemoScenariosExposeOnlyTheirIntendedState() {
        let firstRun = AppModel.syntheticDemo(.firstRun)
        let consent = AppModel.syntheticDemo(.consent)
        let revoked = AppModel.syntheticDemo(.revoked)
        let expired = AppModel.syntheticDemo(.expired)
        let healthEmpty = AppModel.syntheticDemo(.healthEmpty)

        XCTAssertFalse(firstRun.isPaired)
        XCTAssertNil(firstRun.pendingAgentConsent)
        XCTAssertEqual(consent.pendingAgentConsent?.preview.assertedAgentName, "Kiku Assistant")
        XCTAssertFalse(consent.isPaired)
        XCTAssertTrue(revoked.localCredentialCleanupPending)
        XCTAssertFalse(revoked.isPaired)
        XCTAssertEqual(
            expired.errorMessage,
            "This Pair Link has expired. Ask your agent for a new link."
        )
        XCTAssertTrue(healthEmpty.healthAccessRequested)
        XCTAssertNil(healthEmpty.today)
        XCTAssertNil(healthEmpty.yesterday)
    }

    private func agentLink(token: String) -> String {
        "fitkiku-health://pair?server=https%3A%2F%2Ffitkiku.example&token=\(token)"
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func malformedResponseSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MalformedResponseURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    @MainActor
    private func makeModelHarness() throws -> ModelHarness {
        let identifier = UUID().uuidString
        let suiteName = "FitKikuTests.\(identifier)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let keychain = KeychainStore(service: "com.kikuai.fitkiku.health.tests.\(identifier)")
        let transport = PairingTestTransport()
        let health = PairingTestHealthReader()
        let outboxDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(identifier, isDirectory: true)
        let model = AppModel(
            defaults: defaults,
            keychain: keychain,
            transport: transport,
            healthReader: health,
            outbox: try ProtectedOutbox(directory: outboxDirectory),
            stateStore: SyncStateStore(suiteName: suiteName)
        )
        return ModelHarness(
            model: model,
            keychain: keychain,
            transport: transport,
            health: health,
            suiteName: suiteName,
            outboxDirectory: outboxDirectory
        )
    }
}

@MainActor
private struct ModelHarness {
    let model: AppModel
    let keychain: KeychainStore
    let transport: PairingTestTransport
    let health: PairingTestHealthReader
    let suiteName: String
    let outboxDirectory: URL

    func cleanup() {
        try? keychain.deleteCredential()
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: outboxDirectory)
    }
}
