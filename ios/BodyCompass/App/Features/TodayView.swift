import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var training: TrainingStore
    @State private var showingManualEntry = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    dayHeader

                    healthSyncBanner
                    serverSyncBanner

                    priorityCard

                    SectionHeader(title: "Health today")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricCard(title: "Steps", value: "\(store.today.steps)", caption: "Since midnight · 10,000 goal", systemImage: "figure.walk", tint: Theme.blue)
                        MetricCard(title: "Active energy", value: "\(Int(store.today.activeEnergyKcal)) kcal", caption: "Since midnight · Apple Health", systemImage: "flame.fill", tint: Theme.orange)
                        MetricCard(title: "Sleep", value: hoursText(store.today.sleepHours), caption: sourceCaption(for: \.sleepHours, fallback: "Current night · recovery"), systemImage: "bed.double.fill", tint: Theme.indigo)
                        MetricCard(title: "Workout", value: "\(store.today.workoutMinutes) min", caption: "Since midnight · Apple Health", systemImage: "dumbbell.fill", tint: Theme.coral)
                        MetricCard(title: "Weight", value: weightText, caption: sourceCaption(for: \.weightKg, fallback: "Latest within 14 days"), systemImage: "scalemass.fill", tint: Theme.cyan)
                        MetricCard(title: "Body fat", value: bodyFatText, caption: sourceCaption(for: \.bodyFatPercentage, fallback: "Latest within 30 days"), systemImage: "percent", tint: Theme.violet)
                    }

                    Button {
                        showingManualEntry = true
                    } label: {
                        Label("Enter values manually", systemImage: "square.and.pencil")
                            .font(.subheadline)
                    }

                    adherenceCard

                    trainingCard

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
                            .accessibilityLabel("\(item.title), \(item.isDone ? "completed" : "not completed")")
                            .accessibilityHint("Double tap to mark \(item.isDone ? "not completed" : "completed")")
                        }

                        if store.schedule.isEmpty {
                            Text("No tasks yet. Tap Edit to build your daily plan.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                    }

                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .task { await store.refreshToday() }
            .refreshable { await store.refreshToday() }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntrySheet()
            }
        }
    }

    private var dayHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Text("\(greeting), \(firstName)")
                .font(.title2.bold())
            Text("Keep the next decision simple and useful.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var priorityCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "scope")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Theme.accent)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("PRIORITY NOW")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.accent)
                Text(store.nextBestAction.headline)
                    .font(.headline)
                Text(store.nextBestAction.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.accent.opacity(0.22), lineWidth: 1)
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Good night"
        }
    }

    private var firstName: String {
        store.profile.name.split(separator: " ").first.map(String.init) ?? "there"
    }

    // Today's structured session from the weekly program — separate from the
    // generic habit schedule below, which tracks daily accountability.
    private var trainingCard: some View {
        let day = training.effectiveDay()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Today's training")
                Spacer()
                NavigationLink {
                    TrainingWeekView()
                } label: {
                    Text("Week")
                        .font(.subheadline)
                }
            }

            NavigationLink {
                TrainingSessionView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: day.sessions.first?.kind.systemImage ?? "leaf")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.sessions.isEmpty ? "Rest day" : day.sessions.map(\.title).joined(separator: " + "))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(trainingCaption(for: day))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            if training.needsSetup {
                Text("Set up your program on the Week screen to get exact sets, reps, and effort targets.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func trainingCaption(for day: EffectiveTrainingDay) -> String {
        if day.isException { return "Changed just for today" }
        if day.sessions.isEmpty { return "Recovery is part of the plan" }
        let strength = day.sessions.filter { $0.kind == .strength }.flatMap(\.exercises).count
        let swims = day.sessions.filter { $0.kind == .swimming }
        var parts: [String] = []
        if strength > 0 { parts.append("\(strength) exercises") }
        if let plan = swims.first?.swimPlan { parts.append("\(plan.targetMinutes) min swim") }
        else if !swims.isEmpty { parts.append("swim") }
        return parts.isEmpty ? "Tap for details" : parts.joined(separator: " · ")
    }

    private var adherenceCard: some View {
        let daily = store.dailyAdherence
        return VStack(spacing: 12) {
            HStack(spacing: 16) {
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
            ProgressView(value: Double(daily.percent), total: 100)
                .tint(Theme.accent)
        }
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Adherence")
        .accessibilityValue("Today \(daily.completed) of \(daily.total), \(daily.percent) percent. Seven day average \(store.weeklyAdherence.map { "\(Int(($0 * 100).rounded())) percent" } ?? "unavailable")")
    }

    @ViewBuilder
    private var serverSyncBanner: some View {
        switch store.serverSync {
        case .idle, .synced:
            EmptyView()
        case .syncing:
            Label("Backing up changes privately…", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Private backup in progress")
        case .failed:
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Private backup is offline", systemImage: "icloud.slash")
                        .font(.subheadline.bold())
                    Text("Your data is still saved on this iPhone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Retry") {
                    Task { await store.syncNow() }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Theme.warning.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .contain)
        }
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
