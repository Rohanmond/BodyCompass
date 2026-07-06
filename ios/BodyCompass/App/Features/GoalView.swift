import SwiftUI

struct GoalView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        let projection = store.projection

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("12% Body Fat")
                        .font(.largeTitle.bold())
                    Text(projection.explanation)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricCard(title: "Current fat mass", value: String(format: "%.1f kg", projection.currentFatMassKg), caption: "Estimated", systemImage: "scalemass")
                        MetricCard(title: "Target weight", value: String(format: "%.1f kg", projection.targetWeightKg), caption: "At 12%", systemImage: "flag.checkered")
                        MetricCard(title: "Fat to lose", value: String(format: "%.1f kg", projection.fatToLoseKg), caption: "Protect lean mass", systemImage: "arrow.down.forward")
                        MetricCard(title: "Optimum time", value: "\(projection.optimumWeeks) wk", caption: "\(projection.dailyDeficitKcal) kcal/day deficit", systemImage: "clock")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Timeline range").font(.headline)
                        Text("Aggressive: \(projection.aggressiveWeeks) weeks")
                        Text("Optimum: \(projection.optimumWeeks) weeks")
                        Text("Conservative: \(projection.conservativeWeeks) weeks")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
            }
            .navigationTitle("Goal")
        }
    }
}
