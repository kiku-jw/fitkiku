import Foundation

enum CoverageState: String, Codable, Hashable, Sendable {
    case complete
    case partial
    case unknown
}

struct HealthCoverage: Codable, Hashable, Sendable {
    let steps: CoverageState
    let sleep: CoverageState
}

struct HealthMetricsPayload: Codable, Hashable, Sendable {
    let steps: Int?
    let asleepMinutes: Int?
}

enum NativeHealthDisclosure {
    static let outbound = "After Apple Health permission and sync, FitKiku sends this server daily Steps, asleep minutes, coverage, and Health source details. Sleep interval times and categories stay on this iPhone."
}

enum SleepCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case inBed = "in_bed"
    case asleepUnspecified = "asleep_unspecified"
    case awake
    case core
    case deep
    case rem
    case unknown

    var countsAsSleep: Bool {
        switch self {
        case .asleepUnspecified, .core, .deep, .rem:
            true
        case .inBed, .awake, .unknown:
            false
        }
    }
}

struct SleepIntervalPayload: Codable, Hashable, Sendable {
    let start: String
    let end: String
    let category: SleepCategory
}

struct HealthSourcePayload: Codable, Hashable, Sendable {
    let name: String
    let bundleIdentifier: String
    let productType: String?
}

struct HealthWorkoutPayload: Codable, Hashable, Sendable {}

struct UnsignedHealthSnapshot: Codable, Hashable, Sendable {
    let schemaVersion: String
    let deviceInstallationID: String
    let localDate: String
    let timezone: String
    let syncRevision: Int
    let generatedAt: String
    let idempotencyKey: String
    let metrics: HealthMetricsPayload
    let coverage: HealthCoverage
    let sleepIntervals: [SleepIntervalPayload]
    let workouts: [HealthWorkoutPayload]
    let sources: [HealthSourcePayload]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case deviceInstallationID = "deviceInstallationId"
        case localDate
        case timezone
        case syncRevision
        case generatedAt
        case idempotencyKey
        case metrics
        case coverage
        case sleepIntervals
        case workouts
        case sources
    }
}

struct HealthSnapshotPayload: Codable, Hashable, Sendable {
    let schemaVersion: String
    let deviceInstallationID: String
    let localDate: String
    let timezone: String
    let syncRevision: Int
    let generatedAt: String
    let idempotencyKey: String
    let metrics: HealthMetricsPayload
    let coverage: HealthCoverage
    let sleepIntervals: [SleepIntervalPayload]
    let workouts: [HealthWorkoutPayload]
    let sources: [HealthSourcePayload]
    let signature: String

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case deviceInstallationID = "deviceInstallationId"
        case localDate
        case timezone
        case syncRevision
        case generatedAt
        case idempotencyKey
        case metrics
        case coverage
        case sleepIntervals
        case workouts
        case sources
        case signature
    }
}

struct DaySummary: Codable, Hashable, Sendable {
    let localDate: String
    let steps: Int?
    let stepsCoverage: CoverageState
    let sleepIntervals: [SleepIntervalPayload]
    let sleepCoverage: CoverageState
    let sources: [HealthSourcePayload]

    var coverage: HealthCoverage {
        HealthCoverage(steps: stepsCoverage, sleep: sleepCoverage)
    }

    var normalized: DaySummary {
        let canonicalIntervals = sleepIntervals.map { interval in
            guard let start = AppDate.parseTimestamp(interval.start),
                  let end = AppDate.parseTimestamp(interval.end)
            else {
                return interval
            }
            return SleepIntervalPayload(
                start: AppDate.timestamp(start),
                end: AppDate.timestamp(end),
                category: interval.category
            )
        }
        let intervals = Array(Set(canonicalIntervals)).sorted {
            ($0.start, $0.end, $0.category.rawValue) < ($1.start, $1.end, $1.category.rawValue)
        }
        let uniqueSources = Dictionary(
            sources.map { source in
                ("\(source.bundleIdentifier)|\(source.name)|\(source.productType ?? "")", source)
            },
            uniquingKeysWith: { first, _ in first }
        ).values.sorted {
            ($0.bundleIdentifier, $0.name, $0.productType ?? "")
                < ($1.bundleIdentifier, $1.name, $1.productType ?? "")
        }
        return DaySummary(
            localDate: localDate,
            steps: steps,
            stepsCoverage: stepsCoverage,
            sleepIntervals: intervals,
            sleepCoverage: sleepCoverage,
            sources: uniqueSources
        )
    }

