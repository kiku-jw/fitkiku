// SPDX-License-Identifier: MPL-2.0

import XCTest
@testable import FitKiku

final class SecureStoresTests: XCTestCase {
    func testSecureStoreErrorsDoNotExposeSystemCodes() {
        let error = SecureStoreError.keychain(-34_018)

        XCTAssertEqual(
            error.errorDescription,
            "Secure storage is unavailable on this device. FitKiku cannot connect until it is available."
        )
        XCTAssertFalse(error.errorDescription?.contains("-34018") == true)
    }

    func testKeychainCredentialRotationAndStableInstallationID() throws {
        let store = KeychainStore(service: "com.kikuai.fitkiku.health.tests")
        defer { try? store.deleteCredential() }

        let firstInstallationID = try store.installationID()
        XCTAssertEqual(try store.installationID(), firstInstallationID)
        XCTAssertNil(try store.credential())

        try store.saveCredential("first-synthetic-credential")
        XCTAssertEqual(try store.credential(), "first-synthetic-credential")
        try store.saveCredential("rotated-synthetic-credential")
        XCTAssertEqual(try store.credential(), "rotated-synthetic-credential")
        try store.deleteCredential()
        XCTAssertNil(try store.credential())
    }

    func testProtectedOutboxRoundTrip() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let outbox = try ProtectedOutbox(directory: directory)
        let pending = PendingDay(
            summary: DaySummary(
                localDate: "2026-08-02",
                steps: nil,
                stepsCoverage: .unknown,
                sleepIntervals: [],
                sleepCoverage: .unknown,
                sources: []
            ),
            revision: 2
        )

        try await outbox.save(pending)
        let restored = try await outbox.pending(for: "2026-08-02")
        XCTAssertEqual(restored, pending)
        try await outbox.remove(localDate: "2026-08-02")
        let removed = try await outbox.pending(for: "2026-08-02")
        XCTAssertNil(removed)
    }
}
