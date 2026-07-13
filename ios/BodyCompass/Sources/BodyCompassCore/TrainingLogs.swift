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
