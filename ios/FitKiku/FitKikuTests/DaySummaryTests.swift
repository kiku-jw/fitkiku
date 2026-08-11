// SPDX-License-Identifier: MPL-2.0

import XCTest
@testable import FitKiku

final class DaySummaryTests: XCTestCase {
    func testPublicProductLinksUseHTTPSAndExpectedHosts() throws {
        XCTAssertEqual(Set(FitKikuLinks.all.compactMap(\.scheme)), ["https"])
        XCTAssertEqual(FitKikuLinks.website.host, "kikuai.dev")
        XCTAssertEqual(FitKikuLinks.source.host, "github.com")
        XCTAssertEqual(FitKikuLinks.telegram.host, "t.me")
        XCTAssertEqual(FitKikuLinks.privacy.host, "kikuai.dev")
        XCTAssertEqual(FitKikuLinks.support.host, "kikuai.dev")
        XCTAssertEqual(FitKikuLinks.all.count, 5)
    }

    func testNormalizationDeduplicatesAndMergesOverlappingSleepForDisplay() throws {
        let first = SleepIntervalPayload(
            start: "2026-08-01T21:00:00Z",
            end: "2026-08-01T22:00:00Z",
            category: .core
        )
        let overlapping = SleepIntervalPayload(
            start: "2026-08-01T21:30:00Z",
            end: "2026-08-01T22:30:00Z",
            category: .deep
        )
        let source = HealthSourcePayload(
            name: "Synthetic",
            bundleIdentifier: "com.example.synthetic",
            productType: nil
        )
        let summary = DaySummary(
            localDate: "2026-08-02",
            steps: 5000,
            stepsCoverage: .complete,
            sleepIntervals: [overlapping, first, first],
            sleepCoverage: .complete,
            sources: [source, source]
        )

        XCTAssertEqual(summary.normalized.sleepIntervals, [first, overlapping])
        XCTAssertEqual(summary.normalized.sources, [source])
        XCTAssertEqual(summary.asleepMinutes, 90)
    }

    func testSnapshotKeepsIntervalNormalizationLocalAndSendsAggregateSleep() throws {
        let summary = DaySummary(
            localDate: "2026-08-02",
            steps: nil,
            stepsCoverage: .unknown,
            sleepIntervals: [
                SleepIntervalPayload(
                    start: "2026-08-01T21:00:00.123Z",
                    end: "2026-08-01T22:00:00.987Z",
                    category: .core
                )
            ],
            sleepCoverage: .complete,
            sources: []
        )
        let normalizedInterval = try XCTUnwrap(summary.normalized.sleepIntervals.first)
        XCTAssertEqual(normalizedInterval.start, "2026-08-01T21:00:00.123000Z")
        XCTAssertEqual(normalizedInterval.end, "2026-08-01T22:00:00.987000Z")

        let snapshot = try summary.unsignedSnapshot(
            installationID: "fixture-installation-0001",
            revision: 1,
            generatedAt: try XCTUnwrap(AppDate.parseTimestamp("2026-08-02T10:11:12.987Z"))
        )

        XCTAssertEqual(snapshot.schemaVersion, "1.1")
        XCTAssertEqual(snapshot.generatedAt, "2026-08-02T10:11:12.987000Z")
        XCTAssertEqual(snapshot.metrics.asleepMinutes, 60)
        XCTAssertTrue(snapshot.sleepIntervals.isEmpty)

        let signed = try SnapshotSigner.sign(snapshot, credential: "synthetic-credential")
        let outboundJSON = String(decoding: try CanonicalJSON.encode(signed), as: UTF8.self)
        XCTAssertTrue(outboundJSON.contains("\"sleep_intervals\":[]"))
        XCTAssertFalse(outboundJSON.contains(normalizedInterval.start))
        XCTAssertFalse(outboundJSON.contains(normalizedInterval.end))
    }

    func testNormalizationPreservesValidSubsecondSleepInterval() throws {
        let summary = DaySummary(
            localDate: "2026-08-02",
            steps: nil,
            stepsCoverage: .unknown,
            sleepIntervals: [
                SleepIntervalPayload(
                    start: "2026-08-01T21:00:00.100Z",
                    end: "2026-08-01T21:00:00.900Z",
                    category: .core
                )
            ],
            sleepCoverage: .complete,
            sources: []
        )

        let interval = try XCTUnwrap(summary.normalized.sleepIntervals.first)
        XCTAssertEqual(interval.start, "2026-08-01T21:00:00.100000Z")
        XCTAssertEqual(interval.end, "2026-08-01T21:00:00.900000Z")
        XCTAssertGreaterThan(
            try XCTUnwrap(AppDate.parseTimestamp(interval.end)),
            try XCTUnwrap(AppDate.parseTimestamp(interval.start))
        )
    }

