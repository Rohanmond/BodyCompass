import SwiftUI
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

/// What to do today: prescriptions, progression hints, and set-by-set logging.
struct TrainingSessionView: View {
    @EnvironmentObject private var training: TrainingStore

    let date: Date

    @State private var loggingExercise: LoggingTarget?
    @State private var loggingSwim: TrainingSession?

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
        }
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
