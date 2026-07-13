import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        if store.hasCompletedOnboarding {
            mainTabs
        } else {
            OnboardingView()
        }
    }

    private var mainTabs: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "target") }

            MealLogView()
                .tabItem { Label("Meals", systemImage: "camera.viewfinder") }

            GoalView()
                .tabItem { Label("Goal", systemImage: "chart.line.uptrend.xyaxis") }

            HistoryView()
                .tabItem { Label("History", systemImage: "calendar") }

            CoachChatView()
                .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right") }
        }
        .tint(Theme.accent)
    }
}
