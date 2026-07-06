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

print("BodyCompassCoreCheck passed")
