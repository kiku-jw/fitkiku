import Foundation
import HealthKit

enum HealthKitClientError: LocalizedError {
    case unavailable
    case authorizationFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Apple Health is not available on this device."
        case .authorizationFailed:
            "Apple Health access could not be requested."
        }
    }
}

protocol HealthDataReading: Sendable {
    func requestAuthorization() async throws
    func readDay(_ dayStart: Date) async -> DaySummary
    func installObservers(onChange: @escaping @Sendable () async -> Void)
    func enableBackgroundDelivery() async throws
    func stopObservers() async
}

final class HealthKitClient: HealthDataReading, @unchecked Sendable {
    private struct StepsRead: Sendable {
        let value: Int?
        let coverage: CoverageState
        let sources: [HealthSourcePayload]
    }

    private struct SleepRead: Sendable {
        let intervals: [SleepIntervalPayload]
        let coverage: CoverageState
        let sources: [HealthSourcePayload]
    }

    private let store: HKHealthStore
    private let stepType: HKQuantityType
    private let sleepType: HKCategoryType
    private let observerLock = NSLock()
    private var observerQueries: [HKObserverQuery] = []

    init(store: HKHealthStore = HKHealthStore()) throws {
        guard HKHealthStore.isHealthDataAvailable(),
              let stepType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        else {
            throw HealthKitClientError.unavailable
        }
        self.store = store
        self.stepType = stepType
        self.sleepType = sleepType
    }

    func requestAuthorization() async throws {
        do {
            try await store.requestAuthorization(
                toShare: Set<HKSampleType>(),
                read: Set<HKObjectType>([stepType, sleepType])
            )
        } catch {
            throw HealthKitClientError.authorizationFailed
        }
    }

    func readDay(_ dayStart: Date) async -> DaySummary {
        let normalizedStart = AppDate.dayStart(dayStart)
        async let stepsRead = readSteps(dayStart: normalizedStart)
        async let sleepRead = readSleep(dayStart: normalizedStart)
        let (steps, sleep) = await (stepsRead, sleepRead)
        return DaySummary(
            localDate: AppDate.localDate(normalizedStart),
            steps: steps.value,
            stepsCoverage: steps.coverage,
            sleepIntervals: sleep.intervals,
            sleepCoverage: sleep.coverage,
            sources: (steps.sources + sleep.sources).uniquedAndSorted()
        ).normalized
    }

