// SPDX-License-Identifier: MPL-2.0

import Foundation

enum APIClientError: LocalizedError, Equatable {
    case invalidBaseURL
    case invalidPairingCode
    case invalidPairingToken
    case invalidPreview
    case invalidResponse
    case httpStatus(Int)
    case transport

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "Use a valid HTTPS FitKiku server address."
        case .invalidPairingCode:
            "Enter the current eight-digit recovery code."
        case .invalidPairingToken:
            "This Pair Link has an invalid or incomplete token."
        case .invalidPreview:
            "The server returned pairing details that do not match this Pair Link."
        case .invalidResponse:
            "The FitKiku server returned an invalid response."
        case let .httpStatus(status):
            "The FitKiku server rejected the request (HTTP \(status))."
        case .transport:
            "The FitKiku server is currently unreachable."
        }
    }
}

protocol HealthTransport: Sendable {
    func pair(baseURL: URL, code: String, installationID: String) async throws -> String
    func ingest(
        baseURL: URL,
        credential: String,
        snapshot: HealthSnapshotPayload
    ) async throws -> String
}

protocol AgentPairingTransport: Sendable {
    func previewAgentGrant(baseURL: URL, pairingToken: String) async throws -> AgentGrantPreview
    func pairAgent(
        baseURL: URL,
        pairingToken: String,
        installationID: String,
        timezone: String?
    ) async throws -> String
    func revokeDevice(
        baseURL: URL,
        credential: String,
        installationID: String
    ) async throws -> String
    func deleteAccount(
        baseURL: URL,
        credential: String,
        installationID: String
    ) async throws -> String
    func deviceStatus(
        baseURL: URL,
        credential: String,
        installationID: String
    ) async throws -> DeviceDeliveryStatus
}

protocol AppTransport: HealthTransport, AgentPairingTransport {}

struct PairRequest: Codable, Sendable {
    let code: String
    let installationID: String
    let appVersion: String

    private enum CodingKeys: String, CodingKey {
        case code
        case installationID = "installation_id"
        case appVersion = "app_version"
    }
}

struct PairResponse: Codable, Sendable {
    let credential: String
}

struct IngestResponse: Codable, Sendable {
    let outcome: String
}

struct AgentGrantPreviewRequest: Codable, Equatable, Sendable {
    let pairingToken: String

    private enum CodingKeys: String, CodingKey {
        case pairingToken = "pairing_token"
    }
}

enum HealthReadScope: String, Codable, Hashable, Sendable {
    case steps
    case sleep
}

struct AgentGrantPreview: Codable, Equatable, Sendable {
    let assertedAgentName: String
    let serverOrigin: String
    let scopes: [HealthReadScope]
    let expiresAt: String
    let retentionDisclosure: String
    let aiProcessingDisclosure: String
    let requiresTimezone: Bool?

    var formattedExpiresAt: String {
        guard let date = AppDate.parseTimestamp(expiresAt) else { return expiresAt }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

struct AgentPairRequest: Codable, Equatable, Sendable {
    let pairingToken: String
    let installationID: String
    let appVersion: String
    let timezone: String?

    private enum CodingKeys: String, CodingKey {
        case pairingToken = "pairing_token"
        case installationID = "installation_id"
        case appVersion = "app_version"
        case timezone
    }
}

struct DeviceRevokeRequest: Codable, Equatable, Sendable {
    let installationID: String

    private enum CodingKeys: String, CodingKey {
        case installationID = "installation_id"
    }
}

struct DeviceRevokeResponse: Codable, Equatable, Sendable {
    let outcome: String
}

struct DeviceStatusResponse: Codable, Equatable, Sendable {
    let lastServerReceivedAt: String?
    let lastAgentFetchedAt: String?
    let latestLocalDate: String?
    let lastDeviceGeneratedAt: String?
    let latestCoverage: HealthCoverage?
    let missingLocalDates: [String]
    let dataFreshness: DeviceDataFreshness
    let canDeleteAccount: Bool?
}

enum DeviceDataFreshness: String, Codable, Equatable, Sendable {
    case unknown
    case current
    case stale
}

struct DeviceDeliveryStatus: Equatable, Sendable {
    let lastServerReceivedAt: Date?
    let lastAgentFetchedAt: Date?
    let latestLocalDate: String?
    let lastDeviceGeneratedAt: Date?
    let latestCoverage: HealthCoverage?
    let missingLocalDates: [String]
    let dataFreshness: DeviceDataFreshness
    let canDeleteAccount: Bool
}

enum PairingPayloadError: LocalizedError, Equatable {
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            "Use the complete Pair Link provided by your agent."
        }
    }
}

