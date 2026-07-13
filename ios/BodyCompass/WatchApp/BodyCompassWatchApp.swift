import SwiftUI

@main
struct BodyCompassWatchApp: App {
    @StateObject private var routineStore = WatchRoutineStore()
    @StateObject private var workoutLauncher = WatchWorkoutLauncher()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(routineStore)
                .environmentObject(workoutLauncher)
        }
    }
}
