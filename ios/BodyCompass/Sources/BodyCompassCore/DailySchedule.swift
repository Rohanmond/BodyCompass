import Foundation

/// The kind of a schedule item, used to rank the next best action and to pick
/// an icon. Pure data so it can be reasoned about without any UI framework.
public enum ScheduleCategory: String, Codable, CaseIterable, Sendable {
    case weighIn
    case nutrition
    case training
    case steps
    case sleep
    case other

    public var displayName: String {
        switch self {
        case .weighIn: return "Weigh-in"
        case .nutrition: return "Nutrition"
        case .training: return "Training"
        case .steps: return "Steps"
        case .sleep: return "Sleep"
        case .other: return "Other"
        }
    }

    public var systemImage: String {
        switch self {
        case .weighIn: return "scalemass"
        case .nutrition: return "fork.knife"
        case .training: return "dumbbell"
        case .steps: return "figure.walk"
        case .sleep: return "bed.double"
        case .other: return "circle"
        }
    }
}

public struct ScheduleItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var category: ScheduleCategory
    public var isDone: Bool
    /// Optional local reminder time-of-day. Both must be set for a reminder.
    public var reminderHour: Int?
    public var reminderMinute: Int?

    public init(
        id: UUID = UUID(),
        title: String,
        category: ScheduleCategory = .other,
        isDone: Bool = false,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.isDone = isDone
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
    }

    public var hasReminder: Bool {
        reminderHour != nil && reminderMinute != nil
    }

    // Tolerate older persisted items that predate category/reminder fields.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        category = try container.decodeIfPresent(ScheduleCategory.self, forKey: .category) ?? .other
        isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        reminderHour = try container.decodeIfPresent(Int.self, forKey: .reminderHour)
        reminderMinute = try container.decodeIfPresent(Int.self, forKey: .reminderMinute)
    }
}

public struct AdherenceReport: Equatable, Sendable {
    public let completed: Int
    public let total: Int

    public init(completed: Int, total: Int) {
        self.completed = completed
        self.total = total
    }

    /// Fraction of scheduled items completed, 0...1. An empty schedule is 0.
    public var score: Double {
        total == 0 ? 0 : Double(completed) / Double(total)
    }

    public var percent: Int {
        Int((score * 100).rounded())
    }
}

/// One day's completion result, persisted so a weekly score can be computed.
public struct DayAdherenceRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String { date }
    public var date: String
    public var completed: Int
    public var total: Int

    public init(date: String, completed: Int, total: Int) {
        self.date = date
        self.completed = completed
        self.total = total
    }

    public var score: Double {
        total == 0 ? 0 : Double(completed) / Double(total)
    }
}

public enum AdherenceCalculator {
    public static func daily(for items: [ScheduleItem]) -> AdherenceReport {
        AdherenceReport(completed: items.filter(\.isDone).count, total: items.count)
    }

    /// Average score across the most recent `days` distinct records. Returns nil
    /// when there is no history yet, so the UI can hide an empty stat.
    public static func weekly(records: [DayAdherenceRecord], days: Int = 7) -> Double? {
        let recent = records
            .filter { $0.total > 0 }
            .sorted { $0.date > $1.date }
            .prefix(days)
        guard !recent.isEmpty else { return nil }
        return recent.map(\.score).reduce(0, +) / Double(recent.count)
    }
}

public struct ActionSuggestion: Equatable, Sendable {
    public let headline: String
    public let detail: String

    public init(headline: String, detail: String) {
        self.headline = headline
        self.detail = detail
    }
}

/// Everything the recommender needs about today, kept UI-free and injectable
/// so the logic can be exercised from the command-line check.
public struct DailyContext: Sendable {
    public var steps: Int
    public var stepGoal: Int
    public var workoutMinutes: Int
    public var proteinGrams: Int
    public var proteinTargetGrams: Int
    public var sleepHours: Double?

    public init(
        steps: Int,
        stepGoal: Int = 10_000,
        workoutMinutes: Int,
        proteinGrams: Int,
        proteinTargetGrams: Int,
        sleepHours: Double?
    ) {
        self.steps = steps
        self.stepGoal = stepGoal
        self.workoutMinutes = workoutMinutes
        self.proteinGrams = proteinGrams
        self.proteinTargetGrams = proteinTargetGrams
        self.sleepHours = sleepHours
    }
}

/// Picks the single most impactful remaining action from schedule + metrics.
/// Ordered so lean-mass protection (training and protein) comes before volume
/// work (steps), then recovery, then whatever else is still open.
public enum NextBestAction {
    public static func recommend(schedule: [ScheduleItem], context: DailyContext) -> ActionSuggestion {
        let remaining = schedule.filter { !$0.isDone }

        let trainingPending = remaining.contains { $0.category == .training }
        if trainingPending && context.workoutMinutes == 0 {
            return ActionSuggestion(
                headline: "Get your strength session in",
                detail: "Training is the highest-leverage task left today — it protects lean mass while you cut."
            )
        }

        let proteinShort = context.proteinTargetGrams > 0
            && context.proteinGrams < Int(Double(context.proteinTargetGrams) * 0.7)
        if proteinShort {
            let gap = context.proteinTargetGrams - context.proteinGrams
            return ActionSuggestion(
                headline: "Add a protein source",
                detail: "You're about \(gap)g short of your \(context.proteinTargetGrams)g target. Protein preserves muscle and blunts hunger."
            )
        }

        let stepsPending = remaining.contains { $0.category == .steps }
        if (stepsPending || context.steps < context.stepGoal) && context.steps < Int(Double(context.stepGoal) * 0.6) {
            return ActionSuggestion(
                headline: "Get moving",
                detail: "You're at \(context.steps) of \(context.stepGoal) steps. A brisk walk closes the daily energy gap without extra calorie cuts."
            )
        }

        let sleepPending = remaining.contains { $0.category == .sleep }
        if sleepPending || (context.sleepHours ?? 8) < 6.5 {
            return ActionSuggestion(
                headline: "Protect tonight's sleep",
                detail: "Short sleep raises hunger and drags training quality. Wind down and aim for an earlier night."
            )
        }

        if let next = remaining.first {
            return ActionSuggestion(
                headline: "Finish: \(next.title)",
                detail: "Knock out the last open items to keep your adherence high."
            )
        }

        return ActionSuggestion(
            headline: "Everything's checked off",
            detail: "Great pace. Protect recovery, hold your protein, and let the plan work."
        )
    }
}
