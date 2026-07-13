import SwiftUI

struct GoalView: View {
    @EnvironmentObject private var store: AppStore
    @State private var isEditingProfile = false

    var body: some View {
        let projection = store.projection

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    goalSummary(projection)

                    SectionHeader(title: "Body composition")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricCard(title: "Current fat mass", value: String(format: "%.1f kg", projection.currentFatMassKg), caption: "Estimated", systemImage: "scalemass", tint: Theme.orange)
                        MetricCard(title: "Target weight", value: String(format: "%.1f kg", projection.targetWeightKg), caption: "At 12% body fat", systemImage: "flag.checkered", tint: Theme.accent)
                        MetricCard(title: "Fat to lose", value: String(format: "%.1f kg", projection.fatToLoseKg), caption: "Protect lean mass", systemImage: "arrow.down.forward", tint: Theme.coral)
                        MetricCard(title: "Daily target", value: "\(projection.dailyDeficitKcal) kcal", caption: "Estimated deficit", systemImage: "fork.knife", tint: Theme.blue)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "Timeline range")
                        timelineRow("Faster pace", weeks: projection.aggressiveWeeks, icon: "bolt.fill", tint: Theme.orange)
                        timelineRow("Optimum pace", weeks: projection.optimumWeeks, icon: "scope", tint: Theme.accent)
                        timelineRow("Gentler pace", weeks: projection.conservativeWeeks, icon: "leaf.fill", tint: Theme.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Goal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        DataPrivacyView()
                    } label: {
                        Image(systemName: "lock.shield")
                    }
                    .accessibilityLabel("Data and privacy")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isEditingProfile = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Edit profile")
                }
            }
            .sheet(isPresented: $isEditingProfile) {
                NavigationStack {
                    ProfileFormView(
                        initialProfile: store.profile,
                        title: "Edit Profile",
                        actionTitle: "Save Changes"
                    ) { profile in
                        store.saveProfile(profile)
                        isEditingProfile = false
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { isEditingProfile = false }
                        }
                    }
                }
            }
        }
    }

    private func goalSummary(_ projection: GoalProjection) -> some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Theme.accent.opacity(0.16), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: goalRingProgress)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("12%")
                        .font(.title3.bold())
                    Text("TARGET")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 5) {
                Text("Your 12% plan")
                    .font(.title2.bold())
                Text("\(projection.optimumWeeks) weeks at the optimum pace")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text(projection.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        }
    }

    private var goalRingProgress: Double {
        let current = store.today.bodyFatPercentage ?? store.profile.bodyFatPercentage
        guard current > store.profile.targetBodyFatPercentage else { return 1 }
        return min(max(store.profile.targetBodyFatPercentage / current, 0.12), 1)
    }

    private func timelineRow(_ title: String, weeks: Int, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12))
                .clipShape(Circle())
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(weeks) weeks")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
