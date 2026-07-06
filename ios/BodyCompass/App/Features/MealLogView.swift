import SwiftUI

struct MealLogView: View {
    @EnvironmentObject private var store: AppStore
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button {
                    } label: {
                        Label("Add meal photo", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    TextField("Portion notes, sauces, oil, restaurant/home", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                        .textFieldStyle(.roundedBorder)

                    SectionHeader(title: "Latest AI estimate")
                    ForEach(store.meals) { meal in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(meal.title).font(.headline)
                            Text("\(meal.caloriesRange.lowerBound)-\(meal.caloriesRange.upperBound) kcal")
                                .font(.title2.bold())
                            Text("Protein \(meal.proteinGrams)g | Carbs \(meal.carbsGrams)g | Fat \(meal.fatGrams)g")
                                .foregroundStyle(.secondary)
                            Text(meal.recommendation)
                            ForEach(meal.likelyMistakes, id: \.self) { mistake in
                                Label(mistake, systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(Theme.warning)
                            }
                        }
                        .padding()
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
            }
            .navigationTitle("Meals")
        }
    }
}
