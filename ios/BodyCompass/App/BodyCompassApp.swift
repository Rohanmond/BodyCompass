import SwiftUI

@main
struct BodyCompassApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var training = TrainingStore()
    @StateObject private var authentication = AuthenticationStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(training)
                .environmentObject(authentication)
                .keyboardDismissible()
        }
    }
}
