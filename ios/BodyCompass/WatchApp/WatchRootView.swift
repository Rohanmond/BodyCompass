import SwiftUI
import WatchKit

struct WatchRootView: View {
    @EnvironmentObject private var store: WatchRoutineStore
    @EnvironmentObject private var workout: WatchWorkoutManager
    @AppStorage("bodycompass.watch.hapticsEnabled") private var hapticsEnabled = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(store.today.weekday.displayName)
                        .font(.headline)
                    Text(store.today.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(store.today.sessions) { session in
                    if session.kind == .strength {
                        NavigationLink {
                            WatchStrengthSessionView(session: session)
                        } label: {
                            Label(session.title, systemImage: "dumbbell")
                        }
                    } else if session.kind == .swimming {
                        NavigationLink {
                            WatchSwimLogView(session: session)
                        } label: {
                            Label(session.title, systemImage: "figure.pool.swim")
                        }
                    }
                }

                if store.today.sessions.isEmpty {
                    ContentUnavailableView("Rest Day", systemImage: "moon.zzz")
                }

                if store.pendingStrengthLogs.count + store.pendingSwimLogs.count > 0 {
                    Label(
                        "\(store.pendingStrengthLogs.count + store.pendingSwimLogs.count) waiting to sync",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("Settings") {
                    Toggle("Workout haptics", isOn: $hapticsEnabled)
                }
            }
            .navigationTitle("BodyCompass")
        }
    }
}

struct WatchStrengthSessionView: View {
    @EnvironmentObject private var workout: WatchWorkoutManager
    @EnvironmentObject private var store: WatchRoutineStore
    let session: TrainingSession
    @State private var confirmsEnd = false

