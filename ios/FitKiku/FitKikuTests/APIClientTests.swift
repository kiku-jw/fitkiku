// SPDX-License-Identifier: MPL-2.0

import HealthKit
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

private final class PairingTestHealthReader: HealthDataReading, @unchecked Sendable {
    private let lock = NSLock()
    private var observerInstallCount = 0
    private var observerStartCount = 0
    private var observerStopCount = 0
    private var dayReadCount = 0
    private var observerAction: (@Sendable () async -> Void)?

    func requestAuthorization() async throws {}

    func readDay(_ dayStart: Date) async -> DaySummary {
        lock.withLock { dayReadCount += 1 }
        return DaySummary(
            localDate: AppDate.localDate(dayStart),
            steps: nil,
            stepsCoverage: .unknown,
            sleepIntervals: [],
            sleepCoverage: .unknown,
            sources: []
        )
    }

    func installObservers(onChange: @escaping @Sendable () async -> Void) {
        lock.withLock {
            observerInstallCount += 1
            observerAction = onChange
        }
    }

    func enableBackgroundDelivery() async throws {
        lock.withLock { observerStartCount += 1 }
    }

    func stopObservers() async {
        lock.withLock { observerStopCount += 1 }
    }

    func observerInstalls() async -> Int {
        lock.withLock { observerInstallCount }
    }

    func observerStarts() async -> Int {
        lock.withLock { observerStartCount }
    }

    func observerStops() async -> Int {
        lock.withLock { observerStopCount }
    }

    func dayReads() async -> Int {
        lock.withLock { dayReadCount }
    }

    func triggerObserver() async {
        let action = lock.withLock { observerAction }
        await action?()
    }
}

