import Foundation
import HealthKit
import WorkoutKit
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

struct ImportedAppleWorkout: Identifiable, Equatable {
    let id: UUID
    let durationMinutes: Int
    let activeEnergyKcal: Double?
    let distanceMeters: Double?
    let averageHeartRateBPM: Double?
    let oneMinuteHeartRateRecoveryBPM: Double?
}

enum WorkoutKitSessionState: Equatable {
    case idle
    case authorizing
    case scheduling
    case scheduled
    case failed(String)
}

@MainActor
final class WorkoutKitService: ObservableObject {
    @Published private(set) var states: [UUID: WorkoutKitSessionState] = [:]
    @Published private(set) var completed: [UUID: ImportedAppleWorkout] = [:]

    private let scheduler = WorkoutScheduler.shared
    private let healthStore = HKHealthStore()

    func state(for sessionID: UUID) -> WorkoutKitSessionState {
        states[sessionID] ?? .idle
    }

    func schedule(
        session: TrainingSession,
        on date: Date,
        swimLocation: BodyCompassSwimLocation? = nil
    ) async {
        guard WorkoutScheduler.isSupported else {
            states[session.id] = .failed("Workout scheduling is not supported on this device.")
            return
        }

        states[session.id] = .authorizing
        var authorization = await scheduler.authorizationState
        if authorization == .notDetermined {
            authorization = await scheduler.requestAuthorization()
        }
        guard authorization == .authorized else {
            states[session.id] = .failed("Allow BodyCompass to schedule Apple workouts in Settings.")
            return
        }

        do {
            states[session.id] = .scheduling
            let plan = try WorkoutPlanFactory.makePlan(for: session, swimLocation: swimLocation)
            let components = Calendar.current.dateComponents(
                [.calendar, .timeZone, .year, .month, .day],
                from: date
            )
            await scheduler.schedule(plan, at: components)
            states[session.id] = .scheduled
        } catch {
            states[session.id] = .failed(error.localizedDescription)
        }
    }

    func refreshCompleted(sessions: [TrainingSession], on date: Date) async {
        let workouts = await workouts(on: date)
        for workout in workouts {
            guard let plan = try? await workout.workoutPlan,
                  sessions.contains(where: { $0.id == plan.id }) else { continue }
            let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?
                .doubleValue(for: .kilocalorie())
            let distance = workout.statistics(for: HKQuantityType(.distanceSwimming))?
                .sumQuantity()?
                .doubleValue(for: .meter())
            let averageHeartRate = workout.statistics(for: HKQuantityType(.heartRate))?
                .averageQuantity()?
                .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            let heartRateRecovery = await oneMinuteHeartRateRecovery(for: workout)
            completed[plan.id] = ImportedAppleWorkout(
                id: workout.uuid,
                durationMinutes: max(1, Int(workout.duration / 60)),
                activeEnergyKcal: energy,
                distanceMeters: distance,
                averageHeartRateBPM: averageHeartRate,
                oneMinuteHeartRateRecoveryBPM: heartRateRecovery
            )
        }
    }

    private func workouts(on date: Date) async -> [HKWorkout] {
        let start = Calendar.current.startOfDay(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let newestFirst = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [newestFirst]
            ) { _, samples, _ in
                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }
            healthStore.execute(query)
        }
    }

    /// Apple Workout may save recovery samples shortly after the workout ends.
    /// Use the nearest samples around workout end and one minute later. Missing
    /// or non-decreasing values remain nil and never block the review.
    private func oneMinuteHeartRateRecovery(for workout: HKWorkout) async -> Double? {
        let heartRateType = HKQuantityType(.heartRate)
        guard let windowEnd = Calendar.current.date(byAdding: .second, value: 90, to: workout.endDate),
              let windowStart = Calendar.current.date(byAdding: .second, value: -15, to: workout.endDate) else {
            return nil
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: windowStart,
            end: windowEnd,
            options: .strictStartDate
        )
        let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            healthStore.execute(query)
        }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let endSample = samples
            .filter { $0.startDate <= workout.endDate.addingTimeInterval(10) }
            .min { abs($0.startDate.timeIntervalSince(workout.endDate)) < abs($1.startDate.timeIntervalSince(workout.endDate)) }
        let minuteMark = workout.endDate.addingTimeInterval(60)
        let minuteSample = samples
            .filter { $0.startDate >= workout.endDate.addingTimeInterval(40) }
            .min { abs($0.startDate.timeIntervalSince(minuteMark)) < abs($1.startDate.timeIntervalSince(minuteMark)) }
        guard let endBPM = endSample?.quantity.doubleValue(for: unit),
              let minuteBPM = minuteSample?.quantity.doubleValue(for: unit),
              endBPM > minuteBPM else { return nil }
        return endBPM - minuteBPM
    }
}
