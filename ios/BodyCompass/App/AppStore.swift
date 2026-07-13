import Foundation
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

enum HealthSyncStatus: Equatable {
    case idle
    case unavailable
    case needsPermission
    case syncing
    case synced(Date)
}

struct ManualHealthEntry: Codable, Equatable {
    var date: String
    var weightKg: Double?
    var bodyFatPercentage: Double?
    var sleepHours: Double?
}

@MainActor
final class AppStore: ObservableObject {
    private enum StorageKey {
        static let profile = "bodycompass.profile"
        static let onboardingComplete = "bodycompass.onboardingComplete"
        static let manualEntry = "bodycompass.manualEntry"
        static let schedule = "bodycompass.schedule"
        static let scheduleDate = "bodycompass.scheduleDate"
        static let adherenceRecords = "bodycompass.adherenceRecords"
        static let remindersEnabled = "bodycompass.remindersEnabled"
        static let mealHistory = "bodycompass.mealHistory"
    }

    private let defaults: UserDefaults
    private let healthKit = HealthKitService()
    private let reminders = ReminderService()
    private let mealImages = MealImageStore()

    @Published private(set) var profile: BodyProfile
    @Published private(set) var hasCompletedOnboarding: Bool
    @Published private(set) var healthSync: HealthSyncStatus = .idle
    @Published private(set) var manualEntry: ManualHealthEntry?
    @Published private(set) var adherenceRecords: [DayAdherenceRecord] = []
    @Published private(set) var remindersEnabled: Bool = false
    @Published private(set) var mealHistory: [LoggedMeal] = []

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
        manualEntry = Self.loadManualEntry(from: defaults)
        adherenceRecords = Self.loadAdherenceRecords(from: defaults)
        remindersEnabled = defaults.bool(forKey: StorageKey.remindersEnabled)
        mealHistory = Self.loadMealHistory(from: defaults)
        schedule = Self.loadSchedule(from: defaults) ?? Self.defaultSchedule
        applyManualEntry()
        rollScheduleIfNeeded()
        recordTodayAdherence()
    }

    @Published var today = DailyHealthSnapshot(date: HealthKitService.dayKey())

    @Published private(set) var schedule: [ScheduleItem] = []

    static let defaultSchedule: [ScheduleItem] = [
        ScheduleItem(title: "Morning weigh-in", category: .weighIn),
        ScheduleItem(title: "Protein-first breakfast", category: .nutrition),
        ScheduleItem(title: "Strength training", category: .training),
        ScheduleItem(title: "10k steps", category: .steps),
        ScheduleItem(title: "Sleep before 11:30 PM", category: .sleep)
    ]

    var meals: [MealAnalysis] {
        mealHistory.map(\.accepted)
    }

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

    // MARK: - Schedule & adherence

    var dailyAdherence: AdherenceReport {
        AdherenceCalculator.daily(for: schedule)
    }

    var weeklyAdherence: Double? {
        AdherenceCalculator.weekly(records: adherenceRecords)
    }

    /// Roughly 1.8 g of protein per kg of goal weight — enough to protect lean
    /// mass in a deficit without pretending to clinical precision.
    var proteinTargetGrams: Int {
        Int((projection.targetWeightKg * 1.8).rounded())
    }

    private var proteinConsumedGrams: Int {
        meals.reduce(0) { $0 + $1.proteinGrams }
    }

    // MARK: - Meal history

    func saveMeal(
        estimates: MealAnalysisBundle,
        accepted: MealAnalysis,
        notes: String,
        imageData: Data
    ) {
        let id = UUID()
        let filename = try? mealImages.save(imageData, id: id)
        mealHistory.insert(
            LoggedMeal(
                id: id,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                imageFilename: filename,
                estimates: estimates,
                accepted: accepted
            ),
            at: 0
        )
        mealHistory = Array(mealHistory.prefix(200))
        persistMealHistory()
    }

    func deleteMeal(_ meal: LoggedMeal) {
        mealImages.delete(meal.imageFilename)
        mealHistory.removeAll { $0.id == meal.id }
        persistMealHistory()
    }

    func mealImageData(for meal: LoggedMeal) -> Data? {
        mealImages.data(for: meal.imageFilename)
    }

    private func persistMealHistory() {
        if let data = try? JSONEncoder().encode(mealHistory) {
            defaults.set(data, forKey: StorageKey.mealHistory)
        }
    }

    var nextBestAction: ActionSuggestion {
        let context = DailyContext(
            steps: today.steps,
            workoutMinutes: today.workoutMinutes,
            proteinGrams: proteinConsumedGrams,
            proteinTargetGrams: proteinTargetGrams,
            sleepHours: today.sleepHours
        )
        return NextBestAction.recommend(schedule: schedule, context: context)
    }

    func toggleItem(_ item: ScheduleItem) {
        guard let index = schedule.firstIndex(where: { $0.id == item.id }) else { return }
        schedule[index].isDone.toggle()
        persistSchedule()
        recordTodayAdherence()
    }

    func addItem(title: String, category: ScheduleCategory, reminderHour: Int?, reminderMinute: Int?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        schedule.append(
            ScheduleItem(title: trimmed, category: category, reminderHour: reminderHour, reminderMinute: reminderMinute)
        )
        persistSchedule()
        recordTodayAdherence()
        syncReminders()
    }

    func updateItem(_ item: ScheduleItem) {
        guard let index = schedule.firstIndex(where: { $0.id == item.id }) else { return }
        schedule[index] = item
        persistSchedule()
        syncReminders()
    }

    func deleteItems(at offsets: IndexSet) {
        schedule.remove(atOffsets: offsets)
        persistSchedule()
        recordTodayAdherence()
        syncReminders()
    }

    func moveItems(from source: IndexSet, to destination: Int) {
        schedule.move(fromOffsets: source, toOffset: destination)
        persistSchedule()
    }

    // MARK: - Reminders

    func setRemindersEnabled(_ enabled: Bool) async {
        if enabled {
            let granted = await reminders.requestAuthorization()
            remindersEnabled = granted
        } else {
            remindersEnabled = false
            await reminders.cancelAll()
        }
        defaults.set(remindersEnabled, forKey: StorageKey.remindersEnabled)
        if remindersEnabled {
            await reminders.reschedule(for: schedule)
        }
    }

    private func syncReminders() {
        guard remindersEnabled else { return }
        Task { await reminders.reschedule(for: schedule) }
    }

    // MARK: - Persistence & daily roll

    // A new day keeps the item list but clears completion. Yesterday's score is
    // already saved via recordTodayAdherence, so weekly history survives.
    private func rollScheduleIfNeeded() {
        let todayKey = HealthKitService.dayKey()
        let storedDate = defaults.string(forKey: StorageKey.scheduleDate)
        guard storedDate != todayKey else { return }
        for index in schedule.indices {
            schedule[index].isDone = false
        }
        defaults.set(todayKey, forKey: StorageKey.scheduleDate)
        persistSchedule()
    }

    private func recordTodayAdherence() {
        let report = dailyAdherence
        let todayKey = HealthKitService.dayKey()
        let record = DayAdherenceRecord(date: todayKey, completed: report.completed, total: report.total)
        if let index = adherenceRecords.firstIndex(where: { $0.date == todayKey }) {
            adherenceRecords[index] = record
        } else {
            adherenceRecords.append(record)
        }
        // Keep history bounded to the last 60 days.
        adherenceRecords = Array(adherenceRecords.sorted { $0.date > $1.date }.prefix(60))
        if let data = try? JSONEncoder().encode(adherenceRecords) {
            defaults.set(data, forKey: StorageKey.adherenceRecords)
        }
    }

    private func persistSchedule() {
        if let data = try? JSONEncoder().encode(schedule) {
            defaults.set(data, forKey: StorageKey.schedule)
        }
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

    // MARK: - HealthKit sync

    func connectHealthKit() async {
        guard healthKit.isAvailable else {
            healthSync = .unavailable
            return
        }
        try? await healthKit.requestAuthorization()
        await refreshToday()
    }

    func refreshToday() async {
        rollScheduleIfNeeded()
        recordTodayAdherence()
        guard healthKit.isAvailable else {
            healthSync = .unavailable
            return
        }
        if await healthKit.shouldRequestAuthorization() {
            healthSync = .needsPermission
            return
        }
        if healthSync == .syncing { return }

        healthSync = .syncing
        today = await healthKit.dailySnapshot()
        applyManualEntry()
        healthSync = .synced(Date())
    }

    // MARK: - Manual fallback entries

    func saveManualEntry(weightKg: Double?, bodyFatPercentage: Double?, sleepHours: Double?) {
        let entry = ManualHealthEntry(
            date: HealthKitService.dayKey(),
            weightKg: weightKg,
            bodyFatPercentage: bodyFatPercentage,
            sleepHours: sleepHours
        )
        manualEntry = entry
        if let data = try? JSONEncoder().encode(entry) {
            defaults.set(data, forKey: StorageKey.manualEntry)
        }
        applyManualEntry()
    }

    // Manual values win over imported ones so the user can correct bad scale
    // or estimate data (see docs/healthkit.md).
    private func applyManualEntry() {
        guard let entry = manualEntry, entry.date == today.date else { return }
        if let weight = entry.weightKg { today.weightKg = weight }
        if let bodyFat = entry.bodyFatPercentage { today.bodyFatPercentage = bodyFat }
        if let sleep = entry.sleepHours { today.sleepHours = sleep }
    }

    private static func loadProfile(from defaults: UserDefaults) -> BodyProfile? {
        guard let data = defaults.data(forKey: StorageKey.profile) else { return nil }
        return try? JSONDecoder().decode(BodyProfile.self, from: data)
    }

    private static func loadManualEntry(from defaults: UserDefaults) -> ManualHealthEntry? {
        guard let data = defaults.data(forKey: StorageKey.manualEntry) else { return nil }
        return try? JSONDecoder().decode(ManualHealthEntry.self, from: data)
    }

    private static func loadSchedule(from defaults: UserDefaults) -> [ScheduleItem]? {
        guard let data = defaults.data(forKey: StorageKey.schedule) else { return nil }
        return try? JSONDecoder().decode([ScheduleItem].self, from: data)
    }

    private static func loadAdherenceRecords(from defaults: UserDefaults) -> [DayAdherenceRecord] {
        guard let data = defaults.data(forKey: StorageKey.adherenceRecords),
              let records = try? JSONDecoder().decode([DayAdherenceRecord].self, from: data) else { return [] }
        return records
    }

    private static func loadMealHistory(from defaults: UserDefaults) -> [LoggedMeal] {
        guard let data = defaults.data(forKey: StorageKey.mealHistory),
              let meals = try? JSONDecoder().decode([LoggedMeal].self, from: data) else { return [] }
        return meals
    }
}
