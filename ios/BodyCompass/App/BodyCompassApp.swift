import SwiftUI

@main
struct BodyCompassApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var training = TrainingStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(training)
                .keyboardDismissible()
        }
    }
}
