import Foundation
import WorkoutKit

enum WatchWorkoutLaunchState: Equatable {
    case idle
    case opening
    case opened
    case failed(String)
}

@MainActor
final class WatchWorkoutLauncher: ObservableObject {
    @Published private(set) var states: [UUID: WatchWorkoutLaunchState] = [:]

    func state(for sessionID: UUID) -> WatchWorkoutLaunchState {
        states[sessionID] ?? .idle
    }

    func open(
        session: TrainingSession,
        swimLocation: BodyCompassSwimLocation? = nil
    ) async {
        states[session.id] = .opening
        do {
            let plan = try WorkoutPlanFactory.makePlan(for: session, swimLocation: swimLocation)
            try await plan.openInWorkoutApp()
            states[session.id] = .opened
        } catch {
            states[session.id] = .failed(error.localizedDescription)
        }
    }
}