    var asleepMinutes: Int? {
        guard sleepCoverage != .unknown else { return nil }
        let asleep = normalized.sleepIntervals.compactMap { interval -> (Date, Date)? in
            guard interval.category.countsAsSleep,
                  let start = AppDate.parseTimestamp(interval.start),
                  let end = AppDate.parseTimestamp(interval.end),
                  end > start
            else {
                return nil
            }
            return (start, end)
        }
        guard !asleep.isEmpty else {
            return sleepCoverage == .complete ? 0 : nil
        }

        var merged: [(Date, Date)] = []
        for interval in asleep.sorted(by: { $0.0 < $1.0 }) {
            guard let last = merged.last, interval.0 <= last.1 else {
                merged.append(interval)
                continue
            }
            merged[merged.count - 1] = (last.0, max(last.1, interval.1))
        }
        let seconds = merged.reduce(0.0) { $0 + $1.1.timeIntervalSince($1.0) }
        return Int(seconds / 60)
    }

    func contentDigest() throws -> String {
        let content = DayContentIdentity(
            schemaVersion: "1.1",
            localDate: localDate,
            timezone: AppDate.timezoneIdentifier,
            metrics: HealthMetricsPayload(steps: steps, asleepMinutes: asleepMinutes),
            coverage: coverage,
            sleepIntervals: [],
            sources: normalized.sources
        )
        return CanonicalJSON.sha256Hex(try CanonicalJSON.encode(content))
    }

    func unsignedSnapshot(
        installationID: String,
        revision: Int,
        generatedAt: Date
    ) throws -> UnsignedHealthSnapshot {
        let digest = try contentDigest()
        let installationScope = CanonicalJSON.sha256Hex(Data(installationID.utf8))
        return UnsignedHealthSnapshot(
            schemaVersion: "1.1",
            deviceInstallationID: installationID,
            localDate: localDate,
            timezone: AppDate.timezoneIdentifier,
            syncRevision: revision,
            generatedAt: AppDate.timestamp(generatedAt),
            idempotencyKey: "native:\(installationScope):\(digest):r\(revision)",
            metrics: HealthMetricsPayload(steps: steps, asleepMinutes: asleepMinutes),
            coverage: coverage,
            sleepIntervals: [],
            workouts: [],
            sources: normalized.sources
        )
    }
}

private struct DayContentIdentity: Codable, Hashable, Sendable {
    let schemaVersion: String
    let localDate: String
    let timezone: String
    let metrics: HealthMetricsPayload
    let coverage: HealthCoverage
    let sleepIntervals: [SleepIntervalPayload]
    let sources: [HealthSourcePayload]
}

struct PendingDay: Codable, Hashable, Sendable {
    let summary: DaySummary
    let revision: Int
}

struct ConfirmedDayState: Codable, Hashable, Sendable {
    let contentDigest: String
    let revision: Int
}

struct DaySyncResult: Identifiable, Hashable, Sendable {
    enum Outcome: String, Hashable, Sendable {
        case created
        case replaced
        case duplicate
        case unchanged
        case queued
        case failed
    }

    let localDate: String
    let outcome: Outcome
    let message: String?

    var id: String { localDate }
}

enum AppDate {
    static let timezoneIdentifier = "Europe/Kyiv"

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: timezoneIdentifier)!
        return calendar
    }

    static func dayStart(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func addingDays(_ value: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: value, to: dayStart(date))!
    }

    static func localDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func timestamp(_ date: Date) -> String {
        let rawSeconds = date.timeIntervalSince1970
        var wholeSeconds = floor(rawSeconds)
        var microseconds = Int(((rawSeconds - wholeSeconds) * 1_000_000).rounded())
        if microseconds == 1_000_000 {
            wholeSeconds += 1
            microseconds = 0
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let wholeTimestamp = formatter.string(
            from: Date(timeIntervalSince1970: wholeSeconds)
        )
        guard microseconds != 0 else { return wholeTimestamp }

        let digits = String(microseconds)
        let fraction = String(repeating: "0", count: 6 - digits.count) + digits
        return "\(wholeTimestamp.dropLast()).\(fraction)Z"
    }

    static func parseTimestamp(_ value: String) -> Date? {
        let fractional = Date.ISO8601FormatStyle(
            includingFractionalSeconds: true,
            timeZone: .gmt
        )
        if let date = try? fractional.parse(value) {
            return date
        }
        let wholeSeconds = Date.ISO8601FormatStyle(timeZone: .gmt)
        return try? wholeSeconds.parse(value)
    }
}