struct AgentPairingLink: Equatable, Sendable {
    let baseURL: URL
    let pairingToken: String
}

struct LegacyPairingLink: Equatable, Sendable {
    let baseURL: URL
    let code: String
}

enum PairingPayload: Equatable, Sendable {
    case agent(AgentPairingLink)
    case legacy(LegacyPairingLink)

    private static let brandedHTTPSHost = "kikuai.dev"
    private static let brandedHTTPSPath = "/fitkiku/pair"

    static func parse(_ value: String) throws -> PairingPayload? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        guard let components = URLComponents(string: trimmed),
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.fragment == nil,
              isAllowedEntryPoint(components)
        else {
            throw PairingPayloadError.invalidPayload
        }

        let items = components.queryItems ?? []
        guard items.count == 2,
              items.allSatisfy({ $0.value != nil }),
              Set(items.map(\.name)).count == items.count
        else {
            throw PairingPayloadError.invalidPayload
        }
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        guard let server = values["server"] else {
            throw PairingPayloadError.invalidPayload
        }
        let baseURL: URL
        do {
            baseURL = try APIClient.validatedBaseURL(server)
        } catch {
            throw PairingPayloadError.invalidPayload
        }
        if isBrandedHTTPSEntryPoint(components),
           !(baseURL.scheme == "https"
               && baseURL.host?.lowercased() == brandedHTTPSHost
               && baseURL.port == nil)
        {
            throw PairingPayloadError.invalidPayload
        }

        if Set(values.keys) == ["server", "token"], let token = values["token"] {
            guard APIClient.isValidPairingToken(token) else {
                throw PairingPayloadError.invalidPayload
            }
            return .agent(AgentPairingLink(baseURL: baseURL, pairingToken: token))
        }
        if Set(values.keys) == ["server", "code"],
           let code = values["code"],
           code.count == 8,
           code.allSatisfy(\.isNumber)
        {
            return .legacy(LegacyPairingLink(baseURL: baseURL, code: code))
        }
        throw PairingPayloadError.invalidPayload
    }

    private static func isAllowedEntryPoint(_ components: URLComponents) -> Bool {
        let scheme = components.scheme?.lowercased()
        let host = components.host?.lowercased()
        let isPrivateScheme = scheme == "fitkiku-health"
            && host == "pair"
            && components.path.isEmpty
        return isPrivateScheme || isBrandedHTTPSEntryPoint(components)
    }

    private static func isBrandedHTTPSEntryPoint(_ components: URLComponents) -> Bool {
        components.scheme?.lowercased() == "https"
            && components.host?.lowercased() == brandedHTTPSHost
            && components.path == brandedHTTPSPath
    }
}

struct APIClient: AppTransport, Sendable {
    private static let applicationVersion = "native/1.0"
    private static let pairingTokenLength = 43 ... 128

    private let session: URLSession
    private let redirectDelegate = RejectRedirectDelegate()
    private let pairingTimeout: TimeInterval
    private let ingestTimeout: TimeInterval

    init(
        session: URLSession? = nil,
        pairingTimeout: TimeInterval = 20,
        ingestTimeout: TimeInterval = 30
    ) {
        self.session = session ?? Self.ephemeralSession()
        self.pairingTimeout = pairingTimeout
        self.ingestTimeout = ingestTimeout
    }

