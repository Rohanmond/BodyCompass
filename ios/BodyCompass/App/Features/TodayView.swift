import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingManualEntry = false

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

                    healthSyncBanner

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricCard(title: "Steps", value: "\(store.today.steps)", caption: "Goal: 10,000", systemImage: "figure.walk")
                        MetricCard(title: "Active energy", value: "\(Int(store.today.activeEnergyKcal)) kcal", caption: "From Apple Health", systemImage: "flame")
                        MetricCard(title: "Sleep", value: hoursText(store.today.sleepHours), caption: sourceCaption(for: \.sleepHours, fallback: "Recovery input"), systemImage: "bed.double")
                        MetricCard(title: "Workout", value: "\(store.today.workoutMinutes) min", caption: "Strength protects lean mass", systemImage: "dumbbell")
                        MetricCard(title: "Weight", value: weightText, caption: sourceCaption(for: \.weightKg, fallback: "Latest measurement"), systemImage: "scalemass")
                        MetricCard(title: "Body fat", value: bodyFatText, caption: sourceCaption(for: \.bodyFatPercentage, fallback: "Latest estimate"), systemImage: "percent")
                    }

                    Button {
                        showingManualEntry = true
                    } label: {
                        Label("Enter values manually", systemImage: "square.and.pencil")
                            .font(.subheadline)
                    }

                    adherenceCard

                    HStack {
                        SectionHeader(title: "Schedule")
                        Spacer()
                        NavigationLink {
                            ScheduleEditorView()
                        } label: {
                            Text("Edit")
                                .font(.subheadline)
                        }
                    }

                    VStack(spacing: 10) {
                        ForEach(store.schedule) { item in
                            Button {
                                store.toggleItem(item)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(item.isDone ? Theme.accent : .secondary)
                                    Image(systemName: item.category.systemImage)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Text(item.title)
                                        .strikethrough(item.isDone, color: .secondary)
                                        .foregroundStyle(item.isDone ? .secondary : .primary)
                                    Spacer()
                                    if item.hasReminder {
                                        Image(systemName: "bell.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding()
                                .background(Theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }

                        if store.schedule.isEmpty {
                            Text("No tasks yet. Tap Edit to build your daily plan.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                    }

                    SectionHeader(title: "Next best action")
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.nextBestAction.headline)
                            .font(.headline)
                        Text(store.nextBestAction.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Theme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
            }
            .navigationTitle("BodyCompass")
            .task { await store.refreshToday() }
            .refreshable { await store.refreshToday() }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntrySheet()
            }
        }
    }

    private var adherenceCard: some View {
        let daily = store.dailyAdherence
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's adherence")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(daily.completed)/\(daily.total) · \(daily.percent)%")
                    .font(.title3.bold())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("7-day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(store.weeklyAdherence.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                    .font(.title3.bold())
            }
        }
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var healthSyncBanner: some View {
        switch store.healthSync {
        case .idle, .syncing:
            HStack(spacing: 10) {
                ProgressView()
                Text("Syncing Apple Health…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .unavailable:
            Text("Apple Health isn't available on this device. Enter your numbers manually below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Theme.warning.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        case .needsPermission:
            VStack(alignment: .leading, spacing: 10) {
                Text("Connect Apple Health to fill this dashboard automatically. Anything you don't share can be entered manually.")
                    .font(.subheadline)
                Button {
                    Task { await store.connectHealthKit() }
                } label: {
                    Label("Connect Apple Health", systemImage: "heart.fill")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Theme.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        case .synced(let date):
            Label("Apple Health synced at \(date.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var weightText: String {
        store.today.weightKg.map { String(format: "%.1f kg", $0) } ?? "—"
    }

    private var bodyFatText: String {
        store.today.bodyFatPercentage.map { String(format: "%.1f%%", $0) } ?? "—"
    }

    private func hoursText(_ hours: Double?) -> String {
        hours.map { String(format: "%.1f h", $0) } ?? "—"
    }

    private func sourceCaption(for keyPath: KeyPath<ManualHealthEntry, Double?>, fallback: String) -> String {
        guard let entry = store.manualEntry,
              entry.date == store.today.date,
              entry[keyPath: keyPath] != nil else { return fallback }
        return "Manual entry"
    }
}

private struct ManualEntrySheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var weightText = ""
    @State private var bodyFatText = ""
    @State private var sleepText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Weight (kg)") {
                    TextField("e.g. 79.4", text: $weightText)
                        .keyboardType(.decimalPad)
                }
                Section("Body fat (%)") {
                    TextField("e.g. 21.5", text: $bodyFatText)
                        .keyboardType(.decimalPad)
                }
                Section("Sleep (hours)") {
                    TextField("e.g. 7.5", text: $sleepText)
                        .keyboardType(.decimalPad)
                }
                Section {
                    Text("Manual values override Apple Health for today. Leave a field empty to keep the imported value.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Manual entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.saveManualEntry(
                            weightKg: parsePositive(weightText),
                            bodyFatPercentage: parsePositive(bodyFatText),
                            sleepHours: parsePositive(sleepText)
                        )
                        dismiss()
                    }
                }
            }
            .onAppear(perform: prefill)
        }
    }

    private func prefill() {
        guard let entry = store.manualEntry, entry.date == store.today.date else { return }
        weightText = entry.weightKg.map { String(format: "%.1f", $0) } ?? ""
        bodyFatText = entry.bodyFatPercentage.map { String(format: "%.1f", $0) } ?? ""
        sleepText = entry.sleepHours.map { String(format: "%.1f", $0) } ?? ""
    }

    private func parsePositive(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
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
