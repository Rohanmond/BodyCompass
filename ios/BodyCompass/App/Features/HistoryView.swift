import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Weekly Review")
                        .font(.largeTitle.bold())
                    Text("This screen will compare weight trend, body-fat estimate, calories, protein, workouts, sleep, and schedule completion.")
                        .foregroundStyle(.secondary)

                    ForEach(["Weight trend", "Body-fat trend", "Meal adherence", "Workout consistency", "Sleep quality"], id: \.self) { title in
                        HStack {
                            Text(title)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
            }
            .navigationTitle("History")
        }
    }
}
