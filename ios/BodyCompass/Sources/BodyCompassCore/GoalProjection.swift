import Foundation

public struct GoalProjection: Codable, Equatable, Sendable {
    public let currentFatMassKg: Double
    public let currentLeanMassKg: Double
    public let targetWeightKg: Double
    public let fatToLoseKg: Double
    public let optimumWeeks: Int
    public let aggressiveWeeks: Int
    public let conservativeWeeks: Int
    public let weeklyLossTargetKg: Double
    public let dailyDeficitKcal: Int
    public let status: ProjectionStatus
    public let explanation: String
}

public enum ProjectionStatus: String, Codable, Equatable, Sendable {
    case alreadyAtGoal
    case onTrack
    case needsBetterAdherence
    case unsafePace
}

public enum GoalProjectionError: Error, Equatable {
    case invalidWeight
    case invalidBodyFat
    case targetNotLowerThanCurrent
}

public struct GoalProjectionCalculator: Sendable {
    public init() {}

    public func project(profile: BodyProfile) throws -> GoalProjection {
        guard profile.weightKg > 0 else { throw GoalProjectionError.invalidWeight }
        guard profile.bodyFatPercentage > 0, profile.bodyFatPercentage < 70 else {
            throw GoalProjectionError.invalidBodyFat
        }

        if profile.bodyFatPercentage <= profile.targetBodyFatPercentage {
            let fatMass = profile.weightKg * profile.bodyFatPercentage / 100
            let leanMass = profile.weightKg - fatMass
            return GoalProjection(
                currentFatMassKg: fatMass,
                currentLeanMassKg: leanMass,
                targetWeightKg: profile.weightKg,
                fatToLoseKg: 0,
                optimumWeeks: 0,
                aggressiveWeeks: 0,
                conservativeWeeks: 0,
                weeklyLossTargetKg: 0,
                dailyDeficitKcal: 0,
                status: .alreadyAtGoal,
                explanation: "You are already at or below the target body-fat percentage. Focus on maintenance, strength, and recovery."
            )
        }

        guard profile.targetBodyFatPercentage > 3, profile.targetBodyFatPercentage < profile.bodyFatPercentage else {
            throw GoalProjectionError.targetNotLowerThanCurrent
        }

        let currentFatMass = profile.weightKg * profile.bodyFatPercentage / 100
        let currentLeanMass = profile.weightKg - currentFatMass
        let targetWeight = currentLeanMass / (1 - profile.targetBodyFatPercentage / 100)
        let fatToLose = max(0, profile.weightKg - targetWeight)

        let baseWeeklyLoss = min(max(profile.weightKg * 0.0075, 0.35), 0.85)
        let adherence = min(max(profile.adherenceScore, 0.35), 1)
        let observedTrend = profile.weeklyWeightTrendKg.map { abs($0) }
        let weeklyTarget = max(0.25, min(observedTrend ?? baseWeeklyLoss, baseWeeklyLoss) * adherence)

        let optimumWeeks = Int(ceil(fatToLose / weeklyTarget))
        let aggressiveWeeks = Int(ceil(fatToLose / min(profile.weightKg * 0.01, 1.0)))
        let conservativeWeeks = Int(ceil(fatToLose / max(profile.weightKg * 0.005, 0.25)))
        let dailyDeficit = Int((weeklyTarget * 7700 / 7).rounded())

        let status: ProjectionStatus
        if dailyDeficit > 1100 {
            status = .unsafePace
        } else if adherence < 0.65 {
            status = .needsBetterAdherence
        } else {
            status = .onTrack
        }

        return GoalProjection(
            currentFatMassKg: currentFatMass,
            currentLeanMassKg: currentLeanMass,
            targetWeightKg: targetWeight,
            fatToLoseKg: fatToLose,
            optimumWeeks: optimumWeeks,
            aggressiveWeeks: aggressiveWeeks,
            conservativeWeeks: conservativeWeeks,
            weeklyLossTargetKg: weeklyTarget,
            dailyDeficitKcal: dailyDeficit,
            status: status,
            explanation: "Projection assumes lean mass is mostly preserved through protein, resistance training, sleep, and a moderate calorie deficit."
        )
    }
}
