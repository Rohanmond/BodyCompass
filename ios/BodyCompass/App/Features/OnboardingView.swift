import SwiftUI
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ProfileFormView(
                initialProfile: store.profile,
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
    @State private var age: Int
    @State private var heightCm: Double
    @State private var weightKg: Double
    @State private var bodyFatPercentage: Double
    @State private var targetBodyFatPercentage: Double
    @State private var workoutTimePreference: WorkoutTimePreference

    init(
        initialProfile: BodyProfile,
        title: String,
        actionTitle: String,
        onSave: @escaping (BodyProfile) -> Void
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.onSave = onSave
        weeklyWeightTrendKg = initialProfile.weeklyWeightTrendKg
        adherenceScore = initialProfile.adherenceScore
        _name = State(initialValue: initialProfile.name)
        _age = State(initialValue: initialProfile.age)
        _heightCm = State(initialValue: initialProfile.heightCm)
        _weightKg = State(initialValue: initialProfile.weightKg)
        _bodyFatPercentage = State(initialValue: initialProfile.bodyFatPercentage)
        _targetBodyFatPercentage = State(initialValue: initialProfile.targetBodyFatPercentage)
        _workoutTimePreference = State(initialValue: initialProfile.workoutTimePreference)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .textContentType(.name)
                Stepper("Age: \(age)", value: $age, in: 16...100)
                measurementRow(title: "Height", value: $heightCm, range: 120...230, step: 1, unit: "cm")
            } header: {
                Text("About You")
            } footer: {
                Text("Your details stay on this device during the MVP.")
            }

            Section("Starting Point") {
                measurementRow(title: "Weight", value: $weightKg, range: 35...250, step: 0.5, unit: "kg")
                measurementRow(title: "Body fat", value: $bodyFatPercentage, range: 5...60, step: 0.5, unit: "%")
            }

            Section {
                measurementRow(title: "Target body fat", value: $targetBodyFatPercentage, range: 5...35, step: 0.5, unit: "%")
                Picker("Workout time", selection: $workoutTimePreference) {
                    ForEach(WorkoutTimePreference.allCases, id: \.self) { preference in
                        Text(preference.displayName).tag(preference)
                    }
                }
            } header: {
                Text("Goal & Routine")
            } footer: {
                Text("BodyCompass recalculates your timeline as your weekly progress changes. This is coaching guidance, not medical advice.")
            }

            Section {
                Button(actionTitle) {
                    onSave(profile)
                }
                .frame(maxWidth: .infinity)
                .fontWeight(.semibold)
                .disabled(!isValid)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var profile: BodyProfile {
        BodyProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            age: age,
            heightCm: heightCm,
            weightKg: weightKg,
            bodyFatPercentage: bodyFatPercentage,
            targetBodyFatPercentage: targetBodyFatPercentage,
            weeklyWeightTrendKg: weeklyWeightTrendKg,
            adherenceScore: adherenceScore,
            workoutTimePreference: workoutTimePreference
        )
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && targetBodyFatPercentage < bodyFatPercentage
    }

    private func measurementRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String
    ) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue, specifier: step < 1 ? "%.1f" : "%.0f") \(unit)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
