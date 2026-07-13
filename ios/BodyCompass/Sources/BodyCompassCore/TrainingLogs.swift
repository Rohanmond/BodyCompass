import Foundation

// MARK: - Performance logs

/// One completed working set. Loads come only from what the user actually
/// lifted — the app never invents a starting weight.
public struct ExerciseSetLog: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    /// Day key in yyyy-MM-dd form.
    public var date: String
    public var sessionID: UUID
    public var exerciseName: String
    public var setNumber: Int
    public var loadKg: Double
    public var reps: Int
    /// Reps in reserve the set actually finished with, if the user rated it.
    public var rir: Int?
    public var painNote: String?

    public init(
        id: UUID = UUID(),
        date: String,
        sessionID: UUID,
        exerciseName: String,
        setNumber: Int,
        loadKg: Double,
        reps: Int,
        rir: Int? = nil,
        painNote: String? = nil
    ) {
        self.id = id
        self.date = date
        self.sessionID = sessionID
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.loadKg = loadKg
        self.reps = reps
        self.rir = rir
        self.painNote = painNote
    }
}

/// Deterministically reconciles phone and Watch copies of set history. Stable
/// UUIDs make retransmission safe, while incoming values win if a future
/// correction arrives for an existing log.
public enum ExerciseLogReconciler {
    public static func merge(
        existing: [ExerciseSetLog],
        incoming: [ExerciseSetLog],
        limit: Int = 300
    ) -> [ExerciseSetLog] {
        guard limit > 0 else { return [] }
        var byID: [UUID: ExerciseSetLog] = [:]
        existing.forEach { byID[$0.id] = $0 }
        incoming.forEach { byID[$0.id] = $0 }
        let ordered = byID.values.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.exerciseName != $1.exerciseName { return $0.exerciseName < $1.exerciseName }
            if $0.setNumber != $1.setNumber { return $0.setNumber < $1.setNumber }
            return $0.id.uuidString < $1.id.uuidString
        }
        return Array(ordered.suffix(limit))
    }
}

public struct SwimSessionLog: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var date: String
    public var sessionID: UUID
    public var minutes: Int
    public var distanceMeters: Int?
    public var intensity: SwimIntensity
    public var note: String?

    public init(
        id: UUID = UUID(),
        date: String,
        sessionID: UUID,
        minutes: Int,
        distanceMeters: Int? = nil,
        intensity: SwimIntensity,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.sessionID = sessionID
        self.minutes = minutes
        self.distanceMeters = distanceMeters
        self.intensity = intensity
        self.note = note
    }
}

// MARK: - Post-workout recovery

public enum SorenessLevel: Int, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case mild
    case moderate
    case severe

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .mild: return "Mild"
        case .moderate: return "Moderate"
        case .severe: return "Severe"
        }
    }
}

public struct PostWorkoutCheckIn: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var date: String
    public var sessionID: UUID
    /// Whole-session effort from 1 (very easy) to 10 (maximal).
    public var sessionRPE: Int
    public var soreness: SorenessLevel
    public var note: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        date: String,
        sessionID: UUID,
        sessionRPE: Int,
        soreness: SorenessLevel,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.sessionID = sessionID
        self.sessionRPE = min(max(sessionRPE, 1), 10)
        self.soreness = soreness
        self.note = note
        self.createdAt = createdAt
    }
}

public struct RecoveryContext: Equatable, Sendable {
    public var sleepHours: Double?
    public var currentRestingHeartRate: Double?
    public var baselineRestingHeartRate: Double?
    public var oneMinuteHeartRateRecovery: Double?
    public var sessionRPE: Int
    public var soreness: SorenessLevel
    public var averageRIR: Double?
    public var painReported: Bool
    public var plannedWork: Int
    public var completedWork: Int
    public var recentWork: Int
    public var priorWork: Int

    public init(
        sleepHours: Double? = nil,
        currentRestingHeartRate: Double? = nil,
        baselineRestingHeartRate: Double? = nil,
        oneMinuteHeartRateRecovery: Double? = nil,
        sessionRPE: Int,
        soreness: SorenessLevel,
        averageRIR: Double? = nil,
        painReported: Bool = false,
        plannedWork: Int,
        completedWork: Int,
        recentWork: Int,
        priorWork: Int
    ) {
        self.sleepHours = sleepHours
        self.currentRestingHeartRate = currentRestingHeartRate
        self.baselineRestingHeartRate = baselineRestingHeartRate
        self.oneMinuteHeartRateRecovery = oneMinuteHeartRateRecovery
        self.sessionRPE = min(max(sessionRPE, 1), 10)
        self.soreness = soreness
        self.averageRIR = averageRIR
        self.painReported = painReported
        self.plannedWork = max(0, plannedWork)
        self.completedWork = max(0, completedWork)
        self.recentWork = max(0, recentWork)
        self.priorWork = max(0, priorWork)
    }
}

