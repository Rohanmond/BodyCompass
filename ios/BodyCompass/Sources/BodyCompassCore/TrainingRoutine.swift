import Foundation

/// Day of week for the repeating routine. Raw values run Monday = 1 through
/// Sunday = 7 so the seeded split reads in the same order as the plan docs.
public enum Weekday: Int, Codable, CaseIterable, Comparable, Sendable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    public var displayName: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }

    public var shortName: String { String(displayName.prefix(3)) }

    /// Converts Foundation's `Calendar.component(.weekday, ...)` value, which
    /// is 1 = Sunday ... 7 = Saturday, into this Monday-first enum.
    public init(calendarWeekday: Int) {
        let mondayFirst = calendarWeekday == 1 ? 7 : calendarWeekday - 1
        self = Weekday(rawValue: mondayFirst) ?? .monday
    }

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum TrainingSessionKind: String, Codable, CaseIterable, Sendable {
    case strength
    case swimming
    case recovery

    public var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .swimming: return "Swimming"
        case .recovery: return "Recovery"
        }
    }

    public var systemImage: String {
        switch self {
        case .strength: return "dumbbell"
        case .swimming: return "figure.pool.swim"
        case .recovery: return "leaf"
        }
    }
}

public enum SwimIntensity: String, Codable, CaseIterable, Sendable {
    case easy, moderate, hard

    public var displayName: String { rawValue.capitalized }
}

/// Target plan for one swimming session. No pace targets: duration plus a
/// simple effort bucket is enough to manage weekly load.
public struct SwimPlan: Codable, Equatable, Sendable {
    public var targetMinutes: Int
    public var intensity: SwimIntensity

    public init(targetMinutes: Int, intensity: SwimIntensity) {
        self.targetMinutes = targetMinutes
        self.intensity = intensity
    }
}

/// One exercise inside a strength session. Loads are intentionally absent:
/// the app never guesses a starting weight; it prescribes reps and effort and
/// learns loads from what the user actually logs.
public struct ExercisePrescription: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var warmUp: String
    public var workingSets: Int
    public var repRangeLower: Int
    public var repRangeUpper: Int
    /// Reps in reserve to stop at. 2 means "stop two reps before failure".
    public var targetRIR: Int
    public var restSeconds: Int
    public var techniqueNotes: String
    public var substitutions: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        warmUp: String = "",
        workingSets: Int,
        repRangeLower: Int,
        repRangeUpper: Int,
        targetRIR: Int = 2,
        restSeconds: Int = 120,
        techniqueNotes: String = "",
        substitutions: [String] = []
    ) {
        self.id = id
        self.name = name
        self.warmUp = warmUp
        self.workingSets = workingSets
        self.repRangeLower = repRangeLower
        self.repRangeUpper = repRangeUpper
        self.targetRIR = targetRIR
        self.restSeconds = restSeconds
        self.techniqueNotes = techniqueNotes
        self.substitutions = substitutions
    }

    public var repRangeText: String { "\(repRangeLower)–\(repRangeUpper) reps" }
    public var setsText: String { "\(workingSets) × \(repRangeLower)–\(repRangeUpper)" }
}

/// One session within a training day. A day may hold several (for example
/// back + biceps followed by swimming on Tuesday).
public struct TrainingSession: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var kind: TrainingSessionKind
    public var muscleGroups: [String]
    public var exercises: [ExercisePrescription]
    public var swimPlan: SwimPlan?
    public var notes: String

    public init(
        id: UUID = UUID(),
        title: String,
        kind: TrainingSessionKind,
        muscleGroups: [String] = [],
        exercises: [ExercisePrescription] = [],
        swimPlan: SwimPlan? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.muscleGroups = muscleGroups
        self.exercises = exercises
        self.swimPlan = swimPlan
        self.notes = notes
    }
}

