import Foundation

public struct MealAnalysis: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var caloriesRange: ClosedRange<Int>
    public var proteinGrams: Int
    public var carbsGrams: Int
    public var fatGrams: Int
    public var confidence: Double
    public var likelyMistakes: [String]
    public var recommendation: String

    public init(
        id: UUID = UUID(),
        title: String,
        caloriesRange: ClosedRange<Int>,
        proteinGrams: Int,
        carbsGrams: Int,
        fatGrams: Int,
        confidence: Double,
        likelyMistakes: [String],
        recommendation: String
    ) {
        self.id = id
        self.title = title
        self.caloriesRange = caloriesRange
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.confidence = confidence
        self.likelyMistakes = likelyMistakes
        self.recommendation = recommendation
    }
}
