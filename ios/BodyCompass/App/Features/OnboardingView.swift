import SwiftUI
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ProfileFormView(
                initialProfile: nil,
                title: "Build Your Compass",
                actionTitle: "See My Plan"
            ) { profile in
                store.saveProfile(profile, completingOnboarding: true)
            }
        }
    }
}

struct ProfileFormView: View {
    let title: String
    let actionTitle: String
    let onSave: (BodyProfile) -> Void
    private let weeklyWeightTrendKg: Double?
    private let adherenceScore: Double

    @State private var name: String
    @State private var age: String
    @State private var heightCm: String
    @State private var weightKg: String
    @State private var bodyFatPercentage: String
    @State private var targetBodyFatPercentage: String
    @State private var workoutTimePreference: WorkoutTimePreference?

    init(
        initialProfile: BodyProfile?,
        title: String,
        actionTitle: String,
        onSave: @escaping (BodyProfile) -> Void
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.onSave = onSave
        weeklyWeightTrendKg = initialProfile?.weeklyWeightTrendKg
        adherenceScore = initialProfile?.adherenceScore ?? 0.75
        _name = State(initialValue: initialProfile?.name ?? "")
        _age = State(initialValue: initialProfile.map { String($0.age) } ?? "")
        _heightCm = State(initialValue: initialProfile.map { Self.number($0.heightCm) } ?? "")
        _weightKg = State(initialValue: initialProfile.map { Self.number($0.weightKg) } ?? "")
        _bodyFatPercentage = State(initialValue: initialProfile.map { Self.number($0.bodyFatPercentage) } ?? "")
        _targetBodyFatPercentage = State(initialValue: initialProfile.map { Self.number($0.targetBodyFatPercentage) } ?? "")
        _workoutTimePreference = State(initialValue: initialProfile?.workoutTimePreference)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .textContentType(.name)
                numberField("Age", text: $age, unit: "years", keyboard: .numberPad)
                numberField("Height", text: $heightCm, unit: "cm")
            } header: {
                Text("About You")
            } footer: {
                Text("Used to personalize your projections and coaching.")
            }

            Section("Starting Point") {
                numberField("Weight", text: $weightKg, unit: "kg")
                numberField("Body fat", text: $bodyFatPercentage, unit: "%")
            }

            Section {
                numberField("Target body fat", text: $targetBodyFatPercentage, unit: "%")
                Picker("Workout time", selection: $workoutTimePreference) {
                    Text("Select").tag(nil as WorkoutTimePreference?)
                    ForEach(WorkoutTimePreference.allCases, id: \.self) { preference in
                        Text(preference.displayName).tag(Optional(preference))
                    }
                }
            } header: {
                Text("Goal & Routine")
            } footer: {
                Text("BodyCompass recalculates your timeline as your weekly progress changes. This is coaching guidance, not medical advice.")
            }

            Section {
                Button(actionTitle) {
                    guard let profile else { return }
                    onSave(profile)
                }
                .frame(maxWidth: .infinity)
                .fontWeight(.semibold)
                .disabled(!isValid)
            } footer: {
                if hasStarted && !isValid {
                    Text("Complete every field with realistic values. Your target body fat must be lower than your current estimate.")
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var profile: BodyProfile? {
        guard let ageValue = Int(age),
              let heightValue = decimal(heightCm),
              let weightValue = decimal(weightKg),
              let bodyFatValue = decimal(bodyFatPercentage),
              let targetValue = decimal(targetBodyFatPercentage),
              let workoutTimePreference else { return nil }
        return BodyProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            age: ageValue,
            heightCm: heightValue,
            weightKg: weightValue,
            bodyFatPercentage: bodyFatValue,
            targetBodyFatPercentage: targetValue,
            weeklyWeightTrendKg: weeklyWeightTrendKg,
            adherenceScore: adherenceScore,
            workoutTimePreference: workoutTimePreference
        )
    }

    private var isValid: Bool {
        guard let profile else { return false }
        return !profile.name.isEmpty
            && (16...100).contains(profile.age)
            && (120...230).contains(profile.heightCm)
            && (35...250).contains(profile.weightKg)
            && (5...60).contains(profile.bodyFatPercentage)
            && (5...35).contains(profile.targetBodyFatPercentage)
            && profile.targetBodyFatPercentage < profile.bodyFatPercentage
    }

    private var hasStarted: Bool {
        !name.isEmpty || !age.isEmpty || !heightCm.isEmpty || !weightKg.isEmpty
            || !bodyFatPercentage.isEmpty || !targetBodyFatPercentage.isEmpty
    }

    private func numberField(_ title: String, text: Binding<String>, unit: String, keyboard: UIKeyboardType = .decimalPad) -> some View {
        HStack {
            TextField(title, text: text)
                .keyboardType(keyboard)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }

    private func decimal(_ value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: "."))
    }

    private static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}
