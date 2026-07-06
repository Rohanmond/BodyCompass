import Foundation

public struct DailyHealthSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: String { date }
    public var date: String
    public var weightKg: Double?
    public var bodyFatPercentage: Double?
    public var steps: Int
    public var activeEnergyKcal: Double
    public var sleepHours: Double?
    public var restingHeartRate: Double?
    public var workoutMinutes: Int

    public init(
        date: String,
        weightKg: Double? = nil,
        bodyFatPercentage: Double? = nil,
        steps: Int = 0,
        activeEnergyKcal: Double = 0,
        sleepHours: Double? = nil,
        restingHeartRate: Double? = nil,
        workoutMinutes: Int = 0
    ) {
        self.date = date
        self.weightKg = weightKg
        self.bodyFatPercentage = bodyFatPercentage
        self.steps = steps
        self.activeEnergyKcal = activeEnergyKcal
        self.sleepHours = sleepHours
        self.restingHeartRate = restingHeartRate
        self.workoutMinutes = workoutMinutes
    }
}