public enum RecoveryRecommendationLevel: String, Codable, Equatable, Sendable {
    case ready
    case maintain
    case recover
    case caution
}

public struct RecoveryRecommendation: Equatable, Sendable {
    public let level: RecoveryRecommendationLevel
    public let headline: String
    public let detail: String
    public let nextSessionAction: String
    public let reasons: [String]

    public init(
        level: RecoveryRecommendationLevel,
        headline: String,
        detail: String,
        nextSessionAction: String,
        reasons: [String]
    ) {
        self.level = level
        self.headline = headline
        self.detail = detail
        self.nextSessionAction = nextSessionAction
        self.reasons = reasons
    }
}

/// Conservative, deterministic recovery guidance. It can hold progression or
/// suggest normal training, but it never edits the routine or prescribes load
/// from heart rate alone.
public enum RecoveryAdvisor {
    public static func recommend(context: RecoveryContext) -> RecoveryRecommendation {
        var strainScore = 0
        var reasons: [String] = []

        if context.painReported {
            reasons.append("Pain or discomfort was logged during this session.")
        }
        if context.soreness == .severe {
            reasons.append("Severe soreness was reported after the session.")
        }
        if context.painReported || context.soreness == .severe {
            appendHeartRateContext(context, to: &reasons)
            return RecoveryRecommendation(
                level: .caution,
                headline: "Pause progression and reassess",
                detail: "Pain or severe soreness outweighs performance numbers. Do not push through sharp, severe, or worsening symptoms.",
                nextSessionAction: "Do not add load next session. Use a pain-free substitution, take recovery time, and seek qualified care when symptoms are severe or persist.",
                reasons: reasons
            )
        }

        if let sleep = context.sleepHours {
            if sleep < 6 {
                strainScore += 2
                reasons.append("Sleep was \(formatted(sleep)) hours, below the recovery floor used by this coach.")
            } else if sleep < 7 {
                strainScore += 1
                reasons.append("Sleep was \(formatted(sleep)) hours, so recovery may be slightly limited.")
            } else {
                reasons.append("Sleep was \(formatted(sleep)) hours.")
            }
        }

        if context.sessionRPE >= 9 {
            strainScore += 2
            reasons.append("Session effort was \(context.sessionRPE)/10, close to maximal.")
        } else if context.sessionRPE >= 8 {
            strainScore += 1
            reasons.append("Session effort was \(context.sessionRPE)/10, a hard day.")
        } else {
            reasons.append("Session effort was \(context.sessionRPE)/10.")
        }

        switch context.soreness {
        case .moderate:
            strainScore += 2
            reasons.append("Moderate soreness was reported.")
        case .mild:
            reasons.append("Only mild soreness was reported.")
        case .none, .severe:
            break
        }

        if let averageRIR = context.averageRIR, averageRIR < 1 {
            strainScore += 1
            reasons.append("Average effort finished below 1 rep in reserve.")
        }

        if context.priorWork > 0 && Double(context.recentWork) > Double(context.priorWork) * 1.25 {
            strainScore += 1
            reasons.append("Seven-day training volume is more than 25% above the previous week.")
        }

        if let current = context.currentRestingHeartRate,
           let baseline = context.baselineRestingHeartRate,
           current - baseline >= 8 {
            strainScore += 1
            reasons.append("Resting heart rate is \(Int((current - baseline).rounded())) bpm above the recent baseline.")
        }

        if context.plannedWork > 0 {
            let percent = Int((Double(context.completedWork) / Double(context.plannedWork) * 100).rounded())
            reasons.append("Completed \(percent)% of planned work.")
        }
        appendHeartRateContext(context, to: &reasons)

        if strainScore >= 4 {
            return RecoveryRecommendation(
                level: .recover,
                headline: "Recovery should lead the next 24 hours",
                detail: "Several recovery signals stacked up today. Treat this as a reason to absorb the work, not to chase more fatigue.",
                nextSessionAction: "Hold progression next session. Prioritize sleep and food, then repeat or slightly reduce the last prescription if warm-up performance is still down.",
                reasons: reasons
            )
        }
        if strainScore >= 2 {
            return RecoveryRecommendation(
                level: .maintain,
                headline: "Keep the plan, skip the extra push",
                detail: "Recovery is mixed. The scheduled plan can remain, but adding unplanned volume or intensity is unlikely to help.",
                nextSessionAction: "Keep the planned prescription and reassess during warm-ups. Progress only when technique, reps, and target RIR are all there.",
                reasons: reasons
            )
        }
        return RecoveryRecommendation(
            level: .ready,
            headline: "Recovery signals support the normal plan",
            detail: "Nothing logged here calls for an automatic reduction. Continue the routine and let exercise-level performance decide progression.",
            nextSessionAction: "Use the existing rep-and-RIR progression suggestion next session. Never force a load increase when warm-ups or technique disagree.",
            reasons: reasons
        )
    }