public struct TrainingDay: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var weekday: Weekday
    public var sessions: [TrainingSession]

    public init(id: UUID = UUID(), weekday: Weekday, sessions: [TrainingSession] = []) {
        self.id = id
        self.weekday = weekday
        self.sessions = sessions
    }

    public var isRestDay: Bool {
        sessions.isEmpty || sessions.allSatisfy { $0.kind == .recovery }
    }

    public var summary: String {
        sessions.isEmpty ? "Rest" : sessions.map(\.title).joined(separator: ", ")
    }
}

public enum RoutineSource: String, Codable, Sendable {
    case seed
    case user
    case coach

    public var displayName: String {
        switch self {
        case .seed: return "Starting plan"
        case .user: return "Your edit"
        case .coach: return "Coach change"
        }
    }
}

/// One immutable version of the weekly routine. Edits and confirmed coach
/// proposals append new versions; nothing rewrites an old one, so history and
/// rollback stay trivial.
public struct TrainingRoutine: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var version: Int
    public var source: RoutineSource
    public var changeSummary: String
    public var createdAt: Date
    public var days: [TrainingDay]

    public init(
        id: UUID = UUID(),
        version: Int,
        source: RoutineSource,
        changeSummary: String,
        createdAt: Date = Date(),
        days: [TrainingDay]
    ) {
        self.id = id
        self.version = version
        self.source = source
        self.changeSummary = changeSummary
        self.createdAt = createdAt
        self.days = days.sorted { $0.weekday < $1.weekday }
    }

    public func day(for weekday: Weekday) -> TrainingDay? {
        days.first { $0.weekday == weekday }
    }

    public var weeklySessionCount: Int {
        days.reduce(0) { $0 + $1.sessions.filter { $0.kind != .recovery }.count }
    }
}

// MARK: - Validation

public enum RoutineValidationError: Error, Equatable, Sendable {
    case wrongDayCount(Int)
    case duplicateWeekday(Weekday)
    case emptySessionTitle(Weekday)
    case strengthSessionWithoutExercises(Weekday, String)
    case swimmingSessionWithoutPlan(Weekday, String)
    case invalidSets(String)
    case invalidRepRange(String)
    case invalidEffort(String)
    case invalidRest(String)
    case invalidSwimDuration(Weekday, String)

    public var message: String {
        switch self {
        case .wrongDayCount(let count):
            return "A routine must cover all 7 days; this one has \(count)."
        case .duplicateWeekday(let day):
            return "\(day.displayName) appears more than once."
        case .emptySessionTitle(let day):
            return "A session on \(day.displayName) has no name."
        case .strengthSessionWithoutExercises(let day, let title):
            return "\(title) (\(day.displayName)) is a strength session with no exercises."
        case .swimmingSessionWithoutPlan(let day, let title):
            return "\(title) (\(day.displayName)) is a swimming session with no duration."
        case .invalidSets(let name):
            return "\(name): working sets must be between 1 and 10."
        case .invalidRepRange(let name):
            return "\(name): rep range must be increasing and between 1 and 50."
        case .invalidEffort(let name):
            return "\(name): target RIR must be between 0 and 5."
        case .invalidRest(let name):
            return "\(name): rest must be between 15 seconds and 10 minutes."
        case .invalidSwimDuration(let day, let title):
            return "\(title) (\(day.displayName)): swim duration must be 5–180 minutes."
        }
    }
}

