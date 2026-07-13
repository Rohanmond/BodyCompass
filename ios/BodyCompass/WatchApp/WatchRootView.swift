import SwiftUI
import WatchKit

struct WatchRootView: View {
    @EnvironmentObject private var store: WatchRoutineStore
    @EnvironmentObject private var workout: WatchWorkoutManager

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
            }
            .navigationTitle("BodyCompass")
        }
    }
}

struct WatchStrengthSessionView: View {
    @EnvironmentObject private var workout: WatchWorkoutManager
    let session: TrainingSession

    var body: some View {
        List {
            Section {
                workoutControls
                if workout.state == .running || workout.state == .paused {
                    HStack {
                        Label("\(Int(workout.heartRate))", systemImage: "heart.fill")
                            .foregroundStyle(.red)
                        Spacer()
                        Label("\(Int(workout.activeEnergy))", systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                    }
                    .font(.caption)
                }
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
                Button { workout.end() } label: {
                    Image(systemName: "stop.fill")
                }
                .tint(.red)
            }
        case .ending:
            HStack { ProgressView(); Text("Saving") }
        case .failed(let message):
            VStack(alignment: .leading) {
                Text(message).font(.caption).foregroundStyle(.red)
                Button("Reset") { workout.reset() }
            }
        }
    }
}

struct WatchExerciseView: View {
    @EnvironmentObject private var store: WatchRoutineStore

    let session: TrainingSession
    let exercise: ExercisePrescription

    @State private var loadKg = 0.0
    @State private var reps: Int
    @State private var rir: Int
    @State private var restRemaining = 0
    @State private var restTask: Task<Void, Never>?

    init(session: TrainingSession, exercise: ExercisePrescription) {
        self.session = session
        self.exercise = exercise
        _reps = State(initialValue: exercise.repRangeLower)
        _rir = State(initialValue: exercise.targetRIR)
    }

    var body: some View {
        List {
            Section {
                Text("\(exercise.setsText) · RIR \(exercise.targetRIR)")
                    .font(.caption)
                if restRemaining > 0 {
                    Label("Rest \(restRemaining)s", systemImage: "timer")
                        .foregroundStyle(.yellow)
                }
            }

            Section("Set \(nextSetNumber)") {
                Stepper("\(loadKg, specifier: "%.1f") kg", value: $loadKg, in: 0...400, step: 0.5)
                Stepper("\(reps) reps", value: $reps, in: 1...50)
                Stepper("RIR \(rir)", value: $rir, in: 0...5)
                Button {
                    logSet()
                } label: {
                    Label("Complete Set", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            }
        }
        .navigationTitle(exercise.name)
        .onDisappear { restTask?.cancel() }
    }

    private var dateKey: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }

    private var nextSetNumber: Int {
        store.localLogs(exerciseName: exercise.name, date: dateKey).count + 1
    }

    private func logSet() {
        store.queue(ExerciseSetLog(
            date: dateKey,
            sessionID: session.id,
            exerciseName: exercise.name,
            setNumber: nextSetNumber,
            loadKg: loadKg,
            reps: reps,
            rir: rir
        ))
        WKInterfaceDevice.current().play(.success)
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
            if !Task.isCancelled {
                WKInterfaceDevice.current().play(.notification)
            }
        }
    }
}

struct WatchSwimLogView: View {
    @EnvironmentObject private var store: WatchRoutineStore
    @Environment(\.dismiss) private var dismiss

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
                WKInterfaceDevice.current().play(.success)
                dismiss()
            }
            .tint(.blue)
        }
        .navigationTitle(session.title)
    }

    private var dateKey: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}
