import CryptoKit
import Foundation

enum CanonicalJSON {
    static func encoder(sortedKeys: Bool = true) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        if sortedKeys {
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        } else {
            encoder.outputFormatting = [.withoutEscapingSlashes]
        }
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder().encode(value)
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
enum SnapshotSigner {
    static func sign(
        _ unsigned: UnsignedHealthSnapshot,
        credential: String
    ) throws -> HealthSnapshotPayload {
        let canonical = try CanonicalJSON.encode(unsigned)
        let key = SymmetricKey(data: Data(credential.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: canonical, using: key)
            .map { String(format: "%02x", $0) }
            .joined()
        return HealthSnapshotPayload(
            schemaVersion: unsigned.schemaVersion,
            deviceInstallationID: unsigned.deviceInstallationID,
            localDate: unsigned.localDate,
            timezone: unsigned.timezone,
            syncRevision: unsigned.syncRevision,
            generatedAt: unsigned.generatedAt,
            idempotencyKey: unsigned.idempotencyKey,
            metrics: unsigned.metrics,
            coverage: unsigned.coverage,
            sleepIntervals: unsigned.sleepIntervals,
            workouts: unsigned.workouts,
            sources: unsigned.sources,
            signature: signature
        )
    }
}