private actor PairingTestTransport: AppTransport {
    private var previewCount = 0
    private var agentPairCount = 0
    private var revokeCount = 0
    private var deleteCount = 0
    private var statusCount = 0
    private var ingestCount = 0
    private var publicIssueCount = 0
    private var shareRotateCount = 0
    private var shareRevokeCount = 0
    private var revokeFails = true
    private var deleteFails = true
    private var ingestFails = false
    private var shouldBlockDeviceStatus = false
    private var deviceStatusContinuation: CheckedContinuation<Void, Never>?
    private var lastPairTimezone: String?

    func pair(baseURL _: URL, code _: String, installationID _: String) async throws -> String {
        "legacy-device-credential"
    }

    func issuePublicAgentGrant(baseURL: URL, agentName _: String) async throws -> AgentPairingLink {
        publicIssueCount += 1
        return AgentPairingLink(
            baseURL: baseURL,
            pairingToken: String(repeating: "a", count: 43)
        )
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
            aiProcessingDisclosure: "The agent may send summaries to its configured AI provider.",
            requiresTimezone: true
        )
    }

    func pairAgent(
        baseURL _: URL,
        pairingToken _: String,
        installationID _: String,
        timezone: String?
    ) async throws -> String {
        agentPairCount += 1
        lastPairTimezone = timezone
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

    func deleteAccount(
        baseURL _: URL,
        credential _: String,
        installationID _: String
    ) async throws -> String {
        deleteCount += 1
        if deleteFails {
            throw APIClientError.transport
        }
        return "deleted"
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
            dataFreshness: .current,
            canDeleteAccount: true
        )
    }

    func rotateDeviceShareLink(
        baseURL _: URL,
        credential _: String,
        installationID _: String
    ) async throws -> URL {
        shareRotateCount += 1
        return URL(
            string: "https://kikuai.dev/fitkiku-health/\(String(repeating: "b", count: 43))"
        )!
    }

    func revokeDeviceShareLink(
        baseURL _: URL,
        credential _: String,
        installationID _: String
    ) async throws -> String {
        shareRevokeCount += 1
        return "revoked"
    }

    func allowRevocation() {
        revokeFails = false
    }

    func allowDeletion() {
        deleteFails = false
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

    func counts() -> (preview: Int, pair: Int, revoke: Int, delete: Int, status: Int, ingest: Int) {
        (previewCount, agentPairCount, revokeCount, deleteCount, statusCount, ingestCount)
    }

    func privateLinkCounts() -> (issue: Int, rotate: Int, revoke: Int) {
        (publicIssueCount, shareRotateCount, shareRevokeCount)
    }

    func pairedTimezone() -> String? {
        lastPairTimezone
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

    func testBackgroundDeliveryUsesEarliestFrequencyAndBoundedNetworkTimeout() {
        XCTAssertEqual(HealthKitClient.backgroundDeliveryFrequency, .immediate)
        XCTAssertEqual(APIClient.defaultIngestTimeout, 5)
    }

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

    func testHostedGrantRequestUsesCredentialFreeAppEndpoint() throws {
        let baseURL = try APIClient.validatedBaseURL("https://fitkiku-origin.kikuai.dev")
        let request = try APIClient().makePublicAgentGrantRequest(
            baseURL: baseURL,
            agentName: "  FitKiku private AI link  "
        )
        let object = try jsonObject(XCTUnwrap(request.httpBody))

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/healthkit/public/app-grants")
        XCTAssertEqual(Set(object.keys), ["agent_name"])
        XCTAssertEqual(object["agent_name"] as? String, "FitKiku private AI link")
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
        XCTAssertNil(preview.requiresTimezone)
        XCTAssertNotEqual(preview.formattedExpiresAt, preview.expiresAt)
        XCTAssertFalse(preview.formattedExpiresAt.contains("T12:00:00Z"))
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
            installationID: "fixture-installation-0001",
            timezone: "America/Toronto"
        )
        let object = try jsonObject(XCTUnwrap(request.httpBody))

        XCTAssertEqual(request.url?.path, "/healthkit/agent-pair")
        XCTAssertEqual(
            Set(object.keys),
            ["pairing_token", "installation_id", "app_version", "timezone"]
        )
        XCTAssertEqual(object["pairing_token"] as? String, validToken)
        XCTAssertEqual(object["installation_id"] as? String, "fixture-installation-0001")
        XCTAssertEqual(object["app_version"] as? String, "native/1.1")
        XCTAssertEqual(object["timezone"] as? String, "America/Toronto")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testPrivateAgentPairRequestOmitsTimezoneForOlderBackendCompatibility() throws {
        let baseURL = try APIClient.validatedBaseURL("https://fitkiku.example")
        let request = try APIClient().makeAgentPairRequest(
            baseURL: baseURL,
            pairingToken: validToken,
            installationID: "fixture-installation-0001"
        )
        let object = try jsonObject(XCTUnwrap(request.httpBody))

        XCTAssertEqual(
            Set(object.keys),
            ["pairing_token", "installation_id", "app_version"]
        )
        XCTAssertNil(object["timezone"])
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

    func testDeviceShareLinkRequestIsAuthenticatedAndScopedToInstallation() throws {
        let baseURL = try APIClient.validatedBaseURL("https://fitkiku.example")
        let request = try APIClient().makeDeviceShareLinkRequest(
            path: "healthkit/device/share-link",
            baseURL: baseURL,
            credential: "synthetic-device-credential",
            installationID: "fixture-installation-0001"
        )
        let object = try jsonObject(XCTUnwrap(request.httpBody))

        XCTAssertEqual(request.url?.path, "/healthkit/device/share-link")
        XCTAssertEqual(Set(object.keys), ["installation_id"])
        XCTAssertEqual(object["installation_id"] as? String, "fixture-installation-0001")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer synthetic-device-credential"
        )
    }

    func testPrivateShareURLIsPinnedToTheBrandedCapabilityPath() throws {
        let token = String(repeating: "a", count: 43)
        XCTAssertEqual(
            try APIClient.validatedPublicShareURL(
                "https://kikuai.dev/fitkiku-health/\(token)"
            ).absoluteString,
            "https://kikuai.dev/fitkiku-health/\(token)"
        )
        for value in [
            "http://kikuai.dev/fitkiku-health/\(token)",
            "https://other.example/fitkiku-health/\(token)",
            "https://kikuai.dev/fitkiku-health/short",
            "https://kikuai.dev/fitkiku-health/\(token)/extra",
            "https://kikuai.dev/fitkiku-health/\(token)?copy=1",
            "https://user@kikuai.dev/fitkiku-health/\(token)",
        ] {
            XCTAssertThrowsError(try APIClient.validatedPublicShareURL(value))
        }
    }

    func testDeleteAccountRequestIsAuthenticatedAndScopedToInstallation() throws {
        let baseURL = try APIClient.validatedBaseURL("https://fitkiku.example")
        let request = try APIClient().makeDeleteAccountRequest(
            baseURL: baseURL,
            credential: "synthetic-device-credential",
            installationID: "fixture-installation-0001"
        )
        let object = try jsonObject(XCTUnwrap(request.httpBody))

        XCTAssertEqual(request.url?.path, "/healthkit/device/delete-account")
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
              "data_freshness": "current",
              "can_delete_account": true
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
        XCTAssertEqual(status.canDeleteAccount, true)
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

    func testLegacyDeviceStatusWithoutDeletionFlagDefaultsToNotDeletable() throws {
        let data = Data(
            """
            {
              "last_server_received_at": null,
              "last_agent_fetched_at": null,
              "latest_local_date": null,
              "last_device_generated_at": null,
              "latest_coverage": null,
              "missing_local_dates": [],
              "data_freshness": "unknown"
            }
            """.utf8
        )
        let response = try CanonicalJSON.decoder().decode(DeviceStatusResponse.self, from: data)

        XCTAssertNil(response.canDeleteAccount)
        XCTAssertFalse(try APIClient().validatedDeviceStatus(response).canDeleteAccount)
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
            dataFreshness: .current,
            canDeleteAccount: true
        )
        let parsed = try client.validatedDeviceStatus(valid)

        XCTAssertNotNil(parsed.lastServerReceivedAt)
        XCTAssertNil(parsed.lastAgentFetchedAt)
        XCTAssertEqual(parsed.latestLocalDate, "2026-08-02")
        XCTAssertEqual(parsed.dataFreshness, .current)
        XCTAssertTrue(parsed.canDeleteAccount)
        XCTAssertThrowsError(
            try client.validatedDeviceStatus(
                DeviceStatusResponse(
                    lastServerReceivedAt: "not-a-timestamp",
                    lastAgentFetchedAt: nil,
                    latestLocalDate: "2026-08-02",
                    lastDeviceGeneratedAt: "2026-08-02T11:59:00Z",
                    latestCoverage: HealthCoverage(steps: .complete, sleep: .unknown),
                    missingLocalDates: [],
                    dataFreshness: .current,
                    canDeleteAccount: false
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
                    dataFreshness: .unknown,
                    canDeleteAccount: false
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
            aiProcessingDisclosure: "Processed by the configured model provider.",
            requiresTimezone: false
        )

        XCTAssertEqual(try client.validatedAgentPreview(valid, for: baseURL), valid)

        let wrongOrigin = AgentGrantPreview(
            assertedAgentName: valid.assertedAgentName,
            serverOrigin: "https://attacker.example",
            scopes: valid.scopes,
            expiresAt: valid.expiresAt,
            retentionDisclosure: valid.retentionDisclosure,
            aiProcessingDisclosure: valid.aiProcessingDisclosure,
            requiresTimezone: valid.requiresTimezone
        )
        XCTAssertThrowsError(try client.validatedAgentPreview(wrongOrigin, for: baseURL))

        let wrongScopes = AgentGrantPreview(
            assertedAgentName: valid.assertedAgentName,
            serverOrigin: valid.serverOrigin,
            scopes: [.steps],
            expiresAt: valid.expiresAt,
            retentionDisclosure: valid.retentionDisclosure,
            aiProcessingDisclosure: valid.aiProcessingDisclosure,
            requiresTimezone: valid.requiresTimezone
        )
        XCTAssertThrowsError(try client.validatedAgentPreview(wrongScopes, for: baseURL))

        let expired = AgentGrantPreview(
            assertedAgentName: valid.assertedAgentName,
            serverOrigin: valid.serverOrigin,
            scopes: valid.scopes,
            expiresAt: "2020-01-01T00:00:00Z",
            retentionDisclosure: valid.retentionDisclosure,
            aiProcessingDisclosure: valid.aiProcessingDisclosure,
            requiresTimezone: valid.requiresTimezone
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

    func testBrandedHTTPSPairLinkParsesOpaqueToken() throws {
        let payload = try XCTUnwrap(
            PairingPayload.parse(
                "https://kikuai.dev/fitkiku/pair?server=https%3A%2F%2Fkikuai.dev&token=\(validToken)"
            )
        )
        guard case let .agent(link) = payload else {
            return XCTFail("Expected agent Pair Link")
        }
        XCTAssertEqual(link.baseURL.absoluteString, "https://kikuai.dev")
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
            "https://example.com/fitkiku/pair?server=https%3A%2F%2Ffitkiku.example&token=\(validToken)",
            "https://kikuai.dev/fitkiku/pair?server=https%3A%2F%2Fattacker.example&token=\(validToken)",
            "https://kikuai.dev/fitkiku/pair/?server=https%3A%2F%2Ffitkiku.example&token=\(validToken)",
            "https://kikuai.dev/fitkiku/connect?server=https%3A%2F%2Ffitkiku.example&token=\(validToken)",
            "https://kikuai.dev:443/fitkiku/pair?server=https%3A%2F%2Ffitkiku.example&token=\(validToken)",
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
    func testHostedFlowCreatesAndRevokesPrivateLinkWithoutDisconnecting() async throws {
        let harness = try makeModelHarness()
        defer { harness.cleanup() }

        await harness.model.beginHostedConnection()

        XCTAssertEqual(harness.model.pendingAgentConsent?.createsPrivateShareLink, true)
        XCTAssertEqual(
            harness.model.pendingAgentConsent?.baseURL.absoluteString,
            "https://fitkiku-origin.kikuai.dev"
        )
        var linkCounts = await harness.transport.privateLinkCounts()
        XCTAssertEqual(linkCounts.issue, 1)
        XCTAssertEqual(linkCounts.rotate, 0)

        await harness.model.approveAgentPairing()

        XCTAssertTrue(harness.model.isPaired)
        XCTAssertNil(harness.model.pendingAgentConsent)
        XCTAssertEqual(harness.model.privateShareURL, try harness.keychain.privateShareURL())
        XCTAssertEqual(harness.model.privateShareURL?.host, "kikuai.dev")
        linkCounts = await harness.transport.privateLinkCounts()
        XCTAssertEqual(linkCounts.rotate, 1)

        await harness.model.revokePrivateShareLink()

        XCTAssertTrue(harness.model.isPaired)
        XCTAssertNil(harness.model.privateShareURL)
        XCTAssertNil(try harness.keychain.privateShareURL())
        linkCounts = await harness.transport.privateLinkCounts()
        XCTAssertEqual(linkCounts.revoke, 1)
    }

    @MainActor
    func testPublicGuestPairingUsesTheSnapshotTimezone() async throws {
        let harness = try makeModelHarness()
        defer { harness.cleanup() }

        await harness.model.loadPairingInput(agentLink(token: validToken))
        await harness.model.approveAgentPairing()

        let pairedTimezone = await harness.transport.pairedTimezone()
        XCTAssertEqual(pairedTimezone, AppDate.timezoneIdentifier)
    }

    @MainActor
    func testDisconnectKeepsCredentialUntilServerRevocationSucceeds() async throws {
        let harness = try makeModelHarness()
        defer { harness.cleanup() }

        await harness.model.loadPairingInput(agentLink(token: validToken))
        await harness.model.approveAgentPairing()
        XCTAssertTrue(harness.model.isPaired)
        let pairedTimezone = await harness.transport.pairedTimezone()
        XCTAssertNotNil(pairedTimezone)
        XCTAssertEqual(try harness.keychain.credential(), "agent-device-credential")
        XCTAssertNotNil(harness.model.deliveryStatus?.lastServerReceivedAt)
        XCTAssertNotNil(harness.model.deliveryStatus?.lastAgentFetchedAt)
        XCTAssertEqual(harness.model.deliveryStatus?.dataFreshness, .current)
        XCTAssertEqual(harness.model.deliveryStatus?.missingLocalDates, ["2026-08-01"])
        XCTAssertTrue(harness.model.canDeleteAccount)
        XCTAssertNil(harness.model.deliveryStatusError)

        await harness.model.disconnect()
        XCTAssertTrue(harness.model.isPaired)
        XCTAssertEqual(try harness.keychain.credential(), "agent-device-credential")
        XCTAssertNotNil(harness.model.errorMessage)

        await harness.transport.allowRevocation()
        await harness.model.disconnect()
        XCTAssertFalse(harness.model.isPaired)
        XCTAssertNil(try harness.keychain.credential())
        XCTAssertNil(harness.model.deliveryStatus)
        XCTAssertNil(harness.model.deliveryStatusError)
        XCTAssertNotNil(harness.model.statusMessage)
        let observerStops = await harness.health.observerStops()
        XCTAssertEqual(observerStops, 1)
    }

    @MainActor
    func testDeleteAccountKeepsConnectionUntilServerDeletionSucceeds() async throws {
        let harness = try makeModelHarness()
        defer { harness.cleanup() }

        await harness.model.loadPairingInput(agentLink(token: validToken))
        await harness.model.approveAgentPairing()
        XCTAssertTrue(harness.model.canDeleteAccount)

        await harness.model.deleteAccount()

        XCTAssertTrue(harness.model.isPaired)
        XCTAssertEqual(try harness.keychain.credential(), "agent-device-credential")
        XCTAssertNotNil(harness.model.errorMessage)
        var counts = await harness.transport.counts()
        XCTAssertEqual(counts.delete, 1)
        XCTAssertEqual(counts.revoke, 0)

        await harness.transport.allowDeletion()
        await harness.model.deleteAccount()

        XCTAssertFalse(harness.model.isPaired)
        XCTAssertFalse(harness.model.canDeleteAccount)
        XCTAssertNil(try harness.keychain.credential())
        XCTAssertNotNil(harness.model.statusMessage)
        counts = await harness.transport.counts()
        XCTAssertEqual(counts.delete, 2)
        XCTAssertEqual(counts.revoke, 0)
    }

    @MainActor
    func testDisconnectBlocksReconnectUntilProtectedOutboxCleanupSucceeds() async throws {
        let harness = try makeModelHarness()
        defer { harness.cleanup() }

        await harness.model.loadPairingInput(agentLink(token: validToken))
        await harness.model.approveAgentPairing()
        await harness.transport.allowRevocation()
        try FileManager.default.removeItem(at: harness.outboxDirectory)
        try Data().write(to: harness.outboxDirectory)

        await harness.model.disconnect()

        XCTAssertFalse(harness.model.isPaired)
        XCTAssertTrue(harness.model.localCredentialCleanupPending)
        XCTAssertNotNil(try harness.keychain.credential())
        XCTAssertNotNil(harness.model.errorMessage)

        try FileManager.default.removeItem(at: harness.outboxDirectory)
        try FileManager.default.createDirectory(
            at: harness.outboxDirectory,
            withIntermediateDirectories: true
        )
        await harness.model.retryLocalCredentialCleanup()

        XCTAssertFalse(harness.model.localCredentialCleanupPending)
        XCTAssertNil(try harness.keychain.credential())
        XCTAssertNotNil(harness.model.statusMessage)
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
        XCTAssertNotNil(harness.model.errorMessage)
        XCTAssertNil(harness.model.lastSyncAt)
        let queuedFiles = try FileManager.default.contentsOfDirectory(
            at: harness.outboxDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        XCTAssertEqual(queuedFiles.count, 7)
    }

    @MainActor
    func testModelInstallsHealthObserversSynchronouslyBeforeRestore() async throws {
        let harness = try makeModelHarness()
        defer { harness.cleanup() }

        let observerInstalls = await harness.health.observerInstalls()
        let observerStarts = await harness.health.observerStarts()
        let observerStops = await harness.health.observerStops()
        XCTAssertEqual(observerInstalls, 1)
        XCTAssertEqual(observerStarts, 0)
        XCTAssertEqual(observerStops, 0)
    }

    @MainActor
    func testColdObserverUsesLaunchConfigurationBeforeForegroundRestore() async throws {
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
        let health = PairingTestHealthReader()
        let outboxDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(identifier, isDirectory: true)
        let model = AppModel(
            defaults: defaults,
            keychain: keychain,
            transport: transport,
            healthReader: health,
            outbox: try ProtectedOutbox(directory: outboxDirectory),
            stateStore: SyncStateStore(suiteName: suiteName),
            protectedDataAvailable: { true }
        )
        defer {
            try? keychain.deleteCredential()
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: outboxDirectory)
        }

        await health.triggerObserver()

        let readsAfterObserver = await health.dayReads()
        XCTAssertEqual(readsAfterObserver, 2)
        let counts = await transport.counts()
        XCTAssertEqual(counts.ingest, 2)
        XCTAssertEqual(counts.status, 0)
        XCTAssertEqual(readsAfterObserver, 2)
        XCTAssertFalse(model.isSyntheticDemo)
    }

    @MainActor
    func testObserverSkipsHealthReadsWhileProtectedDataIsUnavailable() async throws {
        let identifier = UUID().uuidString
        let suiteName = "FitKikuTests.\(identifier)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("https://fitkiku.example", forKey: "healthkit.server-address")
        let keychain = KeychainStore(service: "com.kikuai.fitkiku.health.tests.\(identifier)")
        try keychain.saveCredential("restored-device-credential")
        _ = try keychain.installationID()
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
            stateStore: SyncStateStore(suiteName: suiteName),
            protectedDataAvailable: { false }
        )
        defer {
            try? keychain.deleteCredential()
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: outboxDirectory)
        }

        await health.triggerObserver()

        let reads = await health.dayReads()
        let counts = await transport.counts()
        XCTAssertEqual(reads, 0)
        XCTAssertEqual(counts.ingest, 0)
        XCTAssertFalse(model.isSyntheticDemo)
    }

    @MainActor
    func testColdObserverCannotSendWhileRevokedCredentialCleanupIsPending() async throws {
        let identifier = UUID().uuidString
        let suiteName = "FitKikuTests.\(identifier)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("https://fitkiku.example", forKey: "healthkit.server-address")
        defaults.set(true, forKey: "healthkit.local-credential-cleanup-pending")
        let keychain = KeychainStore(service: "com.kikuai.fitkiku.health.tests.\(identifier)")
        try keychain.saveCredential("revoked-device-credential")
        _ = try keychain.installationID()
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
            stateStore: SyncStateStore(suiteName: suiteName),
            protectedDataAvailable: { true }
        )
        defer {
            try? keychain.deleteCredential()
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: outboxDirectory)
        }

        await health.triggerObserver()

        let reads = await health.dayReads()
        let counts = await transport.counts()
        XCTAssertEqual(reads, 0)
        XCTAssertEqual(counts.ingest, 0)
        XCTAssertFalse(model.isSyntheticDemo)
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
        let observerInstalls = await health.observerInstalls()
        XCTAssertEqual(observerInstalls, 1)
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
        let installsBeforeForeground = await harness.health.observerInstalls()
        let observersBeforeForeground = await harness.health.observerStarts()
        let stopsBeforeForeground = await harness.health.observerStops()
        let ingestsBeforeForeground = await harness.transport.counts().ingest

        await harness.model.restore()

        let readsAfterForeground = await harness.health.dayReads()
        let installsAfterForeground = await harness.health.observerInstalls()
        let observersAfterForeground = await harness.health.observerStarts()
        let stopsAfterForeground = await harness.health.observerStops()
        let ingestsAfterForeground = await harness.transport.counts().ingest
        XCTAssertEqual(readsAfterForeground - readsBeforeForeground, 9)
        XCTAssertEqual(installsAfterForeground, installsBeforeForeground)
        XCTAssertEqual(observersAfterForeground - observersBeforeForeground, 1)
        XCTAssertEqual(stopsAfterForeground, stopsBeforeForeground)
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
        XCTAssertNotNil(model.statusMessage)
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

    func testChatPromptContainsPrivateURLAndHonestFreshnessRules() throws {
        let shareURL = try XCTUnwrap(
            URL(
                string: "https://kikuai.dev/fitkiku-health/"
                    + String(repeating: "a", count: 43)
            )
        )
        let message = FitKikuChatPrompt.message(shareURL: shareURL)

        XCTAssertEqual(FitKikuChatPrompt.buttonTitle, "Copy for ChatGPT")
        XCTAssertTrue(message.contains(shareURL.absoluteString))
        XCTAssertTrue(message.contains("data_freshness"))
        XCTAssertTrue(message.contains("latest_local_date"))
        XCTAssertTrue(
            message.contains("normal HTTPS JSON URL")
                || message.contains("обычная HTTPS-ссылка с JSON")
        )
        XCTAssertTrue(
            message.contains("none is required")
                || message.contains("они не нужны")
        )
        XCTAssertTrue(
            message.contains("again before each such answer")
                || message.contains("заново перед каждым таким ответом")
        )
        XCTAssertTrue(
            message.contains("unknown, never as zero")
                || message.contains("неизвестными, а не нулевыми")
        )
        XCTAssertTrue(
            message.contains("Never repeat or expose the private URL")
                || message.contains("Никогда не повторяй и не показывай приватную ссылку")
        )
        XCTAssertFalse(message.contains("Paste a Pair Link"))
        XCTAssertFalse(message.contains("Вставь ссылку подключения"))
    }

    func testAgentReadIsCurrentOnlyAfterAgentFetchesLatestServerReceipt() {
        let serverReceipt = Date(timeIntervalSince1970: 1_775_000_100)

        XCTAssertFalse(
            deliveryStatus(
                serverReceivedAt: serverReceipt,
                agentFetchedAt: nil,
                freshness: .current
            ).hasCurrentAgentRead
        )
        XCTAssertFalse(
            deliveryStatus(
                serverReceivedAt: serverReceipt,
                agentFetchedAt: serverReceipt.addingTimeInterval(-1),
                freshness: .current
            ).hasCurrentAgentRead
        )
        XCTAssertTrue(
            deliveryStatus(
                serverReceivedAt: serverReceipt,
                agentFetchedAt: serverReceipt,
                freshness: .current
            ).hasCurrentAgentRead
        )
        XCTAssertFalse(
            deliveryStatus(
                serverReceivedAt: serverReceipt,
                agentFetchedAt: serverReceipt.addingTimeInterval(1),
                freshness: .stale
            ).hasCurrentAgentRead
        )
    }

    func testReviewPromptWaitsForTwoDistinctCurrentAgentReadsAndOneVersion() throws {
        let suiteName = "FitKikuReviewPromptPolicyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstReceipt = Date(timeIntervalSince1970: 1_775_000_000)
        let firstFetch = firstReceipt.addingTimeInterval(60)
        let first = deliveryStatus(
            serverReceivedAt: firstReceipt,
            agentFetchedAt: firstFetch,
            freshness: .current
        )
        XCTAssertFalse(
            FitKikuReviewPromptPolicy.shouldRequestReview(
                for: first,
                appVersion: "1.1",
                defaults: defaults
            )
        )
        XCTAssertFalse(
            FitKikuReviewPromptPolicy.shouldRequestReview(
                for: first,
                appVersion: "1.1",
                defaults: defaults
            )
        )

        let secondReceipt = firstReceipt.addingTimeInterval(120)
        let second = deliveryStatus(
            serverReceivedAt: secondReceipt,
            agentFetchedAt: secondReceipt.addingTimeInterval(60),
            freshness: .current
        )
        XCTAssertTrue(
            FitKikuReviewPromptPolicy.shouldRequestReview(
                for: second,
                appVersion: "1.1",
                defaults: defaults
            )
        )
        XCTAssertFalse(
            FitKikuReviewPromptPolicy.shouldRequestReview(
                for: second,
                appVersion: "1.2",
                defaults: defaults
            )
        )

        let thirdReceipt = secondReceipt.addingTimeInterval(120)
        let third = deliveryStatus(
            serverReceivedAt: thirdReceipt,
            agentFetchedAt: thirdReceipt.addingTimeInterval(60),
            freshness: .current
        )
        XCTAssertTrue(
            FitKikuReviewPromptPolicy.shouldRequestReview(
                for: third,
                appVersion: "1.2",
                defaults: defaults
            )
        )
    }

    func testSettingsLinksKeepProductAndSupportWithoutCreatorProfile() {
        XCTAssertEqual(FitKikuLinks.chatGPT.scheme, "https")
        XCTAssertEqual(FitKikuLinks.chatGPT.host, "chatgpt.com")
        XCTAssertEqual(
            FitKikuLinks.all,
            [
                FitKikuLinks.appStore,
                FitKikuLinks.review,
                FitKikuLinks.website,
                FitKikuLinks.source,
                FitKikuLinks.telegram,
                FitKikuLinks.privacy,
                FitKikuLinks.support,
            ]
        )
        XCTAssertFalse(FitKikuLinks.all.contains(URL(string: "https://github.com/kiku-jw")!))
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
        let current = AppModel.syntheticDemo(.current)
        let partial = AppModel.syntheticDemo(.partial)
        let revoked = AppModel.syntheticDemo(.revoked)

        XCTAssertEqual(
            consent.pendingAgentConsent?.preview.retentionDisclosure,
            "Daily summaries are retained until deletion is requested. "
                + "Revoking stops future access but does not delete stored summaries."
        )
        let expired = AppModel.syntheticDemo(.expired)
        let healthEmpty = AppModel.syntheticDemo(.healthEmpty)

        XCTAssertFalse(firstRun.isPaired)
        XCTAssertNil(firstRun.pendingAgentConsent)
        XCTAssertEqual(current.deliveryStatus?.hasCurrentAgentRead, true)
        XCTAssertEqual(partial.deliveryStatus?.hasCurrentAgentRead, false)
        XCTAssertEqual(
            consent.pendingAgentConsent?.preview.assertedAgentName,
            String(localized: "FitKiku private AI link")
        )
        XCTAssertFalse(consent.isPaired)
        XCTAssertTrue(revoked.localCredentialCleanupPending)
        XCTAssertFalse(revoked.isPaired)
        XCTAssertEqual(
            expired.errorMessage,
            String(localized: "This Pair Link has expired. Ask your agent for a new link.")
        )
        XCTAssertTrue(healthEmpty.healthAccessRequested)
        XCTAssertNil(healthEmpty.today)
        XCTAssertNil(healthEmpty.yesterday)
    }

    private func agentLink(token: String) -> String {
        "fitkiku-health://pair?server=https%3A%2F%2Ffitkiku.example&token=\(token)"
    }

    private func deliveryStatus(
        serverReceivedAt: Date?,
        agentFetchedAt: Date?,
        freshness: DeviceDataFreshness
    ) -> DeviceDeliveryStatus {
        DeviceDeliveryStatus(
            lastServerReceivedAt: serverReceivedAt,
            lastAgentFetchedAt: agentFetchedAt,
            latestLocalDate: "2026-08-29",
            lastDeviceGeneratedAt: serverReceivedAt,
            latestCoverage: HealthCoverage(steps: .complete, sleep: .complete),
            missingLocalDates: [],
            dataFreshness: freshness,
            canDeleteAccount: true
        )
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
    private func makeModelHarness(
        protectedDataAvailable: @escaping @Sendable () async -> Bool = { true }
    ) throws -> ModelHarness {
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
            stateStore: SyncStateStore(suiteName: suiteName),
            protectedDataAvailable: protectedDataAvailable
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
