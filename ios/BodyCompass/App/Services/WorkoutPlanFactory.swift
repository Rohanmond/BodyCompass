import Foundation
import HealthKit
import WorkoutKit
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

enum BodyCompassSwimLocation: String, CaseIterable, Identifiable {
    case pool
    case openWater

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pool: return "Pool"
        case .openWater: return "Open Water"
        }
    }
}

enum WorkoutPlanFactoryError: LocalizedError {
    case unsupportedSession
    case missingSwimLocation

    var errorDescription: String? {
        switch self {
        case .unsupportedSession:
            return "Apple Workout does not support this session type."
        case .missingSwimLocation:
            return "Choose Pool or Open Water before sending this swim."
        }
    }
}

enum WorkoutPlanFactory {
    static func makePlan(
        for session: TrainingSession,
        swimLocation: BodyCompassSwimLocation? = nil
    ) throws -> WorkoutPlan {
        switch session.kind {
        case .strength:
            return try strengthPlan(for: session)
        case .swimming:
            guard let swimLocation else { throw WorkoutPlanFactoryError.missingSwimLocation }
            return try swimPlan(for: session, location: swimLocation)
        case .recovery:
            throw WorkoutPlanFactoryError.unsupportedSession
        }
    }

    private static func strengthPlan(for session: TrainingSession) throws -> WorkoutPlan {
        let activity = HKWorkoutActivityType.traditionalStrengthTraining
        if CustomWorkout.supportsActivity(activity), !session.exercises.isEmpty {
            let blocks = session.exercises.map { exercise in
                let work = IntervalStep(
                    .work,
                    step: namedStep(
                        goal: .open,
                        name: "\(exercise.name): \(exercise.repRangeLower)-\(exercise.repRangeUpper) reps"
                    )
                )
                let recovery = IntervalStep(
                    .recovery,
                    step: namedStep(
                        goal: .time(Double(exercise.restSeconds), .seconds),
                        name: "Rest"
                    )
                )
                return IntervalBlock(
                    steps: [work, recovery],
                    iterations: max(1, exercise.workingSets)
                )
            }
            let workout = CustomWorkout(
                activity: activity,
                location: .indoor,
                displayName: "BodyCompass: \(session.title)",
                blocks: blocks
            )
            return WorkoutPlan(.custom(workout), id: session.id)
        }

        guard SingleGoalWorkout.supportsActivity(activity) else {
            throw WorkoutPlanFactoryError.unsupportedSession
        }
        let workout = SingleGoalWorkout(activity: activity, location: .indoor, goal: .open)
        return WorkoutPlan(.goal(workout), id: session.id)
    }

    private static func swimPlan(
        for session: TrainingSession,
        location: BodyCompassSwimLocation
    ) throws -> WorkoutPlan {
        let activity = HKWorkoutActivityType.swimming
        guard SingleGoalWorkout.supportsActivity(activity) else {
            throw WorkoutPlanFactoryError.unsupportedSession
        }
        let swimmingLocation: HKWorkoutSwimmingLocationType = location == .pool ? .pool : .openWater
        let workoutLocation: HKWorkoutSessionLocationType = location == .pool ? .indoor : .outdoor
        let minutes = max(1, session.swimPlan?.targetMinutes ?? 30)
        let workout = SingleGoalWorkout(
            activity: activity,
            location: workoutLocation,
            swimmingLocation: swimmingLocation,
            goal: .time(Double(minutes), .minutes)
        )
        return WorkoutPlan(.goal(workout), id: session.id)
    }

    private static func namedStep(goal: WorkoutGoal, name: String) -> WorkoutStep {
        if #available(iOS 18.0, watchOS 11.0, *) {
            return WorkoutStep(goal: goal, displayName: name)
        }
        return WorkoutStep(goal: goal)
    }
}
