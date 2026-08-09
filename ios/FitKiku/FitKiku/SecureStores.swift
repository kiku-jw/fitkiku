import Foundation
import Security

enum SecureStoreError: LocalizedError {
    case keychain(OSStatus)
    case invalidStoredValue

    var errorDescription: String? {
        switch self {
        case .keychain:
            "Secure storage is unavailable on this device. FitKiku cannot connect until it is available."
        case .invalidStoredValue:
            "Secure storage could not be read. Disconnect and connect FitKiku again."
        }
    }
}

struct KeychainStore: Sendable {
    private let service: String
    private let credentialAccount = "healthkit-device-credential"
    private let installationAccount = "healthkit-installation-id"

    init(service: String = "com.kikuai.fitkiku.health") {
        self.service = service
    }

    func installationID() throws -> String {
        if let existing = try load(account: installationAccount) {
            return existing
        }
        let created = UUID().uuidString.lowercased()
        try save(created, account: installationAccount)
        return created
    }

    func credential() throws -> String? {
        try load(account: credentialAccount)
    }

    func saveCredential(_ credential: String) throws {
        try save(credential, account: credentialAccount)
    }

    func deleteCredential() throws {
        let status = SecItemDelete(query(account: credentialAccount) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStoreError.keychain(status)
        }
    }

    private func save(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw SecureStoreError.invalidStoredValue
        }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(
            query(account: account) as CFDictionary,
            attributes as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw SecureStoreError.keychain(updateStatus)
        }
        let item = query(account: account).merging(attributes) { _, new in new }
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecureStoreError.keychain(status)
        }
    }

    private func load(account: String) throws -> String? {
        let request = query(account: account).merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]) { _, new in new }
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw SecureStoreError.keychain(status)
        }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw SecureStoreError.invalidStoredValue
        }
        return value
    }

    private func query(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

actor SyncStateStore {
    private let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults = .standard, storageKey: String = "healthkit.confirmed-days") {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    init(suiteName: String, storageKey: String = "healthkit.confirmed-days") {
        defaults = UserDefaults(suiteName: suiteName)!
        self.storageKey = storageKey
    }

    func state(for localDate: String) -> ConfirmedDayState? {
        loadAll()[localDate]
    }

    func confirm(_ state: ConfirmedDayState, for localDate: String) throws {
        var states = loadAll()
        states[localDate] = state
        defaults.set(try CanonicalJSON.encoder().encode(states), forKey: storageKey)
    }

    func clear() {
        defaults.removeObject(forKey: storageKey)
    }

    private func loadAll() -> [String: ConfirmedDayState] {
        guard let data = defaults.data(forKey: storageKey) else { return [:] }
        return (try? CanonicalJSON.decoder().decode([String: ConfirmedDayState].self, from: data)) ?? [:]
    }
}

actor ProtectedOutbox {
    private let directory: URL

    init(directory: URL? = nil) throws {
        if let directory {
            self.directory = directory
        } else {
            let root = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            self.directory = root.appendingPathComponent("FitKikuHealthOutbox", isDirectory: true)
        }
        try FileManager.default.createDirectory(
            at: self.directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDirectory = self.directory
        try mutableDirectory.setResourceValues(values)
    }

    func pending(for localDate: String) throws -> PendingDay? {
        let file = fileURL(for: localDate)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return try CanonicalJSON.decoder().decode(PendingDay.self, from: Data(contentsOf: file))
    }

    func save(_ pending: PendingDay) throws {
        let data = try CanonicalJSON.encoder().encode(pending)
        try data.write(
            to: fileURL(for: pending.summary.localDate),
            options: [.atomic, .completeFileProtection]
        )
    }

    func remove(localDate: String) throws {
        let file = fileURL(for: localDate)
        if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
    }

    func clear() throws {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        for file in files where file.pathExtension == "json" {
            try FileManager.default.removeItem(at: file)
        }
    }

    private func fileURL(for localDate: String) -> URL {
        let safeName = localDate.filter { $0.isNumber || $0 == "-" }
        return directory.appendingPathComponent("\(safeName).json", isDirectory: false)
    }
}
