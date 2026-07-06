import Foundation

public struct BodyProfile: Codable, Equatable, Sendable {
    public var name: String
    public var age: Int
    public var heightCm: Double
    public var weightKg: Double
    public var bodyFatPercentage: Double
    public var targetBodyFatPercentage: Double
    public var weeklyWeightTrendKg: Double?
    public var adherenceScore: Double

    public init(
        name: String,
        age: Int,
        heightCm: Double,
        weightKg: Double,
        bodyFatPercentage: Double,
        targetBodyFatPercentage: Double = 12,
        weeklyWeightTrendKg: Double? = nil,
        adherenceScore: Double = 0.75
    ) {
        self.name = name
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.bodyFatPercentage = bodyFatPercentage
        self.targetBodyFatPercentage = targetBodyFatPercentage
        self.weeklyWeightTrendKg = weeklyWeightTrendKg
        self.adherenceScore = adherenceScore
    }
}
