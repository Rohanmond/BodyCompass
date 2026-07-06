import SwiftUI

struct RootView: View {
    var body: some View {
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
