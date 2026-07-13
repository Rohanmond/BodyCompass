import SwiftUI
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

/// What to do today: prescriptions, progression hints, and set-by-set logging.
struct TrainingSessionView: View {
    @EnvironmentObject private var app: AppStore
    @EnvironmentObject private var training: TrainingStore
    @StateObject private var workoutKit = WorkoutKitService()

    let date: Date

    @State private var loggingExercise: LoggingTarget?
    @State private var loggingSwim: TrainingSession?
    @State private var reviewingSession: TrainingSession?

    init(date: Date = Date()) {
        self.date = date
    }

    private struct LoggingTarget: Identifiable {
        let session: TrainingSession
        let prescription: ExercisePrescription
        var id: UUID { prescription.id }
    }

    var body: some View {
        let day = training.effectiveDay(for: date)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(day)

                if day.sessions.isEmpty {
                    restCard(day)
                } else {
                    ForEach(day.sessions) { session in
                        sessionCard(session)
                    }
                }

                justTodayControls(day)
            }
            .padding()
        }
        .navigationTitle(day.weekday.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $loggingExercise) { target in
            StrengthSetLogSheet(date: date, session: target.session, prescription: target.prescription)
        }
        .sheet(item: $loggingSwim) { session in
            SwimLogSheet(date: date, session: session)
        }
        .sheet(item: $reviewingSession) { session in
            PostWorkoutReviewSheet(date: date, session: session)
        }
        .task(id: HealthKitService.dayKey(for: date)) {
            await workoutKit.refreshCompleted(sessions: day.sessions, on: date)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func header(_ day: EffectiveTrainingDay) -> some View {
        if let exception = day.exception {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundStyle(Theme.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Changed just for today")
                        .font(.subheadline.bold())
                    Text(exception.note.isEmpty
                         ? "Your repeating week is unchanged."
                         : "\(exception.note) — your repeating week is unchanged.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Theme.warning.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        if training.needsSetup {
            Text("Finish training setup on the week screen to see exact exercises, sets, and effort targets.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Theme.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func restCard(_ day: EffectiveTrainingDay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Rest day", systemImage: "leaf")
                .font(.headline)
            Text("Recovery is where the adaptation happens. Walk, stretch, sleep well.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func sessionCard(_ session: TrainingSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(session.title, systemImage: session.kind.systemImage)
                    .font(.headline)
                Spacer()
                if !session.muscleGroups.isEmpty {
                    Text(session.muscleGroups.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !session.notes.isEmpty {
                Text(session.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            appleWorkoutControls(session)

            switch session.kind {
            case .strength:
                if session.exercises.isEmpty {
                    Text("No exercises yet — finish setup or edit this day.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(session.exercises) { exercise in
                        exerciseCard(exercise, in: session)
                    }
                }
            case .swimming:
                swimContent(session)
            case .recovery:
                Text("Easy movement only.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            postWorkoutSection(session)
        }
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func appleWorkoutControls(_ session: TrainingSession) -> some View {
        if session.kind == .strength {
            Button {
                Task { await workoutKit.schedule(session: session, on: date) }
            } label: {
                workoutKitLabel(for: session, defaultTitle: "Add to Apple Workout")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isWorkoutKitUnavailable(session.id))
        } else if session.kind == .swimming {
            Menu {
                ForEach(BodyCompassSwimLocation.allCases) { location in
                    Button(location.displayName) {
                        Task {
                            await workoutKit.schedule(
                                session: session,
                                on: date,
                                swimLocation: location
                            )
                        }
                    }
                }
            } label: {
                workoutKitLabel(for: session, defaultTitle: "Add swim to Apple Workout")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isWorkoutKitUnavailable(session.id))
        }

        if case .failed(let message) = workoutKit.state(for: session.id) {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(Theme.warning)
        }

        if let imported = workoutKit.completed[session.id] {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), alignment: .leading)], alignment: .leading, spacing: 6) {
                Label("\(imported.durationMinutes) min", systemImage: "checkmark.circle.fill")
                if let energy = imported.activeEnergyKcal {
                    Label("\(Int(energy)) kcal", systemImage: "flame")
                }
                if let distance = imported.distanceMeters, distance > 0 {
                    Label("\(Int(distance)) m", systemImage: "figure.pool.swim")
                }
                if let heartRate = imported.averageHeartRateBPM {
                    Label("\(Int(heartRate.rounded())) bpm avg", systemImage: "heart.fill")
                }
            }
            .font(.caption.bold())
            .foregroundStyle(Theme.accent)
        }
    }

    @ViewBuilder
    private func postWorkoutSection(_ session: TrainingSession) -> some View {
        if session.kind != .recovery && (
            workoutKit.completed[session.id] != nil ||
            training.hasLoggedActivity(for: session, on: date) ||
            training.recoveryCheckIn(on: date, sessionID: session.id) != nil
        ) {
            Divider()
            if let recommendation = recoveryRecommendation(for: session) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(recommendation.headline, systemImage: recoveryIcon(recommendation.level))
                            .font(.subheadline.bold())
                            .foregroundStyle(recoveryColor(recommendation.level))
                        Spacer()
                        Button("Edit") { reviewingSession = session }
                            .font(.caption)
                    }
                    Text(recommendation.detail)
                        .font(.caption)
                    if let note = training.recoveryCheckIn(on: date, sessionID: session.id)?.note {
                        Label(note, systemImage: "note.text")
                            .font(.caption)
                    }
                    ForEach(Array(recommendation.reasons.prefix(4)), id: \.self) { reason in
                        Label(reason, systemImage: "circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next session")
                            .font(.caption.bold())
                        Text(recommendation.nextSessionAction)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(recoveryColor(recommendation.level).opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityElement(children: .combine)
            } else {
                Button {
                    reviewingSession = session
                } label: {
                    Label("Complete post-workout check-in", systemImage: "waveform.path.ecg")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func recoveryRecommendation(for session: TrainingSession) -> RecoveryRecommendation? {
        let snapshot = healthSnapshot(for: date)
        return training.recoveryRecommendation(
            for: session,
            on: date,
            sleepHours: snapshot?.sleepHours,
            currentRestingHeartRate: snapshot?.restingHeartRate,
            baselineRestingHeartRate: restingHeartRateBaseline(before: date),
            oneMinuteHeartRateRecovery: workoutKit.completed[session.id]?.oneMinuteHeartRateRecoveryBPM
        )
    }

    private func healthSnapshot(for date: Date) -> DailyHealthSnapshot? {
        let dateKey = HealthKitService.dayKey(for: date)
        if app.today.date == dateKey { return app.today }
        return app.healthHistory.first { $0.date == dateKey }
    }

    private func restingHeartRateBaseline(before date: Date) -> Double? {
        let dateKey = HealthKitService.dayKey(for: date)
        let values = app.healthHistory
            .filter { $0.date < dateKey }
            .sorted { $0.date < $1.date }
            .compactMap(\.restingHeartRate)
            .suffix(7)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func recoveryIcon(_ level: RecoveryRecommendationLevel) -> String {
        switch level {
        case .ready: return "checkmark.circle.fill"
        case .maintain: return "equal.circle.fill"
        case .recover: return "bed.double.fill"
        case .caution: return "exclamationmark.triangle.fill"
        }
    }

    private func recoveryColor(_ level: RecoveryRecommendationLevel) -> Color {
        switch level {
        case .ready: return Theme.accent
        case .maintain: return .blue
        case .recover: return Theme.warning
        case .caution: return .red
        }
    }

    private func workoutKitLabel(for session: TrainingSession, defaultTitle: String) -> some View {
        let state = workoutKit.state(for: session.id)
        let title: String
        let icon: String
        switch state {
        case .idle, .failed:
            title = defaultTitle
            icon = "applewatch"
        case .authorizing:
            title = "Requesting access"
            icon = "lock.open"
        case .scheduling:
            title = "Scheduling"
            icon = "arrow.triangle.2.circlepath"
        case .scheduled:
            title = "Added to Apple Workout"
            icon = "checkmark.circle.fill"
        }
        return Label(title, systemImage: icon)
            .font(.caption.bold())
    }

    private func isWorkoutKitUnavailable(_ sessionID: UUID) -> Bool {
        let state = workoutKit.state(for: sessionID)
        return state == .authorizing || state == .scheduling || state == .scheduled
    }

    private func exerciseCard(_ exercise: ExercisePrescription, in session: TrainingSession) -> some View {
        let suggestion = training.suggestion(for: exercise)
        let todaysSets = training.strengthLogs(on: date, exerciseName: exercise.name)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.name)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(exercise.setsText) @ \(exercise.targetRIR) RIR")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.accent)
            }

            Text("Rest \(exercise.restSeconds / 60)m\(exercise.restSeconds % 60 == 0 ? "" : " \(exercise.restSeconds % 60)s") between sets")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !exercise.warmUp.isEmpty {
                Label(exercise.warmUp, systemImage: "flame")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !exercise.techniqueNotes.isEmpty {
                Label(exercise.techniqueNotes, systemImage: "lightbulb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !exercise.substitutions.isEmpty {
                Label("Swap: \(exercise.substitutions.joined(separator: ", "))", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Deterministic progression advice from what was actually logged.
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.headline)
                    .font(.caption.bold())
                Text(suggestion.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            if !todaysSets.isEmpty {
                ForEach(todaysSets) { set in
                    HStack {
                        Text("Set \(set.setNumber)")
                            .font(.caption.bold())
                        Text("\(set.loadKg, specifier: "%.1f") kg × \(set.reps)")
                            .font(.caption)
                        if let rir = set.rir {
                            Text("@ \(rir) RIR")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if set.painNote != nil {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(Theme.warning)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            training.deleteStrengthLog(set)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                        }
                    }
                }
            }

            Button {
                loggingExercise = LoggingTarget(session: session, prescription: exercise)
            } label: {
                Label(todaysSets.isEmpty ? "Log first set" : "Log set \(todaysSets.count + 1)", systemImage: "plus.circle")
                    .font(.caption.bold())
            }
        }
        .padding(10)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func swimContent(_ session: TrainingSession) -> some View {
        if let plan = session.swimPlan {
            Text("Target: \(plan.targetMinutes) minutes, \(plan.intensity.displayName.lowercased()) effort")
                .font(.subheadline)
        } else {
            Text("No duration set — finish setup or edit this day.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        let logs = training.swimLogs(on: date, sessionID: session.id)
        ForEach(logs) { log in
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
                Text("\(log.minutes) min · \(log.intensity.displayName)\(log.distanceMeters.map { " · \($0) m" } ?? "")")
                    .font(.caption)
            }
        }

        Button {
            loggingSwim = session
        } label: {
            Label(logs.isEmpty ? "Log swim" : "Log another swim", systemImage: "plus.circle")
                .font(.caption.bold())
        }
    }

    // MARK: - One-day exceptions

    private func justTodayControls(_ day: EffectiveTrainingDay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Just this day")
            if day.isException {
                Button {
                    training.removeException(dateKey: HealthKitService.dayKey(for: date))
                } label: {
                    Label("Restore the planned session", systemImage: "arrow.uturn.backward")
                }
            } else {
                Button {
                    training.setException(
                        dateKey: HealthKitService.dayKey(for: date),
                        sessions: [],
                        note: "Rest day taken"
                    )
                } label: {
                    Label("Make today a rest day", systemImage: "leaf")
                }
                Text("Only this date changes. Your repeating week stays exactly as planned.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Logging sheets

private struct PostWorkoutReviewSheet: View {
    @EnvironmentObject private var training: TrainingStore
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let session: TrainingSession

    @State private var sessionRPE = 7.0
    @State private var soreness: SorenessLevel = .none
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Session effort")
                            Spacer()
                            Text("\(Int(sessionRPE))/10")
                                .font(.headline)
                                .foregroundStyle(Theme.accent)
                        }
                        Slider(value: $sessionRPE, in: 1...10, step: 1)
                            .tint(Theme.accent)
                            .accessibilityValue("\(Int(sessionRPE)) out of 10")
                    }
                } footer: {
                    Text("Rate the whole session: 1 is very easy and 10 is maximal.")
                }

                Section("Soreness now") {
                    Picker("Soreness", selection: $soreness) {
                        ForEach(SorenessLevel.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                }

                Section("Note (optional)") {
                    TextField("Technique issue, fatigue, or limitation", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Text("BodyCompass combines this check-in with available sleep, recent workload, set effort, pain notes, resting heart rate, and Apple Workout data. It does not diagnose recovery or change your routine automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Post-workout review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        training.saveRecoveryCheckIn(
                            date: date,
                            sessionID: session.id,
                            sessionRPE: Int(sessionRPE),
                            soreness: soreness,
                            note: note
                        )
                        dismiss()
                    }
                }
            }
            .onAppear(perform: prefill)
        }
    }

    private func prefill() {
        guard let checkIn = training.recoveryCheckIn(on: date, sessionID: session.id) else { return }
        sessionRPE = Double(checkIn.sessionRPE)
        soreness = checkIn.soreness
        note = checkIn.note ?? ""
    }
}

private struct StrengthSetLogSheet: View {
    @EnvironmentObject private var training: TrainingStore
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let session: TrainingSession
    let prescription: ExercisePrescription

    @State private var loadText = ""
    @State private var reps: Int = 0
    @State private var rir: Int = 2
    @State private var trackEffort = true
    @State private var painNote = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Load (kg)") {
                    TextField("e.g. 42.5", text: $loadText)
                        .keyboardType(.decimalPad)
                }
                Section("Reps") {
                    Stepper("\(reps) reps", value: $reps, in: 0...50)
                }
                Section {
                    Toggle("Rate effort", isOn: $trackEffort)
                    if trackEffort {
                        Stepper("\(rir) reps in reserve", value: $rir, in: 0...5)
                    }
                } footer: {
                    Text("Target: \(prescription.setsText) with \(prescription.targetRIR) reps in reserve.")
                }
                Section("Pain or limitation (optional)") {
                    TextField("e.g. left shoulder twinge", text: $painNote)
                }
            }
            .navigationTitle(prescription.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save set") {
                        training.logStrengthSet(
                            date: date,
                            sessionID: session.id,
                            exerciseName: prescription.name,
                            loadKg: parsedLoad ?? 0,
                            reps: reps,
                            rir: trackEffort ? rir : nil,
                            painNote: painNote
                        )
                        dismiss()
                    }
                    .disabled(parsedLoad == nil || reps == 0)
                }
            }
            .onAppear(perform: prefill)
        }
    }

    private var parsedLoad: Double? {
        let normalized = loadText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value >= 0 else { return nil }
        return value
    }

    // Start from the previous set today, or the last session's top load.
    private func prefill() {
        rir = prescription.targetRIR
        let today = training.strengthLogs(on: date, exerciseName: prescription.name)
        if let last = today.last {
            loadText = String(format: "%.1f", last.loadKg)
            reps = last.reps
        } else {
            reps = prescription.repRangeLower
        }
    }
}

private struct SwimLogSheet: View {
    @EnvironmentObject private var training: TrainingStore
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let session: TrainingSession

    @State private var minutes: Int = 30
    @State private var distanceText = ""
    @State private var intensity: SwimIntensity = .easy
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Duration") {
                    Stepper("\(minutes) minutes", value: $minutes, in: 5...180, step: 5)
                }
                Section("Distance (m, optional)") {
                    TextField("e.g. 1200", text: $distanceText)
                        .keyboardType(.numberPad)
                }
                Section("Intensity") {
                    Picker("How hard did it feel?", selection: $intensity) {
                        ForEach(SwimIntensity.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Note (optional)") {
                    TextField("e.g. mostly freestyle, some drills", text: $note)
                }
            }
            .navigationTitle("Log swim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        training.logSwim(
                            date: date,
                            sessionID: session.id,
                            minutes: minutes,
                            distanceMeters: Int(distanceText.trimmingCharacters(in: .whitespaces)),
                            intensity: intensity,
                            note: note
                        )
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let plan = session.swimPlan {
                    minutes = plan.targetMinutes
                    intensity = plan.intensity
                }
            }
        }
    }
}