    var body: some View {
        List {
            Section {
                workoutControls
                if workout.state == .running || workout.state == .paused {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(watchDuration(workout.elapsedTime(at: context.date)), systemImage: "timer")
                                .monospacedDigit()
                            HStack {
                                Label("\(Int(workout.heartRate))", systemImage: "heart.fill")
                                    .foregroundStyle(.red)
                                Spacer()
                                Label("\(Int(workout.activeEnergy))", systemImage: "flame.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(.caption)
                    }
                }

                Text("\(store.sessionSetCount(sessionID: session.id, date: dateKey)) sets logged")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section("Exercises") {
                ForEach(session.exercises) { exercise in
                    NavigationLink {
                        WatchExerciseView(session: session, exercise: exercise)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(exercise.name)
                            Text("\(exercise.setsText) · RIR \(exercise.targetRIR)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if session.exercises.isEmpty {
                    Text("Finish training setup on iPhone to sync detailed exercises.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(session.title)
        .confirmationDialog("End and save this workout?", isPresented: $confirmsEnd) {
            Button("End Workout", role: .destructive) { workout.end() }
            Button("Keep Training", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var workoutControls: some View {
        switch workout.state {
        case .idle:
            Button {
                workout.startStrength()
            } label: {
                Label("Start Workout", systemImage: "play.fill")
            }
            .tint(.green)
        case .authorizing:
            HStack { ProgressView(); Text("Connecting Health") }
        case .running, .paused:
            HStack {
                Button { workout.togglePause() } label: {
                    Image(systemName: workout.state == .paused ? "play.fill" : "pause.fill")
                }
                .tint(.yellow)
                Button { confirmsEnd = true } label: {
                    Image(systemName: "stop.fill")
                }
                .tint(.red)
            }
        case .ending:
            HStack { ProgressView(); Text("Saving") }
        case .completed(let summary):
            VStack(alignment: .leading, spacing: 5) {
                Label("Workout saved", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("\(watchDuration(summary.duration)) · \(Int(summary.activeEnergy)) kcal")
                    .font(.caption)
                if summary.finalHeartRate > 0 {
                    Text("Final heart rate: \(Int(summary.finalHeartRate)) bpm")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Button("Done") { workout.reset() }
            }
        case .failed(let message):
            VStack(alignment: .leading) {
                Text(message).font(.caption).foregroundStyle(.red)
                Button("Reset") { workout.reset() }
            }
        }
    }

    private var dateKey: String { watchDateKey() }
}

private enum WatchPainRating: String, CaseIterable, Identifiable {
    case none
    case mild
    case moderate
    case severe

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var note: String? {
        self == .none ? nil : "\(displayName) pain or discomfort reported on Watch."
    }
}

struct WatchExerciseView: View {
    @EnvironmentObject private var store: WatchRoutineStore

    let session: TrainingSession
    let exercise: ExercisePrescription

    @AppStorage("bodycompass.watch.hapticsEnabled") private var hapticsEnabled = true
    @State private var loadKg = 0.0
    @State private var reps: Int
    @State private var rir: Int
    @State private var selectedExerciseName: String
    @State private var painRating: WatchPainRating = .none
    @State private var restRemaining = 0
    @State private var restTask: Task<Void, Never>?
    @State private var loadedBaseline = false

    init(session: TrainingSession, exercise: ExercisePrescription) {
        self.session = session
        self.exercise = exercise
        _reps = State(initialValue: exercise.repRangeLower)
        _rir = State(initialValue: exercise.targetRIR)
        _selectedExerciseName = State(initialValue: exercise.name)
    }

    var body: some View {
        List {
            Section {
                Text("\(exercise.setsText) · RIR \(exercise.targetRIR)")
                    .font(.caption)
                if !exercise.warmUp.isEmpty {
                    Text(exercise.warmUp)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if restRemaining > 0 {
                    Label("Rest \(restRemaining)s", systemImage: "timer")
                        .foregroundStyle(.yellow)
                }
            }

            if !exercise.substitutions.isEmpty {
                Section("Exercise") {
                    Picker("Movement", selection: $selectedExerciseName) {
                        Text(exercise.name).tag(exercise.name)
                        ForEach(exercise.substitutions, id: \.self) { substitution in
                            Text(substitution).tag(substitution)
                        }
                    }
                }
            }

            if !previousLogs.isEmpty {
                Section("Last Time") {
                    ForEach(previousLogs) { log in
                        Text("Set \(log.setNumber): \(log.loadKg, specifier: "%.1f") kg × \(log.reps)")
                            .font(.caption)
                    }
                }
            }

            Section("Set \(nextSetNumber)") {
                Stepper("\(loadKg, specifier: "%.1f") kg", value: $loadKg, in: 0...400, step: 0.5)
                Stepper("\(reps) reps", value: $reps, in: 1...50)
                Stepper("RIR \(rir)", value: $rir, in: 0...5)
                Picker("Pain", selection: $painRating) {
                    ForEach(WatchPainRating.allCases) { rating in
                        Text(rating.displayName).tag(rating)
                    }
                }
                if painRating != .none {
                    Text("Stop if pain is sharp, severe, or worsening. Choose a safer movement or end the session.")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                Button {
                    logSet()
                } label: {
                    Label("Complete Set", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            }
        }
        .navigationTitle(selectedExerciseName)
        .onAppear { loadPreviousBaselineIfNeeded() }
        .onChange(of: selectedExerciseName) { _, _ in
            loadedBaseline = false
            loadPreviousBaselineIfNeeded()
        }
        .onDisappear { restTask?.cancel() }
    }

    private var dateKey: String {
        watchDateKey()
    }

    private var nextSetNumber: Int {
        store.localLogs(exerciseName: selectedExerciseName, date: dateKey).count + 1
    }

    private var previousLogs: [ExerciseSetLog] {
        store.previousLogs(exerciseName: selectedExerciseName, before: dateKey)
    }

    private func loadPreviousBaselineIfNeeded() {
        guard !loadedBaseline else { return }
        loadedBaseline = true
        if let previous = previousLogs.last {
            loadKg = previous.loadKg
            reps = previous.reps
            rir = previous.rir ?? exercise.targetRIR
        }
    }

    private func logSet() {
        store.queue(ExerciseSetLog(
            date: dateKey,
            sessionID: session.id,
            exerciseName: selectedExerciseName,
            setNumber: nextSetNumber,
            loadKg: loadKg,
            reps: reps,
            rir: rir,
            painNote: painRating.note
        ))
        if hapticsEnabled {
            WKInterfaceDevice.current().play(painRating == .none ? .success : .failure)
        }
        painRating = .none
        startRest(seconds: exercise.restSeconds)
    }

    private func startRest(seconds: Int) {
        restTask?.cancel()
        restRemaining = seconds
        restTask = Task {
            while !Task.isCancelled && restRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled { restRemaining -= 1 }
            }
            if !Task.isCancelled && hapticsEnabled {
                WKInterfaceDevice.current().play(.notification)
            }
        }
    }
}

struct WatchSwimLogView: View {
    @EnvironmentObject private var store: WatchRoutineStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("bodycompass.watch.hapticsEnabled") private var hapticsEnabled = true

    let session: TrainingSession
    @State private var minutes: Int
    @State private var distanceMeters = 0
    @State private var intensity: SwimIntensity

    init(session: TrainingSession) {
        self.session = session
        _minutes = State(initialValue: session.swimPlan?.targetMinutes ?? 30)
        _intensity = State(initialValue: session.swimPlan?.intensity ?? .moderate)
    }

    var body: some View {
        List {
            Text("Live swimming and WorkoutKit arrive in W3. You can log this swim offline now.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Stepper("\(minutes) min", value: $minutes, in: 5...180, step: 5)
            Stepper("\(distanceMeters) m", value: $distanceMeters, in: 0...20_000, step: 50)
            Picker("Effort", selection: $intensity) {
                ForEach(SwimIntensity.allCases, id: \.rawValue) { value in
                    Text(value.displayName).tag(value)
                }
            }
            Button("Save Swim") {
                store.queue(SwimSessionLog(
                    date: dateKey,
                    sessionID: session.id,
                    minutes: minutes,
                    distanceMeters: distanceMeters == 0 ? nil : distanceMeters,
                    intensity: intensity
                ))
                if hapticsEnabled {
                    WKInterfaceDevice.current().play(.success)
                }
                dismiss()
            }
            .tint(.blue)
        }
        .navigationTitle(session.title)
    }

    private var dateKey: String {
        watchDateKey()
    }
}

private func watchDateKey() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    formatter.timeZone = .current
    return formatter.string(from: Date())
}

private func watchDuration(_ interval: TimeInterval) -> String {
    let seconds = max(0, Int(interval))
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
}