    func installObservers(onChange: @escaping @Sendable () async -> Void) {
        let types: [HKSampleType] = [stepType, sleepType]
        let queries = types.map { type in
            HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
                HealthObserverUpdateHandler.handle(
                    error: error,
                    onChange: onChange,
                    completion: completion
                )
            }
        }
        guard storeObserversIfNeeded(queries) else { return }
        for query in queries {
            store.execute(query)
        }
    }

    func enableBackgroundDelivery() async throws {
        let types: [HKSampleType] = [stepType, sleepType]
        do {
            for type in types {
                try await store.enableBackgroundDelivery(for: type, frequency: .hourly)
            }
        } catch {
            await stopObservers()
            throw error
        }
    }

    func stopObservers() async {
        let queries = takeObservers()
        for query in queries {
            store.stop(query)
        }
        for type in [stepType, sleepType] as [HKObjectType] {
            try? await store.disableBackgroundDelivery(for: type)
        }
    }

    private func readSteps(dayStart: Date) async -> StepsRead {
        let end = AppDate.addingDays(1, to: dayStart)
        async let total = readStepTotal(dayStart: dayStart, end: end)
        async let sources = readStepSources(dayStart: dayStart, end: end)
        let (value, stepSources) = await (total, sources)
        return StepsRead(
            value: value,
            coverage: value == nil ? .unknown : .complete,
            sources: stepSources
        )
    }

    private func readStepTotal(dayStart: Date, end: Date) async -> Int? {
        let predicate = HKQuery.predicateForSamples(
            withStart: dayStart,
            end: end,
            options: [.strictStartDate]
        )
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum]
            ) { _, statistics, error in
                guard error == nil,
                      let quantity = statistics?.sumQuantity()
                else {
                    continuation.resume(returning: nil)
                    return
                }
                let rawValue = quantity.doubleValue(for: .count())
                guard rawValue.isFinite, rawValue >= 0, rawValue <= Double(Int.max) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: Int(rawValue.rounded()))
            }
            store.execute(query)
        }
    }

    private func readStepSources(dayStart: Date, end: Date) async -> [HealthSourcePayload] {
        let predicate = HKQuery.predicateForSamples(
            withStart: dayStart,
            end: end,
            options: [.strictStartDate]
        )
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: stepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard error == nil, let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(
                    returning: samples.map(Self.sourcePayload).uniquedAndSorted()
                )
            }
            store.execute(query)
        }
    }

    private func readSleep(dayStart: Date) async -> SleepRead {
        let windowStart = AppDate.calendar.date(
            bySettingHour: 12,
            minute: 0,
            second: 0,
            of: AppDate.addingDays(-1, to: dayStart)
        )!
        let windowEnd = AppDate.addingDays(1, to: dayStart)
        let predicate = HKQuery.predicateForSamples(
            withStart: windowStart,
            end: windowEnd,
            options: []
        )
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard error == nil, let samples = samples as? [HKCategorySample] else {
                    continuation.resume(
                        returning: SleepRead(intervals: [], coverage: .unknown, sources: [])
                    )
                    return
                }
                let validSamples = samples.filter { sample in
                    sample.endDate > sample.startDate
                        && sample.startDate < windowEnd
                        && sample.endDate > windowStart
                }
                guard let latestEnd = validSamples.map(\.endDate).max(),
                      AppDate.localDate(latestEnd) == AppDate.localDate(dayStart)
                else {
                    continuation.resume(
                        returning: SleepRead(intervals: [], coverage: .unknown, sources: [])
                    )
                    return
                }
                let intervals = validSamples.map { sample in
                    SleepIntervalPayload(
                        start: AppDate.timestamp(sample.startDate),
                        end: AppDate.timestamp(sample.endDate),
                        category: Self.sleepCategory(sample.value)
                    )
                }
                let sources = validSamples.map(Self.sourcePayload).uniquedAndSorted()
                let containsSleep = intervals.contains { $0.category.countsAsSleep }
                continuation.resume(
                    returning: SleepRead(
                        intervals: intervals,
                        coverage: containsSleep ? .complete : .partial,
                        sources: sources
                    )
                )
            }
            store.execute(query)
        }
    }

    private static func sleepCategory(_ rawValue: Int) -> SleepCategory {
        switch rawValue {
        case HKCategoryValueSleepAnalysis.inBed.rawValue:
            .inBed
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
            .asleepUnspecified
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            .awake
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
            .core
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
            .deep
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            .rem
        default:
            .unknown
        }
    }

    private static func sourcePayload(_ sample: HKSample) -> HealthSourcePayload {
        HealthSourcePayload(
            name: sample.sourceRevision.source.name,
            bundleIdentifier: sample.sourceRevision.source.bundleIdentifier,
            productType: sample.sourceRevision.productType
        )
    }

    private func storeObserversIfNeeded(_ queries: [HKObserverQuery]) -> Bool {
        observerLock.lock()
        defer { observerLock.unlock() }
        guard observerQueries.isEmpty else { return false }
        observerQueries = queries
        return true
    }

    private func takeObservers() -> [HKObserverQuery] {
        observerLock.lock()
        defer { observerLock.unlock() }
        let queries = observerQueries
        observerQueries = []
        return queries
    }
}

enum HealthObserverUpdateHandler {
    static func handle(
        error: Error?,
        onChange: @escaping @Sendable () async -> Void,
        completion: @escaping () -> Void
    ) {
        guard error == nil else {
            completion()
            return
        }
        let completionBox = ObserverCompletion(completion)
        Task {
            await onChange()
            completionBox.call()
        }
    }
}

private final class ObserverCompletion: @unchecked Sendable {
    private let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }

    func call() {
        action()
    }
}

private extension Array where Element == HealthSourcePayload {
    func uniquedAndSorted() -> [HealthSourcePayload] {
        Dictionary(
            map { source in
                ("\(source.bundleIdentifier)|\(source.name)|\(source.productType ?? "")", source)
            },
            uniquingKeysWith: { first, _ in first }
        ).values.sorted {
            ($0.bundleIdentifier, $0.name, $0.productType ?? "")
                < ($1.bundleIdentifier, $1.name, $1.productType ?? "")
        }
    }
}
