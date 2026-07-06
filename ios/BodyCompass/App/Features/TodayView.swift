import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore

    var completedCount: Int {
        store.schedule.filter(\.isDone).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Today")
                            .font(.largeTitle.bold())
                        Text("Stay honest, stay consistent, adjust fast.")
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricCard(title: "Steps", value: "\(store.today.steps)", caption: "Goal: 10,000", systemImage: "figure.walk")
                        MetricCard(title: "Active energy", value: "\(Int(store.today.activeEnergyKcal)) kcal", caption: "From HealthKit", systemImage: "flame")
                        MetricCard(title: "Sleep", value: "\(store.today.sleepHours ?? 0, specifier: "%.1f") h", caption: "Recovery input", systemImage: "bed.double")
                        MetricCard(title: "Workout", value: "\(store.today.workoutMinutes) min", caption: "Strength protects lean mass", systemImage: "dumbbell")
                    }

                    SectionHeader(title: "Schedule")
                    VStack(spacing: 10) {
                        ForEach(store.schedule) { item in
                            HStack {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isDone ? Theme.accent : .secondary)
                                Text(item.title)
                                Spacer()
                            }
                            .padding()
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    SectionHeader(title: "Next best action")
                    Text(completedCount >= 4 ? "Great pace. Protect sleep tonight." : "Finish the workout or steps before adding more calorie cuts.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Theme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
            }
            .navigationTitle("BodyCompass")
        }
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