public enum RoutineValidator {
    /// Structural checks always run. Detail checks (exercises present, swim
    /// plans present) only apply once the routine claims to be detailed —
    /// the seeded skeleton before the setup questionnaire is legitimately
    /// title-only.
    public static func validate(days: [TrainingDay], requireDetail: Bool) -> [RoutineValidationError] {
        var errors: [RoutineValidationError] = []

        if days.count != 7 {
            errors.append(.wrongDayCount(days.count))
        }
        var seen = Set<Weekday>()
        for day in days {
            if !seen.insert(day.weekday).inserted {
                errors.append(.duplicateWeekday(day.weekday))
            }
            for session in day.sessions {
                if session.title.trimmingCharacters(in: .whitespaces).isEmpty {
                    errors.append(.emptySessionTitle(day.weekday))
                }
                if requireDetail {
                    switch session.kind {
                    case .strength where session.exercises.isEmpty:
                        errors.append(.strengthSessionWithoutExercises(day.weekday, session.title))
                    case .swimming where session.swimPlan == nil:
                        errors.append(.swimmingSessionWithoutPlan(day.weekday, session.title))
                    default:
                        break
                    }
                }
                if let plan = session.swimPlan, !(5...180).contains(plan.targetMinutes) {
                    errors.append(.invalidSwimDuration(day.weekday, session.title))
                }
                for exercise in session.exercises {
                    if !(1...10).contains(exercise.workingSets) {
                        errors.append(.invalidSets(exercise.name))
                    }
                    if exercise.repRangeLower < 1 || exercise.repRangeUpper > 50
                        || exercise.repRangeLower > exercise.repRangeUpper {
                        errors.append(.invalidRepRange(exercise.name))
                    }
                    if !(0...5).contains(exercise.targetRIR) {
                        errors.append(.invalidEffort(exercise.name))
                    }
                    if !(15...600).contains(exercise.restSeconds) {
                        errors.append(.invalidRest(exercise.name))
                    }
                }
            }
        }
        return errors
    }

    public static func validate(_ routine: TrainingRoutine, requireDetail: Bool) -> [RoutineValidationError] {
        validate(days: routine.days, requireDetail: requireDetail)
    }
}

// MARK: - Edit review warnings

/// Non-blocking cautions shown before saving a manual edit that materially
/// increases load or removes the only easy day. The user can always proceed;
/// they stay in control of their own plan.
public enum RoutineChangeReview {
    public static func warnings(from old: [TrainingDay], to new: [TrainingDay]) -> [String] {
        var warnings: [String] = []

        let oldCount = sessionCount(of: old)
        let newCount = sessionCount(of: new)
        if newCount > oldCount + 1 {
            warnings.append(
                "Weekly sessions jump from \(oldCount) to \(newCount). Adding volume gradually recovers better."
            )
        }

        let oldRest = old.filter(\.isRestDay).count
        let newRest = new.filter(\.isRestDay).count
        if oldRest > 0 && newRest == 0 {
            warnings.append(
                "This removes your only rest day. With nine weekly exposures, one easy day protects progress."
            )
        }

        let oldHardSwims = hardSwimCount(of: old)
        let newHardSwims = hardSwimCount(of: new)
        if newHardSwims > oldHardSwims && newHardSwims >= 3 {
            warnings.append(
                "\(newHardSwims) hard swims in one week is a lot next to four lifting days. Consider keeping some easy."
            )
        }

        return warnings
    }

    private static func sessionCount(of days: [TrainingDay]) -> Int {
        days.reduce(0) { $0 + $1.sessions.filter { $0.kind != .recovery }.count }
    }

    private static func hardSwimCount(of days: [TrainingDay]) -> Int {
        days.reduce(0) { total, day in
            total + day.sessions.filter { $0.kind == .swimming && $0.swimPlan?.intensity == .hard }.count
        }
    }
}

// MARK: - One-day exceptions

/// A change that applies to a single calendar date without touching the
/// repeating routine: skip the day, take it easy, or run different sessions.
public struct TrainingDayException: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    /// Day key in yyyy-MM-dd form, matching the rest of the app's daily keys.
    public var date: String
    /// Replacement sessions for that date. Empty means rest/skip.
    public var sessions: [TrainingSession]
    public var note: String

    public init(id: UUID = UUID(), date: String, sessions: [TrainingSession] = [], note: String = "") {
        self.id = id
        self.date = date
        self.sessions = sessions
        self.note = note
    }
}

