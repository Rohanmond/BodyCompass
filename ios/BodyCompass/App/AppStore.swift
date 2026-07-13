import Foundation
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

@MainActor
final class AppStore: ObservableObject {
    private enum StorageKey {
        static let profile = "bodycompass.profile"
        static let onboardingComplete = "bodycompass.onboardingComplete"
    }

    private let defaults: UserDefaults

    @Published private(set) var profile: BodyProfile
    @Published private(set) var hasCompletedOnboarding: Bool

    static let defaultProfile = BodyProfile(
        name: "Rohan",
        age: 26,
        heightCm: 176,
        weightKg: 80,
        bodyFatPercentage: 22,
        adherenceScore: 0.78,
        workoutTimePreference: .evening
    )

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        profile = Self.loadProfile(from: defaults) ?? Self.defaultProfile
        hasCompletedOnboarding = defaults.bool(forKey: StorageKey.onboardingComplete)
    }

    @Published var today = DailyHealthSnapshot(
        date: "2026-07-06",
        weightKg: 80,
        bodyFatPercentage: 22,
        steps: 8420,
        activeEnergyKcal: 640,
        sleepHours: 7.1,
        restingHeartRate: 58,
        workoutMinutes: 45
    )

    @Published var schedule: [ScheduleItem] = [
        ScheduleItem(title: "Morning weigh-in", isDone: true),
        ScheduleItem(title: "Protein-first breakfast", isDone: true),
        ScheduleItem(title: "Strength training", isDone: false),
        ScheduleItem(title: "10k steps", isDone: false),
        ScheduleItem(title: "Sleep before 11:30 PM", isDone: false)
    ]

    @Published var meals: [MealAnalysis] = [
        MealAnalysis(
            title: "Chicken rice bowl",
            caloriesRange: 620...760,
            proteinGrams: 48,
            carbsGrams: 82,
            fatGrams: 18,
            confidence: 0.74,
            likelyMistakes: ["Oil quantity may be underestimated", "Rice portion needs confirmation"],
            recommendation: "Keep it. Add vegetables and confirm rice weight next time."
        )
    ]

    var projection: GoalProjection {
        (try? GoalProjectionCalculator().project(profile: profile)) ?? GoalProjection(
            currentFatMassKg: 0,
            currentLeanMassKg: 0,
            targetWeightKg: profile.weightKg,
            fatToLoseKg: 0,
            optimumWeeks: 0,
            aggressiveWeeks: 0,
            conservativeWeeks: 0,
            weeklyLossTargetKg: 0,
            dailyDeficitKcal: 0,
            status: .alreadyAtGoal,
            explanation: "Add a valid profile to calculate your target timeline."
        )
    }

    func saveProfile(_ updatedProfile: BodyProfile, completingOnboarding: Bool = false) {
        profile = updatedProfile
        if let data = try? JSONEncoder().encode(updatedProfile) {
            defaults.set(data, forKey: StorageKey.profile)
        }

        if completingOnboarding {
            hasCompletedOnboarding = true
            defaults.set(true, forKey: StorageKey.onboardingComplete)
        }
    }

    private static func loadProfile(from defaults: UserDefaults) -> BodyProfile? {
        guard let data = defaults.data(forKey: StorageKey.profile) else { return nil }
        return try? JSONDecoder().decode(BodyProfile.self, from: data)
    }
}

struct ScheduleItem: Identifiable, Codable, Equatable {
    let id = UUID()
    var title: String
    var isDone: Bool
}
