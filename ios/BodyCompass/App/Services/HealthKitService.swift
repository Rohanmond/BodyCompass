import Foundation
import HealthKit
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

final class HealthKitService: @unchecked Sendable {
    private let store = HKHealthStore()

    private static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.bodyMass),
        HKQuantityType(.bodyFatPercentage),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.stepCount),
        HKQuantityType(.restingHeartRate),
        HKObjectType.workoutType(),
        HKCategoryType(.sleepAnalysis)
    ]

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // iOS never reveals whether a read permission was denied, only whether the
    // request sheet still needs to be shown. Denied types simply return no data.
    func shouldRequestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let status = try? await store.statusForAuthorizationRequest(toShare: [], read: Self.readTypes)
        return status == .shouldRequest
    }

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    static func dayKey(for date: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    func dailySnapshot(for date: Date = Date()) async -> DailyHealthSnapshot {
        var snapshot = DailyHealthSnapshot(date: Self.dayKey(for: date))
        guard isAvailable else { return snapshot }

        // Each metric is queried independently so a denied permission or an
        // empty data type never blocks the other metrics.
        async let steps = sumQuantity(.stepCount, unit: .count(), on: date)
        async let activeEnergy = sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), on: date)
        async let weight = latestQuantity(.bodyMass, unit: .gramUnit(with: .kilo), lookBackDays: 14, endingOn: date)
        async let bodyFat = latestQuantity(.bodyFatPercentage, unit: .percent(), lookBackDays: 30, endingOn: date)
        async let restingHeartRate = latestQuantity(
            .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            lookBackDays: 7,
            endingOn: date
        )
        async let sleepHours = sleepHours(endingOn: date)
        async let workoutMinutes = workoutMinutes(on: date)

        snapshot.steps = Int(await steps ?? 0)
        snapshot.activeEnergyKcal = await activeEnergy ?? 0
        snapshot.weightKg = await weight
        snapshot.bodyFatPercentage = (await bodyFat).map { $0 * 100 }
        snapshot.restingHeartRate = await restingHeartRate
        snapshot.sleepHours = await sleepHours
        snapshot.workoutMinutes = await workoutMinutes
        return snapshot
    }

    // MARK: - Queries

    private func dayRange(for date: Date) -> (start: Date, end: Date)? {
        let start = Calendar.current.startOfDay(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return nil }
        return (start, end)
    }

    private func sumQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, on date: Date) async -> Double? {
        guard let range = dayRange(for: date) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: range.start, end: range.end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(identifier),
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    // Weight, body fat, and resting heart rate are not logged every day, so the
    // most recent sample within a short look-back window stands in for today.
    private func latestQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        lookBackDays: Int,
        endingOn date: Date
    ) async -> Double? {
        guard let range = dayRange(for: date),
              let start = Calendar.current.date(byAdding: .day, value: -lookBackDays, to: range.start) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: range.end, options: [])
        let newestFirst = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKQuantityType(identifier),
                predicate: predicate,
                limit: 1,
                sortDescriptors: [newestFirst]
            ) { _, samples, _ in
                let sample = samples?.first as? HKQuantitySample
                continuation.resume(returning: sample?.quantity.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    // Last night's sleep belongs to today, so the window runs from 6 PM the
    // previous evening through the end of the given day.
    private func sleepHours(endingOn date: Date) async -> Double? {
        guard let range = dayRange(for: date),
              let windowStart = Calendar.current.date(byAdding: .hour, value: -6, to: range.start) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: range.end, options: [])
        let asleepValues = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let seconds = (samples as? [HKCategorySample])?
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { total, sample in
                        let start = max(sample.startDate, windowStart)
                        let end = min(sample.endDate, range.end)
                        return total + max(0, end.timeIntervalSince(start))
                    } ?? 0
                continuation.resume(returning: seconds > 0 ? seconds / 3600 : nil)
            }
            store.execute(query)
        }
    }

    private func workoutMinutes(on date: Date) async -> Int {
        guard let range = dayRange(for: date) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: range.start, end: range.end, options: [])

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let seconds = (samples as? [HKWorkout])?.reduce(0.0) { $0 + $1.duration } ?? 0
                continuation.resume(returning: Int(seconds / 60))
            }
            store.execute(query)
        }
    }
}
