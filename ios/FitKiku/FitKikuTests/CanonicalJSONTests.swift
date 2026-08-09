import XCTest
@testable import FitKiku

final class CanonicalJSONTests: XCTestCase {
    private struct Fixture: Decodable {
        let credential: String
        let unsignedPayload: UnsignedHealthSnapshot
        let canonicalJSON: String
        let signature: String
        let fractionalUnsignedPayload: UnsignedHealthSnapshot
        let fractionalCanonicalJSON: String
        let fractionalSignature: String

        private enum CodingKeys: String, CodingKey {
            case credential
            case unsignedPayload
            case canonicalJSON = "canonicalJson"
            case signature
            case fractionalUnsignedPayload
            case fractionalCanonicalJSON = "fractionalCanonicalJson"
            case fractionalSignature
        }
    }

    private struct AggregateFixture: Decodable {
        let credential: String
        let unsignedPayload: UnsignedHealthSnapshot
        let canonicalJSON: String
        let signature: String

        private enum CodingKeys: String, CodingKey {
            case credential
            case unsignedPayload = "aggregateUnsignedPayload"
            case canonicalJSON = "aggregateCanonicalJson"
            case signature = "aggregateSignature"
        }
    }

    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "healthkit_native_hmac", withExtension: "json")
        )
        return try Data(contentsOf: url)
    }

    func testPythonFixtureHasIdenticalCanonicalJSONAndHMAC() throws {
        let fixture = try CanonicalJSON.decoder().decode(Fixture.self, from: fixtureData())
        let canonical = try CanonicalJSON.encode(fixture.unsignedPayload)
        XCTAssertEqual(String(decoding: canonical, as: UTF8.self), fixture.canonicalJSON)

        let signed = try SnapshotSigner.sign(
            fixture.unsignedPayload,
            credential: fixture.credential
        )
        XCTAssertEqual(signed.signature, fixture.signature)

        let fractionalDate = try XCTUnwrap(AppDate.parseTimestamp("2026-08-02T10:11:12.987Z"))
        XCTAssertEqual(
            AppDate.timestamp(fractionalDate),
            fixture.fractionalUnsignedPayload.generatedAt
        )
        let fractionalCanonical = try CanonicalJSON.encode(fixture.fractionalUnsignedPayload)
        XCTAssertEqual(
            String(decoding: fractionalCanonical, as: UTF8.self),
            fixture.fractionalCanonicalJSON
        )
        XCTAssertEqual(
            try SnapshotSigner.sign(
                fixture.fractionalUnsignedPayload,
                credential: fixture.credential
            ).signature,
            fixture.fractionalSignature
        )

        XCTAssertNil(fixture.unsignedPayload.metrics.asleepMinutes)
        XCTAssertNil(fixture.fractionalUnsignedPayload.metrics.asleepMinutes)
    }

    func testAggregatePythonFixtureHasIdenticalCanonicalJSONAndHMAC() throws {
        let fixture = try CanonicalJSON.decoder().decode(
            AggregateFixture.self,
            from: fixtureData()
        )
        let aggregateCanonical = try CanonicalJSON.encode(fixture.unsignedPayload)
        XCTAssertEqual(
            String(decoding: aggregateCanonical, as: UTF8.self),
            fixture.canonicalJSON
        )
        XCTAssertEqual(fixture.unsignedPayload.schemaVersion, "1.1")
        XCTAssertEqual(fixture.unsignedPayload.metrics.asleepMinutes, 390)
        XCTAssertTrue(fixture.unsignedPayload.sleepIntervals.isEmpty)
        XCTAssertEqual(
            try SnapshotSigner.sign(
                fixture.unsignedPayload,
                credential: fixture.credential
            ).signature,
            fixture.signature
        )
    }

    func testUnknownCoverageDoesNotManufactureZero() throws {
        let summary = DaySummary(
            localDate: "2026-08-02",
            steps: nil,
            stepsCoverage: .unknown,
            sleepIntervals: [],
            sleepCoverage: .unknown,
            sources: []
        )
        let data = try CanonicalJSON.encode(
            summary.unsignedSnapshot(
                installationID: "fixture-installation-0001",
                revision: 1,
                generatedAt: Date(timeIntervalSince1970: 0)
            )
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let metrics = try XCTUnwrap(object["metrics"] as? [String: Any])
        XCTAssertNil(metrics["steps"])
        XCTAssertNil(metrics["asleep_minutes"])
        XCTAssertEqual((object["coverage"] as? [String: String])?["steps"], "unknown")
        XCTAssertEqual((object["coverage"] as? [String: String])?["sleep"], "unknown")
        XCTAssertEqual((object["sleep_intervals"] as? [Any])?.count, 0)
    }
}
