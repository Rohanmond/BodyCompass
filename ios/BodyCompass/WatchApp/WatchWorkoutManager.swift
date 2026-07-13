import Foundation
import HealthKit

struct WatchWorkoutSummary: Equatable {
    let duration: TimeInterval
    let activeEnergy: Double
    let finalHeartRate: Double
}

enum WatchWorkoutState: Equatable {
    case idle
    case authorizing
    case running
    case paused
    case ending
    case completed(WatchWorkoutSummary)
    case failed(String)
}

final class WatchWorkoutManager: NSObject, ObservableObject {
    @Published private(set) var state: WatchWorkoutState = .idle
    @Published private(set) var heartRate = 0.0
    @Published private(set) var activeEnergy = 0.0
    @Published private(set) var startedAt: Date?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var pausedAt: Date?
    private var accumulatedPausedTime: TimeInterval = 0

    func startStrength() {
        guard state == .idle else { return }
        state = .authorizing

        Task {
            do {
                try await requestAuthorization()
                await MainActor.run { self.beginStrengthSession() }
            } catch {
                await MainActor.run { self.state = .failed(error.localizedDescription) }
            }
        }
    }

    func togglePause() {
        switch state {
        case .running:
            session?.pause()
        case .paused:
            session?.resume()
        default:
            break
        }
    }

    func end() {
        guard state == .running || state == .paused else { return }
        state = .ending
        session?.end()
    }

    func reset() {
        session = nil
        builder = nil
        startedAt = nil
        pausedAt = nil
        accumulatedPausedTime = 0
        heartRate = 0
        activeEnergy = 0
        state = .idle
    }

    func elapsedTime(at date: Date = Date()) -> TimeInterval {
        guard let startedAt else { return 0 }
        let currentPause = pausedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0
        return max(0, date.timeIntervalSince(startedAt) - accumulatedPausedTime - currentPause)
    }

    private func requestAuthorization() async throws {
        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        let read: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]
        try await healthStore.requestAuthorization(toShare: share, read: read)
    }

    private func beginStrengthSession() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            let workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let workoutBuilder = workoutSession.associatedWorkoutBuilder()
            workoutBuilder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            workoutSession.delegate = self
            workoutBuilder.delegate = self
            session = workoutSession
            builder = workoutBuilder

            let start = Date()
            startedAt = start
            workoutSession.startActivity(with: start)
            workoutBuilder.beginCollection(withStart: start) { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        self?.state = .running
                    } else {
                        self?.state = .failed(error?.localizedDescription ?? "Workout could not start.")
                    }
                }
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func updateMetrics(for types: Set<HKSampleType>) {
        for type in types {
            guard let quantityType = type as? HKQuantityType,
                  let statistics = builder?.statistics(for: quantityType) else { continue }

            if quantityType == HKQuantityType(.heartRate) {
                let unit = HKUnit.count().unitDivided(by: .minute())
                let value = statistics.mostRecentQuantity()?.doubleValue(for: unit) ?? 0
                DispatchQueue.main.async { self.heartRate = value }
            } else if quantityType == HKQuantityType(.activeEnergyBurned) {
                let value = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                DispatchQueue.main.async { self.activeEnergy = value }
            }
        }
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                if let pausedAt = self.pausedAt {
                    self.accumulatedPausedTime += max(0, date.timeIntervalSince(pausedAt))
                    self.pausedAt = nil
                }
                self.state = .running
            case .paused:
                self.pausedAt = date
                self.state = .paused
            case .ended: self.finishWorkout(at: date)
            default: break
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async { self.state = .failed(error.localizedDescription) }
    }

    private func finishWorkout(at date: Date) {
        builder?.endCollection(withEnd: date) { [weak self] _, error in
            guard error == nil else {
                DispatchQueue.main.async { self?.state = .failed(error?.localizedDescription ?? "Workout could not end.") }
                return
            }
            self?.builder?.finishWorkout { _, finishError in
                DispatchQueue.main.async {
                    if let finishError {
                        self?.state = .failed(finishError.localizedDescription)
                    } else {
                        self?.completeWorkout(at: date)
                    }
                }
            }
        }
    }

    private func completeWorkout(at date: Date) {
        let summary = WatchWorkoutSummary(
            duration: elapsedTime(at: date),
            activeEnergy: activeEnergy,
            finalHeartRate: heartRate
        )
        session = nil
        builder = nil
        startedAt = nil
        pausedAt = nil
        accumulatedPausedTime = 0
        state = .completed(summary)
    }
}

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        updateMetrics(for: collectedTypes)
    }
}
