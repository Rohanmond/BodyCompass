import Foundation
import HealthKit
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

final class HealthKitService {
    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.bodyMass),
            HKQuantityType(.bodyFatPercentage),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.stepCount),
            HKQuantityType(.restingHeartRate),
            HKObjectType.workoutType(),
            HKCategoryType(.sleepAnalysis)
        ]

        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func dailySnapshot(for date: Date = Date()) async -> DailyHealthSnapshot {
        // The first app milestone wires HealthKit permission and keeps manual/mock fallback.
        // Metric queries will be added per type so partial permissions never break the dashboard.
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return DailyHealthSnapshot(date: formatter.string(from: date))
    }
}
