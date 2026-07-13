import BodyCompassCore
import Foundation

let profile = BodyProfile(
    name: "Rohan",
    age: 26,
    heightCm: 176,
    weightKg: 80,
    bodyFatPercentage: 22,
    adherenceScore: 0.8
)

let projection = try GoalProjectionCalculator().project(profile: profile)

precondition(abs(projection.currentFatMassKg - 17.6) < 0.01)
precondition(abs(projection.currentLeanMassKg - 62.4) < 0.01)
precondition(abs(projection.targetWeightKg - 70.9) < 0.1)
precondition(projection.optimumWeeks > 0)
precondition(projection.status == .onTrack)

let maintenance = try GoalProjectionCalculator().project(
    profile: BodyProfile(
        name: "Rohan",
        age: 26,
        heightCm: 176,
        weightKg: 72,
        bodyFatPercentage: 12
    )
)

precondition(maintenance.status == .alreadyAtGoal)
precondition(maintenance.fatToLoseKg == 0)
precondition(maintenance.optimumWeeks == 0)

// Schedule adherence and next-best-action logic.
let schedule = [
    ScheduleItem(title: "Weigh-in", category: .weighIn, isDone: true),
    ScheduleItem(title: "Strength training", category: .training, isDone: false),
    ScheduleItem(title: "10k steps", category: .steps, isDone: false),
    ScheduleItem(title: "Sleep early", category: .sleep, isDone: false)
]

let daily = AdherenceCalculator.daily(for: schedule)
precondition(daily.completed == 1)
precondition(daily.total == 4)
precondition(daily.percent == 25)

let records = [
    DayAdherenceRecord(date: "2026-07-11", completed: 4, total: 5),
    DayAdherenceRecord(date: "2026-07-12", completed: 3, total: 5)
]
let weekly = AdherenceCalculator.weekly(records: records)
precondition(weekly != nil)
precondition(abs(weekly! - 0.7) < 0.0001)
precondition(AdherenceCalculator.weekly(records: []) == nil)

// Untrained day with no workout should surface training first.
let context = DailyContext(steps: 3000, workoutMinutes: 0, proteinGrams: 40, proteinTargetGrams: 128, sleepHours: 7)
let action = NextBestAction.recommend(schedule: schedule, context: context)
precondition(action.headline == "Get your strength session in")

// A fully complete day with good metrics should read as done.
let doneSchedule = schedule.map { item -> ScheduleItem in
    var copy = item
    copy.isDone = true
    return copy
}
let goodContext = DailyContext(steps: 11_000, workoutMinutes: 45, proteinGrams: 150, proteinTargetGrams: 128, sleepHours: 7.5)
precondition(NextBestAction.recommend(schedule: doneSchedule, context: goodContext).headline == "Everything's checked off")

// MARK: - Structured training (Phase 4)

// The seeded skeleton must match the documented split exactly.
let skeleton = TrainingRoutineSeeder.skeleton()
precondition(skeleton.days.count == 7)
precondition(skeleton.version == 1)
precondition(skeleton.day(for: .monday)?.summary == "Chest + triceps")
precondition(skeleton.day(for: .tuesday)?.sessions.map(\.title) == ["Back + biceps", "Swimming"])
precondition(skeleton.day(for: .wednesday)?.summary == "Legs")
precondition(skeleton.day(for: .thursday)?.summary == "Swimming")
precondition(skeleton.day(for: .friday)?.summary == "Upper body")
precondition(skeleton.day(for: .saturday)?.sessions.map(\.title) == ["Arms", "Swimming"])
precondition(skeleton.day(for: .sunday)?.summary == "Swimming")
precondition(skeleton.weeklySessionCount == 9)

// Skeleton passes structural validation but is not yet detailed.
precondition(RoutineValidator.validate(skeleton, requireDetail: false).isEmpty)
precondition(!RoutineValidator.validate(skeleton, requireDetail: true).isEmpty)

// Detailed seeding fills every strength session and swim plan without loads.
let setup = TrainingSetup(experience: .beginner, equipment: .fullGym, swimMinutes: 40, swimIntensity: .easy)
let detailed = TrainingRoutineSeeder.detailed(setup: setup, version: 2)
precondition(RoutineValidator.validate(detailed, requireDetail: true).isEmpty)
for day in detailed.days {
    for session in day.sessions where session.kind == .strength {
        precondition(!session.exercises.isEmpty)
        for exercise in session.exercises {
            precondition(exercise.workingSets == 3) // beginner volume
            precondition(exercise.targetRIR == 3) // beginner effort buffer
            precondition(!exercise.substitutions.isEmpty || !exercise.techniqueNotes.isEmpty)
        }
    }
    for session in day.sessions where session.kind == .swimming {
        precondition(session.swimPlan?.targetMinutes == 40)
    }
}

// Validation catches broken routines.
var broken = detailed
broken.days.removeLast()
precondition(RoutineValidator.validate(broken, requireDetail: true).contains(.wrongDayCount(6)))

