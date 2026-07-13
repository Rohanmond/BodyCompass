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

print("BodyCompassCoreCheck passed")