    func testPartialSleepWithoutAsleepSamplesDoesNotManufactureZero() throws {
        let summary = DaySummary(
            localDate: "2026-08-02",
            steps: nil,
            stepsCoverage: .unknown,
            sleepIntervals: [
                SleepIntervalPayload(
                    start: "2026-08-01T21:00:00Z",
                    end: "2026-08-01T22:00:00Z",
                    category: .inBed
                ),
                SleepIntervalPayload(
                    start: "2026-08-01T22:00:00Z",
                    end: "2026-08-01T22:10:00Z",
                    category: .awake
                )
            ],
            sleepCoverage: .partial,
            sources: []
        )

        XCTAssertNil(summary.asleepMinutes)
        let snapshot = try summary.unsignedSnapshot(
            installationID: "fixture-installation-0001",
            revision: 1,
            generatedAt: Date(timeIntervalSince1970: 0)
        )
        XCTAssertNil(snapshot.metrics.asleepMinutes)
        XCTAssertTrue(snapshot.sleepIntervals.isEmpty)

        let data = try CanonicalJSON.encode(snapshot)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let metrics = try XCTUnwrap(object["metrics"] as? [String: Any])
        XCTAssertNil(metrics["asleep_minutes"])
        XCTAssertEqual((object["coverage"] as? [String: String])?["sleep"], "partial")
    }