    private static func ephemeralSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }

    static func validatedBaseURL(
        _ value: String,
        allowInsecureLocalhost: Bool = _isDebugAssertConfiguration()
    ) throws -> URL {
        guard var components = URLComponents(
            string: value.trimmingCharacters(in: .whitespacesAndNewlines)
        ),
        let host = components.host,
        !host.isEmpty,
        components.user == nil,
        components.password == nil,
        components.query == nil,
        components.fragment == nil
        else {
            throw APIClientError.invalidBaseURL
        }
        let localHosts = ["localhost", "127.0.0.1", "::1"]
        let scheme = components.scheme?.lowercased()
        let secure = scheme == "https"
        let debugLocal = allowInsecureLocalhost
            && scheme == "http"
            && localHosts.contains(host.lowercased())
        guard secure || debugLocal else {
            throw APIClientError.invalidBaseURL
        }
        guard components.path.isEmpty || components.path == "/" else {
            throw APIClientError.invalidBaseURL
        }
        components.scheme = scheme
        components.host = host.lowercased()
        components.path = ""
        guard let url = components.url else {
            throw APIClientError.invalidBaseURL
        }
        return url
    }

    static func isValidPairingToken(_ token: String) -> Bool {
        guard pairingTokenLength.contains(token.count) else { return false }
        return token.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 45, 48 ... 57, 65 ... 90, 95, 97 ... 122:
                true
            default:
                false
            }
        }
    }

    func pair(
        baseURL: URL,
        code: String,
        installationID: String
    ) async throws -> String {
        guard code.count == 8, code.allSatisfy(\.isNumber) else {
            throw APIClientError.invalidPairingCode
        }
        var request = URLRequest(url: endpoint("healthkit/pair", baseURL: baseURL))
        request.httpMethod = "POST"
        request.timeoutInterval = pairingTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try CanonicalJSON.encoder(sortedKeys: false).encode(
            PairRequest(
                code: code,
                installationID: installationID,
                appVersion: Self.applicationVersion
            )
        )
        let data = try await perform(request)
        let credential = try CanonicalJSON.decoder().decode(PairResponse.self, from: data).credential
        guard !credential.isEmpty else { throw APIClientError.invalidResponse }
        return credential
    }

    func previewAgentGrant(
        baseURL: URL,
        pairingToken: String
    ) async throws -> AgentGrantPreview {
        let request = try makeAgentPreviewRequest(
            baseURL: baseURL,
            pairingToken: pairingToken
        )
        let data = try await perform(request)
        let preview: AgentGrantPreview
        do {
            preview = try CanonicalJSON.decoder().decode(AgentGrantPreview.self, from: data)
        } catch {
            throw APIClientError.invalidResponse
        }
        return try validatedAgentPreview(preview, for: baseURL)
    }

    func validatedAgentPreview(
        _ preview: AgentGrantPreview,
        for baseURL: URL
    ) throws -> AgentGrantPreview {
        let agentName = preview.assertedAgentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let retention = preview.retentionDisclosure.trimmingCharacters(in: .whitespacesAndNewlines)
        let aiProcessing = preview.aiProcessingDisclosure.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let responseOrigin = try? Self.validatedBaseURL(preview.serverOrigin),
              let expiresAt = Self.iso8601Date(preview.expiresAt),
              expiresAt > Date(),
              responseOrigin == baseURL,
              Set(preview.scopes) == [.steps, .sleep],
              preview.scopes.count == 2,
              (1 ... 200).contains(agentName.count),
              (1 ... 2_000).contains(retention.count),
              (1 ... 2_000).contains(aiProcessing.count)
        else {
            throw APIClientError.invalidPreview
        }
        return preview
    }

    private static func iso8601Date(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        let wholeSeconds = ISO8601DateFormatter()
        wholeSeconds.formatOptions = [.withInternetDateTime]
        return wholeSeconds.date(from: value)
    }

    func pairAgent(
        baseURL: URL,
        pairingToken: String,
        installationID: String,
        timezone: String?
    ) async throws -> String {
        let request = try makeAgentPairRequest(
            baseURL: baseURL,
            pairingToken: pairingToken,
            installationID: installationID,
            timezone: timezone
        )
        let data = try await perform(request)
        let credential = try CanonicalJSON.decoder().decode(PairResponse.self, from: data).credential
        guard !credential.isEmpty else { throw APIClientError.invalidResponse }
        return credential
    }

    func revokeDevice(
        baseURL: URL,
        credential: String,
        installationID: String
    ) async throws -> String {
        let request = try makeDeviceRevokeRequest(
            baseURL: baseURL,
            credential: credential,
            installationID: installationID
        )
        let data = try await perform(request)
        let outcome = try CanonicalJSON.decoder().decode(DeviceRevokeResponse.self, from: data).outcome
        guard !outcome.isEmpty else { throw APIClientError.invalidResponse }
        return outcome
    }

    func deleteAccount(
        baseURL: URL,
        credential: String,
        installationID: String
    ) async throws -> String {
        let request = try makeDeleteAccountRequest(
            baseURL: baseURL,
            credential: credential,
            installationID: installationID
        )
        let data = try await perform(request)
        let outcome = try CanonicalJSON.decoder().decode(DeviceRevokeResponse.self, from: data).outcome
        guard !outcome.isEmpty else { throw APIClientError.invalidResponse }
        return outcome
    }

    func deviceStatus(
        baseURL: URL,
        credential: String,
        installationID: String
    ) async throws -> DeviceDeliveryStatus {
        let request = try makeDeviceStatusRequest(
            baseURL: baseURL,
            credential: credential,
            installationID: installationID
        )
        let data = try await perform(request)
        let response: DeviceStatusResponse
        do {
            response = try CanonicalJSON.decoder().decode(DeviceStatusResponse.self, from: data)
        } catch {
            throw APIClientError.invalidResponse
        }
        return try validatedDeviceStatus(response)
    }

    func validatedDeviceStatus(_ response: DeviceStatusResponse) throws -> DeviceDeliveryStatus {
        let serverReceived = try Self.optionalISO8601Date(response.lastServerReceivedAt)
        let agentFetched = try Self.optionalISO8601Date(response.lastAgentFetchedAt)
        let deviceGenerated = try Self.optionalISO8601Date(response.lastDeviceGeneratedAt)
        let dates = [response.latestLocalDate].compactMap { $0 } + response.missingLocalDates
        guard dates.count <= 4,
              Set(dates).count == dates.count,
              dates.allSatisfy(Self.isValidLocalDate)
        else {
            throw APIClientError.invalidResponse
        }
        if response.latestLocalDate == nil {
            guard deviceGenerated == nil,
                  response.latestCoverage == nil,
                  response.dataFreshness == .unknown
            else {
                throw APIClientError.invalidResponse
            }
        } else {
            guard deviceGenerated != nil,
                  serverReceived != nil,
                  response.latestCoverage != nil,
                  response.dataFreshness != .unknown
            else {
                throw APIClientError.invalidResponse
            }
        }
        return DeviceDeliveryStatus(
            lastServerReceivedAt: serverReceived,
            lastAgentFetchedAt: agentFetched,
            latestLocalDate: response.latestLocalDate,
            lastDeviceGeneratedAt: deviceGenerated,
            latestCoverage: response.latestCoverage,
            missingLocalDates: response.missingLocalDates,
            dataFreshness: response.dataFreshness,
            canDeleteAccount: response.canDeleteAccount ?? false
        )
    }

    func ingest(
        baseURL: URL,
        credential: String,
        snapshot: HealthSnapshotPayload
    ) async throws -> String {
        var request = URLRequest(url: endpoint("healthkit/ingest", baseURL: baseURL))
        request.httpMethod = "POST"
        request.timeoutInterval = ingestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        request.httpBody = try CanonicalJSON.encoder(sortedKeys: false).encode(snapshot)
        let data = try await perform(request)
        return try CanonicalJSON.decoder().decode(IngestResponse.self, from: data).outcome
    }

    func makeAgentPreviewRequest(baseURL: URL, pairingToken: String) throws -> URLRequest {
        guard Self.isValidPairingToken(pairingToken) else {
            throw APIClientError.invalidPairingToken
        }
        var request = URLRequest(url: endpoint("healthkit/agent-grants/preview", baseURL: baseURL))
        request.httpMethod = "POST"
        request.timeoutInterval = pairingTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try CanonicalJSON.encoder(sortedKeys: false).encode(
            AgentGrantPreviewRequest(pairingToken: pairingToken)
        )
        return request
    }

    func makeAgentPairRequest(
        baseURL: URL,
        pairingToken: String,
        installationID: String,
        timezone: String? = nil
    ) throws -> URLRequest {
        guard Self.isValidPairingToken(pairingToken) else {
            throw APIClientError.invalidPairingToken
        }
        var request = URLRequest(url: endpoint("healthkit/agent-pair", baseURL: baseURL))
        request.httpMethod = "POST"
        request.timeoutInterval = pairingTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try CanonicalJSON.encoder(sortedKeys: false).encode(
            AgentPairRequest(
                pairingToken: pairingToken,
                installationID: installationID,
                appVersion: Self.applicationVersion,
                timezone: timezone
            )
        )
        return request
    }

    func makeDeviceRevokeRequest(
        baseURL: URL,
        credential: String,
        installationID: String
    ) throws -> URLRequest {
        guard !credential.isEmpty else { throw APIClientError.invalidResponse }
        var request = URLRequest(url: endpoint("healthkit/device/revoke", baseURL: baseURL))
        request.httpMethod = "POST"
        request.timeoutInterval = pairingTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        request.httpBody = try CanonicalJSON.encoder(sortedKeys: false).encode(
            DeviceRevokeRequest(installationID: installationID)
        )
        return request
    }

    func makeDeleteAccountRequest(
        baseURL: URL,
        credential: String,
        installationID: String
    ) throws -> URLRequest {
        guard !credential.isEmpty else { throw APIClientError.invalidResponse }
        var request = URLRequest(url: endpoint("healthkit/device/delete-account", baseURL: baseURL))
        request.httpMethod = "POST"
        request.timeoutInterval = pairingTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        request.httpBody = try CanonicalJSON.encoder(sortedKeys: false).encode(
            DeviceRevokeRequest(installationID: installationID)
        )
        return request
    }

    func makeDeviceStatusRequest(
        baseURL: URL,
        credential: String,
        installationID: String
    ) throws -> URLRequest {
        guard !credential.isEmpty,
              (16 ... 128).contains(installationID.count),
              var components = URLComponents(
                  url: endpoint("healthkit/device/status", baseURL: baseURL),
                  resolvingAgainstBaseURL: false
              )
        else {
            throw APIClientError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "installation_id", value: installationID)]
        guard let url = components.url else { throw APIClientError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = pairingTimeout
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        return request
    }

    private static func optionalISO8601Date(_ value: String?) throws -> Date? {
        guard let value else { return nil }
        guard let parsed = iso8601Date(value) else { throw APIClientError.invalidResponse }
        return parsed
    }

    private static func isValidLocalDate(_ value: String) -> Bool {
        guard value.count == 10 else { return false }
        let formatter = DateFormatter()
        formatter.calendar = AppDate.calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = AppDate.calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let parsed = formatter.date(from: value) else { return false }
        return formatter.string(from: parsed) == value
    }

    private func endpoint(_ path: String, baseURL: URL) -> URL {
        path.split(separator: "/").reduce(baseURL) { url, component in
            url.appendingPathComponent(String(component), isDirectory: false)
        }
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request, delegate: redirectDelegate)
        } catch {
            throw APIClientError.transport
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw APIClientError.httpStatus(http.statusCode)
        }
        return data
    }
}

final class RejectRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