var badRange = detailed
badRange.days[0].sessions[0].exercises[0].repRangeLower = 12
badRange.days[0].sessions[0].exercises[0].repRangeUpper = 8
precondition(RoutineValidator.validate(badRange, requireDetail: true)
    .contains { if case .invalidRepRange = $0 { return true } else { return false } })

// Weekday mapping: Calendar's 1 = Sunday scheme converts to Monday-first.
precondition(Weekday(calendarWeekday: 1) == .sunday)
precondition(Weekday(calendarWeekday: 2) == .monday)
precondition(Weekday(calendarWeekday: 7) == .saturday)

// A one-day exception overrides the date without touching the routine.
let exception = TrainingDayException(date: "2026-07-15", sessions: [], note: "Travel day")
let exceptionDay = TrainingScheduleResolver.effectiveDay(
    routine: detailed, weekday: .wednesday, dateKey: "2026-07-15", exceptions: [exception]
)
precondition(exceptionDay.isException)
precondition(exceptionDay.sessions.isEmpty)
let normalDay = TrainingScheduleResolver.effectiveDay(
    routine: detailed, weekday: .wednesday, dateKey: "2026-07-22", exceptions: [exception]
)
precondition(!normalDay.isException)
precondition(normalDay.sessions.first?.title == "Legs")

// Diff reports only days whose content changed.
var edited = detailed.days
edited[2].sessions = [] // Wednesday becomes rest
let changes = RoutineDiff.changes(from: detailed.days, to: edited)
precondition(changes.count == 1)
precondition(changes[0].weekday == .wednesday)
precondition(changes[0].after == "Rest")
precondition(RoutineDiff.changes(from: detailed.days, to: detailed.days).isEmpty)

// Edit review warns when the only rest day disappears or volume jumps.
var withRest = detailed.days
withRest[6].sessions = [] // Sunday rest
var noRest = withRest
noRest[6].sessions = [TrainingSession(title: "Swimming", kind: .swimming, swimPlan: SwimPlan(targetMinutes: 30, intensity: .hard))]
precondition(!RoutineChangeReview.warnings(from: withRest, to: noRest).isEmpty)
precondition(RoutineChangeReview.warnings(from: detailed.days, to: detailed.days).isEmpty)

// Conservative double progression.
let bench = detailed.days[0].sessions[0].exercises[0]
let sessionID = detailed.days[0].sessions[0].id

// No history: establish a baseline, never invent a load.
precondition(ProgressionAdvisor.suggest(prescription: bench, history: []).action == .establishBaseline)

// Every set at the top of the range at target effort: increase load.
let topLogs = (1...bench.workingSets).map { setNumber in
    ExerciseSetLog(date: "2026-07-10", sessionID: sessionID, exerciseName: bench.name,
                   setNumber: setNumber, loadKg: 60, reps: bench.repRangeUpper, rir: bench.targetRIR)
}
let increase = ProgressionAdvisor.suggest(prescription: bench, history: topLogs)
precondition(increase.action == .increaseLoad(byKg: 1.5)) // 2.5% of 60 kg
precondition(ProgressionAdvisor.loadIncrement(forLoadKg: 20) == 1.0) // floor at 1 kg

// Mid-range performance: add reps at the same load.
let midLogs = (1...bench.workingSets).map { setNumber in
    ExerciseSetLog(date: "2026-07-10", sessionID: sessionID, exerciseName: bench.name,
                   setNumber: setNumber, loadKg: 60, reps: bench.repRangeLower + 1, rir: bench.targetRIR)
}
precondition(ProgressionAdvisor.suggest(prescription: bench, history: midLogs).action == .addReps)

// Reps under the bottom of the range: hold or reduce.
var underLogs = midLogs
underLogs[0].reps = bench.repRangeLower - 2
precondition(ProgressionAdvisor.suggest(prescription: bench, history: underLogs).action == .holdOrReduce)

// Pain note trumps everything.
var painLogs = topLogs
painLogs[0].painNote = "shoulder twinge"
precondition(ProgressionAdvisor.suggest(prescription: bench, history: painLogs).action == .caution)

// Only the most recent session counts.
let mixedLogs = midLogs + (1...bench.workingSets).map { setNumber in
    ExerciseSetLog(date: "2026-07-12", sessionID: sessionID, exerciseName: bench.name,
                   setNumber: setNumber, loadKg: 60, reps: bench.repRangeUpper, rir: bench.targetRIR)
}
precondition(ProgressionAdvisor.suggest(prescription: bench, history: mixedLogs).action == .increaseLoad(byKg: 1.5))

// Proposals: pending until decided, stale once the base version moves on.
let proposal = RoutineChangeProposal(
    baseVersion: detailed.version,
    proposedDays: edited,
    reasons: ["Recovery has lagged mid-week"],
    expectedBenefit: "Fresher legs sessions",
    recoveryImpact: "One extra rest day"
)
precondition(proposal.status == .pending)
precondition(!proposal.isStale(activeVersion: 2))
precondition(proposal.isStale(activeVersion: 3))

print("BodyCompassCoreCheck passed")