/// What the user should actually do on a given date once exceptions are
/// applied on top of the repeating routine.
public struct EffectiveTrainingDay: Equatable, Sendable {
    public let weekday: Weekday
    public let sessions: [TrainingSession]
    public let exception: TrainingDayException?

    public var isException: Bool { exception != nil }

    public init(weekday: Weekday, sessions: [TrainingSession], exception: TrainingDayException? = nil) {
        self.weekday = weekday
        self.sessions = sessions
        self.exception = exception
    }
}

public enum TrainingScheduleResolver {
    public static func effectiveDay(
        routine: TrainingRoutine,
        weekday: Weekday,
        dateKey: String,
        exceptions: [TrainingDayException]
    ) -> EffectiveTrainingDay {
        if let exception = exceptions.first(where: { $0.date == dateKey }) {
            return EffectiveTrainingDay(weekday: weekday, sessions: exception.sessions, exception: exception)
        }
        let sessions = routine.day(for: weekday)?.sessions ?? []
        return EffectiveTrainingDay(weekday: weekday, sessions: sessions)
    }
}

// MARK: - Diff between two weekly plans

public struct RoutineDayChange: Identifiable, Equatable, Sendable {
    public var id: Weekday { weekday }
    public let weekday: Weekday
    public let before: String
    public let after: String

    public init(weekday: Weekday, before: String, after: String) {
        self.weekday = weekday
        self.before = before
        self.after = after
    }
}

public enum RoutineDiff {
    /// Day-level before/after summaries for every day that changed. Compares
    /// content (titles, exercises, plans), not identity, so re-created days
    /// with identical content do not show as changes.
    public static func changes(from old: [TrainingDay], to new: [TrainingDay]) -> [RoutineDayChange] {
        Weekday.allCases.compactMap { weekday in
            let oldDay = old.first { $0.weekday == weekday }
            let newDay = new.first { $0.weekday == weekday }
            let before = describe(oldDay)
            let after = describe(newDay)
            guard before != after else { return nil }
            return RoutineDayChange(weekday: weekday, before: before, after: after)
        }
    }

    private static func describe(_ day: TrainingDay?) -> String {
        guard let day, !day.sessions.isEmpty else { return "Rest" }
        return day.sessions.map { session in
            var parts = [session.title]
            if session.kind == .strength {
                let names = session.exercises.map { "\($0.name) \($0.setsText)" }
                if !names.isEmpty { parts.append(names.joined(separator: "; ")) }
            }
            if let plan = session.swimPlan {
                parts.append("\(plan.targetMinutes) min \(plan.intensity.displayName.lowercased())")
            }
            return parts.joined(separator: " — ")
        }.joined(separator: " + ")
    }
}

// MARK: - Coach change proposals

public enum ProposalStatus: String, Codable, Sendable {
    case pending
    case confirmed
    case rejected

    public var displayName: String { rawValue.capitalized }
}

/// A structured routine change suggested by Coach. It never activates by
/// itself: only an explicit user confirmation turns it into a new version.
public struct RoutineChangeProposal: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var createdAt: Date
    /// Version number of the routine the proposal was built against, so a
    /// stale proposal can be detected after the user edits manually.
    public var baseVersion: Int
    public var proposedDays: [TrainingDay]
    public var reasons: [String]
    public var expectedBenefit: String
    public var recoveryImpact: String
    public var status: ProposalStatus
    public var decidedAt: Date?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        baseVersion: Int,
        proposedDays: [TrainingDay],
        reasons: [String],
        expectedBenefit: String,
        recoveryImpact: String,
        status: ProposalStatus = .pending,
        decidedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.baseVersion = baseVersion
        self.proposedDays = proposedDays
        self.reasons = reasons
        self.expectedBenefit = expectedBenefit
        self.recoveryImpact = recoveryImpact
        self.status = status
        self.decidedAt = decidedAt
    }

    public func isStale(activeVersion: Int) -> Bool {
        baseVersion != activeVersion
    }
}