    func testCompleteKnownSleepWithoutAsleepIntervalsPreservesZero() throws {
        let summary = DaySummary(
            localDate: "2026-08-02",
            steps: nil,
            stepsCoverage: .unknown,
            sleepIntervals: [],
            sleepCoverage: .complete,
            sources: []
        )

        XCTAssertEqual(summary.asleepMinutes, 0)
        let snapshot = try summary.unsignedSnapshot(
            installationID: "fixture-installation-0001",
            revision: 1,
            generatedAt: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(snapshot.metrics.asleepMinutes, 0)
        XCTAssertTrue(snapshot.sleepIntervals.isEmpty)
    }

    func testConsentDisclosureNamesAggregateAndLocalIntervalBoundary() {
        XCTAssertTrue(NativeHealthDisclosure.outbound.contains("asleep minutes"))
        XCTAssertTrue(
            NativeHealthDisclosure.outbound.contains(
                "Sleep interval times and categories stay on this iPhone"
            )
        )
    }

    func testSleepSamplesAreAssignedByKyivWakeDate() throws {
        let targetDay = try XCTUnwrap(AppDate.parseTimestamp("2026-08-01T21:00:00Z"))
        let previousDayNapStart = try XCTUnwrap(
            AppDate.parseTimestamp("2026-08-01T10:00:00Z")
        )
        let previousDayNapEnd = try XCTUnwrap(
            AppDate.parseTimestamp("2026-08-01T11:00:00Z")
        )
        let overnightStart = try XCTUnwrap(AppDate.parseTimestamp("2026-08-01T20:30:00Z"))
        let overnightEnd = try XCTUnwrap(AppDate.parseTimestamp("2026-08-02T04:30:00Z"))
        let targetDayNapStart = try XCTUnwrap(
            AppDate.parseTimestamp("2026-08-02T11:00:00Z")
        )
        let targetDayNapEnd = try XCTUnwrap(AppDate.parseTimestamp("2026-08-02T12:00:00Z"))
        let nextNightEnd = try XCTUnwrap(AppDate.parseTimestamp("2026-08-03T04:30:00Z"))

        XCTAssertFalse(
            HealthKitClient.isAssignedToSleepDay(
                start: previousDayNapStart,
                end: previousDayNapEnd,
                dayStart: targetDay
            )
        )
        XCTAssertTrue(
            HealthKitClient.isAssignedToSleepDay(
                start: overnightStart,
                end: overnightEnd,
                dayStart: targetDay
            )
        )
        XCTAssertTrue(
            HealthKitClient.isAssignedToSleepDay(
                start: targetDayNapStart,
                end: targetDayNapEnd,
                dayStart: targetDay
            )
        )
        XCTAssertFalse(
            HealthKitClient.isAssignedToSleepDay(
                start: targetDayNapStart,
                end: nextNightEnd,
                dayStart: targetDay
            )
        )
        XCTAssertFalse(
            HealthKitClient.isAssignedToSleepDay(
                start: overnightEnd,
                end: overnightStart,
                dayStart: targetDay
            )
        )
    }

    func testPlannerUsesMonotonicRevisionAndStableContentKey() throws {
        let summary = DaySummary(
            localDate: "2026-08-02",
            steps: 5000,
            stepsCoverage: .complete,
            sleepIntervals: [],
            sleepCoverage: .unknown,
            sources: []
        )
        let prior = ConfirmedDayState(contentDigest: "old", revision: 4)
        let pending = try XCTUnwrap(SyncPlanner.nextPending(summary: summary, confirmed: prior))
        XCTAssertEqual(pending.revision, 5)

        let first = try pending.summary.unsignedSnapshot(
            installationID: "fixture-installation-0001",
            revision: pending.revision,
            generatedAt: Date(timeIntervalSince1970: 1)
        )
        let retry = try pending.summary.unsignedSnapshot(
            installationID: "fixture-installation-0001",
            revision: pending.revision,
            generatedAt: Date(timeIntervalSince1970: 2)
        )
        XCTAssertEqual(first.idempotencyKey, retry.idempotencyKey)
        XCTAssertEqual(first.syncRevision, retry.syncRevision)
        XCTAssertNotEqual(first.generatedAt, retry.generatedAt)

        let otherInstallation = try pending.summary.unsignedSnapshot(
            installationID: "fixture-installation-0002",
            revision: pending.revision,
            generatedAt: Date(timeIntervalSince1970: 1)
        )
        XCTAssertNotEqual(first.idempotencyKey, otherInstallation.idempotencyKey)

        let confirmed = ConfirmedDayState(
            contentDigest: try summary.contentDigest(),
            revision: 5
        )
        XCTAssertNil(try SyncPlanner.nextPending(summary: summary, confirmed: confirmed))
    }

    func testContentDigestUsesOnlyServerVisibleAggregateSleep() throws {
        let singleInterval = DaySummary(
            localDate: "2026-08-02",
            steps: 5000,
            stepsCoverage: .complete,
            sleepIntervals: [
                SleepIntervalPayload(
                    start: "2026-08-01T21:00:00Z",
                    end: "2026-08-01T23:00:00Z",
                    category: .core
                )
            ],
            sleepCoverage: .complete,
            sources: []
        )
        let splitIntervals = DaySummary(
            localDate: "2026-08-02",
            steps: 5000,
            stepsCoverage: .complete,
            sleepIntervals: [
                SleepIntervalPayload(
                    start: "2026-08-01T21:00:00Z",
                    end: "2026-08-01T22:00:00Z",
                    category: .core
                ),
                SleepIntervalPayload(
                    start: "2026-08-01T22:00:00Z",
                    end: "2026-08-01T23:00:00Z",
                    category: .deep
                )
            ],
            sleepCoverage: .complete,
            sources: []
        )
        let shorterSleep = DaySummary(
            localDate: "2026-08-02",
            steps: 5000,
            stepsCoverage: .complete,
            sleepIntervals: [
                SleepIntervalPayload(
                    start: "2026-08-01T21:00:00Z",
                    end: "2026-08-01T22:00:00Z",
                    category: .core
                )
            ],
            sleepCoverage: .complete,
            sources: []
        )

        XCTAssertEqual(singleInterval.asleepMinutes, 120)
        XCTAssertEqual(splitIntervals.asleepMinutes, 120)
        let singleDigest = try singleInterval.contentDigest()
        XCTAssertEqual(singleDigest, try splitIntervals.contentDigest())
        XCTAssertNotEqual(singleDigest, try shorterSleep.contentDigest())
    }

    func testLegacyPendingDayStillDecodesWithLocalSleepIntervals() throws {
        let legacyJSON = Data(
            """
            {
              "summary": {
                "local_date": "2026-08-02",
                "steps": 5000,
                "steps_coverage": "complete",
                "sleep_intervals": [
                  {
                    "start": "2026-08-01T21:00:00Z",
                    "end": "2026-08-01T22:30:00Z",
                    "category": "core"
                  }
                ],
                "sleep_coverage": "complete",
                "sources": []
              },
              "revision": 4
            }
            """.utf8
        )

        let pending = try CanonicalJSON.decoder().decode(PendingDay.self, from: legacyJSON)
        XCTAssertEqual(pending.revision, 4)
        XCTAssertEqual(pending.summary.sleepIntervals.count, 1)
        XCTAssertEqual(pending.summary.asleepMinutes, 90)

        let snapshot = try pending.summary.unsignedSnapshot(
            installationID: "fixture-installation-0001",
            revision: pending.revision,
            generatedAt: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(snapshot.metrics.asleepMinutes, 90)
        XCTAssertTrue(snapshot.sleepIntervals.isEmpty)
    }
}