    private static func appendHeartRateContext(_ context: RecoveryContext, to reasons: inout [String]) {
        guard let recovery = context.oneMinuteHeartRateRecovery else { return }
        reasons.append("Apple Watch recorded a \(Int(recovery.rounded())) bpm one-minute heart-rate drop; it is context only, not a strength-load prescription.")
    }

    private static func formatted(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

// MARK: - Progression

public enum ProgressionAction: Equatable, Sendable {
    /// No history yet: find a working weight, don't chase numbers.
    case establishBaseline
    /// Top of the rep range reached on every set at (or easier than) the
    /// target effort: add a small amount of load next time.
    case increaseLoad(byKg: Double)
    /// Inside the range but not at the top: add reps at the same load.
    case addReps
    /// Under the bottom of the range or ground to failure: hold or reduce.
    case holdOrReduce
    /// The user reported pain on this exercise last time.
    case caution
}

public struct ProgressionSuggestion: Equatable, Sendable {
    public let action: ProgressionAction
    public let headline: String
    public let detail: String

    public init(action: ProgressionAction, headline: String, detail: String) {
        self.action = action
        self.headline = headline
        self.detail = detail
    }
}

/// Conservative double progression: fill the rep range first, then nudge the
/// load. Deterministic — the same logs always produce the same suggestion —
/// so it is testable and never surprises the user.
public enum ProgressionAdvisor {
    /// Smallest sensible load bump. 2.5% of the working load rounded to the
    /// nearest 0.5 kg, but never less than 1 kg so plates actually exist.
    public static func loadIncrement(forLoadKg load: Double) -> Double {
        let raw = load * 0.025
        let rounded = (raw * 2).rounded() / 2
        return max(rounded, 1.0)
    }

    public static func suggest(
        prescription: ExercisePrescription,
        history: [ExerciseSetLog]
    ) -> ProgressionSuggestion {
        let relevant = history.filter { $0.exerciseName == prescription.name }
        guard let lastDate = relevant.map(\.date).max() else {
            return ProgressionSuggestion(
                action: .establishBaseline,
                headline: "Find your working weight",
                detail: "Pick a load you can lift for \(prescription.repRangeText) with about \(prescription.targetRIR) reps left in the tank. Log what you actually did — next session builds on it."
            )
        }
        let lastSession = relevant
            .filter { $0.date == lastDate }
            .sorted { $0.setNumber < $1.setNumber }

        if lastSession.contains(where: { $0.painNote?.isEmpty == false }) {
            return ProgressionSuggestion(
                action: .caution,
                headline: "Ease off — pain was reported last time",
                detail: "Reduce the load, tighten form, or use a substitution. Pain is a stop signal, not something to push through."
            )
        }

        let topLoad = lastSession.map(\.loadKg).max() ?? 0

        let allAtTop = lastSession.allSatisfy { set in
            set.reps >= prescription.repRangeUpper && (set.rir ?? prescription.targetRIR) >= prescription.targetRIR
        }
        if allAtTop {
            let bump = loadIncrement(forLoadKg: topLoad)
            return ProgressionSuggestion(
                action: .increaseLoad(byKg: bump),
                headline: "Add \(trimmed(bump)) kg",
                detail: "Every set hit \(prescription.repRangeUpper) reps at your target effort last time (\(trimmed(topLoad)) kg). Go to \(trimmed(topLoad + bump)) kg and drop back to \(prescription.repRangeLower)+ reps."
            )
        }

        let anyBelowBottom = lastSession.contains { $0.reps < prescription.repRangeLower }
        let anyAtFailure = lastSession.contains { ($0.rir ?? prescription.targetRIR) == 0 }
        if anyBelowBottom || anyAtFailure {
            return ProgressionSuggestion(
                action: .holdOrReduce,
                headline: "Hold the load — own the range first",
                detail: anyBelowBottom
                    ? "Some sets fell under \(prescription.repRangeLower) reps at \(trimmed(topLoad)) kg. Stay there (or drop ~5%) until every set is inside the range."
                    : "You went to failure last time. Keep \(trimmed(topLoad)) kg and stop at \(prescription.targetRIR) reps in reserve."
            )
        }

        return ProgressionSuggestion(
            action: .addReps,
            headline: "Same load, add reps",
            detail: "Keep \(trimmed(topLoad)) kg and push each set toward \(prescription.repRangeUpper) reps at \(prescription.targetRIR) RIR. When every set gets there, the load goes up."
        )
    }

    private static func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}
