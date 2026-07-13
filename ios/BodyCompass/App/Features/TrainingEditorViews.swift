import SwiftUI
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

// MARK: - Setup questionnaire

/// Collects the context the app refuses to program without: experience,
/// equipment, limitations, and swimming load.
struct TrainingSetupView: View {
    @EnvironmentObject private var training: TrainingStore
    @Environment(\.dismiss) private var dismiss

    @State private var experience: TrainingExperience = .beginner
    @State private var equipment: EquipmentAccess = .fullGym
    @State private var limitations = ""
    @State private var swimMinutes = 30
    @State private var swimIntensity: SwimIntensity = .easy

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Experience", selection: $experience) {
                        ForEach(TrainingExperience.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(experience.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Lifting experience")
                }

                Section("Equipment") {
                    Picker("Equipment", selection: $equipment) {
                        ForEach(EquipmentAccess.allCases, id: \.self) { access in
                            Text(access.displayName).tag(access)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    TextField("e.g. left knee pain on deep squats", text: $limitations, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Injuries or limitations")
                } footer: {
                    Text("Sessions will carry a reminder to skip or substitute anything that provokes this.")
                }

                Section {
                    Stepper("\(swimMinutes) minutes per swim", value: $swimMinutes, in: 10...120, step: 5)
                    Picker("Usual effort", selection: $swimIntensity) {
                        ForEach(SwimIntensity.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Swimming")
                } footer: {
                    Text("Your week has four swims alongside five lifting sessions. Most should feel easy to moderate so lifting quality doesn't collapse.")
                }
            }
            .navigationTitle("Training setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Build my program") {
                        training.completeSetup(TrainingSetup(
                            experience: experience,
                            equipment: equipment,
                            limitations: limitations.trimmingCharacters(in: .whitespacesAndNewlines),
                            swimMinutes: swimMinutes,
                            swimIntensity: swimIntensity
                        ))
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Day editor

/// Edits one day of the week: rename sessions, change swim plans, manage
/// exercises. The caller decides what saving means (new routine version or a
/// revised Coach proposal), so this view stays reusable.
struct TrainingDayEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let requireDetail: Bool
    let onSave: (TrainingDay) -> Void

    @State private var day: TrainingDay
    @State private var editingExercise: ExerciseLocation?

    private struct ExerciseLocation: Identifiable {
        let sessionIndex: Int
        let exerciseIndex: Int
        var id: String { "\(sessionIndex)-\(exerciseIndex)" }
    }

    init(day: TrainingDay, requireDetail: Bool, onSave: @escaping (TrainingDay) -> Void) {
        self.requireDetail = requireDetail
        self.onSave = onSave
        _day = State(initialValue: day)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(day.sessions.indices, id: \.self) { sessionIndex in
                    sessionSection(sessionIndex)
                }

                Section {
                    Button {
                        day.sessions.append(TrainingSession(title: "Strength session", kind: .strength))
                    } label: {
                        Label("Add strength session", systemImage: "plus")
                    }
                    Button {
                        day.sessions.append(TrainingSession(
                            title: "Swimming", kind: .swimming,
                            swimPlan: SwimPlan(targetMinutes: 30, intensity: .easy)
                        ))
                    } label: {
                        Label("Add swimming session", systemImage: "plus")
                    }
                    if !day.sessions.isEmpty {
                        Button(role: .destructive) {
                            day.sessions.removeAll()
                        } label: {
                            Label("Make this a rest day", systemImage: "leaf")
                        }
                    }
                } footer: {
                    Text("Saving creates a new routine version. Earlier versions stay available under History.")
                }
            }
            .navigationTitle("Edit \(day.weekday.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(day)
                        dismiss()
                    }
                }
            }
            .sheet(item: $editingExercise) { location in
                if location.sessionIndex < day.sessions.count,
                   location.exerciseIndex < day.sessions[location.sessionIndex].exercises.count {
                    ExercisePrescriptionEditor(
                        prescription: day.sessions[location.sessionIndex].exercises[location.exerciseIndex]
                    ) { updated in
                        day.sessions[location.sessionIndex].exercises[location.exerciseIndex] = updated
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sessionSection(_ sessionIndex: Int) -> some View {
        let session = day.sessions[sessionIndex]
        Section {
            TextField("Session name", text: sessionBinding(sessionIndex).title)

            Picker("Type", selection: sessionBinding(sessionIndex).kind) {
                ForEach(TrainingSessionKind.allCases, id: \.self) { kind in
                    Label(kind.displayName, systemImage: kind.systemImage).tag(kind)
                }
            }

            if session.kind == .swimming {
                Stepper(
                    "\(session.swimPlan?.targetMinutes ?? 30) minutes",
                    value: swimMinutesBinding(sessionIndex),
                    in: 5...180,
                    step: 5
                )
                Picker("Intensity", selection: swimIntensityBinding(sessionIndex)) {
                    ForEach(SwimIntensity.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }

            if session.kind == .strength {
                ForEach(session.exercises.indices, id: \.self) { exerciseIndex in
                    Button {
                        editingExercise = ExerciseLocation(sessionIndex: sessionIndex, exerciseIndex: exerciseIndex)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.exercises[exerciseIndex].name)
                                    .foregroundStyle(.primary)
                                Text("\(session.exercises[exerciseIndex].setsText) @ \(session.exercises[exerciseIndex].targetRIR) RIR")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .onDelete { day.sessions[sessionIndex].exercises.remove(atOffsets: $0) }
                .onMove { day.sessions[sessionIndex].exercises.move(fromOffsets: $0, toOffset: $1) }

                Button {
                    day.sessions[sessionIndex].exercises.append(ExercisePrescription(
                        name: "New exercise",
                        workingSets: 3,
                        repRangeLower: 8,
                        repRangeUpper: 12
                    ))
                    editingExercise = ExerciseLocation(
                        sessionIndex: sessionIndex,
                        exerciseIndex: day.sessions[sessionIndex].exercises.count - 1
                    )
                } label: {
                    Label("Add exercise", systemImage: "plus")
                        .font(.subheadline)
                }
            }

            Button(role: .destructive) {
                day.sessions.remove(at: sessionIndex)
            } label: {
                Label("Remove session", systemImage: "trash")
                    .font(.subheadline)
            }
        } header: {
            Text("Session \(sessionIndex + 1)")
        }
    }

    private func sessionBinding(_ index: Int) -> Binding<TrainingSession> {
        Binding(
            get: { day.sessions[index] },
            set: { day.sessions[index] = $0 }
        )
    }

    private func swimMinutesBinding(_ index: Int) -> Binding<Int> {
        Binding(
            get: { day.sessions[index].swimPlan?.targetMinutes ?? 30 },
            set: { newValue in
                let intensity = day.sessions[index].swimPlan?.intensity ?? .easy
                day.sessions[index].swimPlan = SwimPlan(targetMinutes: newValue, intensity: intensity)
            }
        )
    }

    private func swimIntensityBinding(_ index: Int) -> Binding<SwimIntensity> {
        Binding(
            get: { day.sessions[index].swimPlan?.intensity ?? .easy },
            set: { newValue in
                let minutes = day.sessions[index].swimPlan?.targetMinutes ?? 30
                day.sessions[index].swimPlan = SwimPlan(targetMinutes: minutes, intensity: newValue)
            }
        )
    }
}

// MARK: - Exercise editor

struct ExercisePrescriptionEditor: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (ExercisePrescription) -> Void

    @State private var prescription: ExercisePrescription

    init(prescription: ExercisePrescription, onSave: @escaping (ExercisePrescription) -> Void) {
        self.onSave = onSave
        _prescription = State(initialValue: prescription)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Name", text: $prescription.name)
                }

                Section("Prescription") {
                    Stepper("\(prescription.workingSets) working sets", value: $prescription.workingSets, in: 1...10)
                    Stepper("From \(prescription.repRangeLower) reps", value: $prescription.repRangeLower, in: 1...prescription.repRangeUpper)
                    Stepper("To \(prescription.repRangeUpper) reps", value: $prescription.repRangeUpper, in: prescription.repRangeLower...50)
                    Stepper("\(prescription.targetRIR) reps in reserve", value: $prescription.targetRIR, in: 0...5)
                    Stepper("Rest \(prescription.restSeconds) s", value: $prescription.restSeconds, in: 15...600, step: 15)
                }

                Section("Notes") {
                    TextField("Warm-up", text: $prescription.warmUp, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("Technique", text: $prescription.techniqueNotes, axis: .vertical)
                        .lineLimit(1...3)
                }

                if !prescription.substitutions.isEmpty {
                    Section {
                        ForEach(prescription.substitutions, id: \.self) { substitution in
                            Button {
                                swapTo(substitution)
                            } label: {
                                HStack {
                                    Text(substitution)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("Use instead")
                                        .font(.caption.bold())
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                        }
                    } header: {
                        Text("Substitutions")
                    } footer: {
                        Text("Swapping keeps the same sets, reps, effort, and rest.")
                    }
                }
            }
            .navigationTitle("Edit exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(prescription)
                        dismiss()
                    }
                    .disabled(prescription.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func swapTo(_ substitution: String) {
        let previous = prescription.name
        prescription.name = substitution
        prescription.substitutions.removeAll { $0 == substitution }
        prescription.substitutions.append(previous)
    }
}
