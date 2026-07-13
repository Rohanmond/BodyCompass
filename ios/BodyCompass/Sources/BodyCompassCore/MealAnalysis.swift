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

public struct MealProviderEstimate: Codable, Equatable, Sendable {
    public var provider: String
    public var mode: String
    public var analysis: MealAnalysis?
    public var error: String?

    public init(provider: String, mode: String, analysis: MealAnalysis? = nil, error: String? = nil) {
        self.provider = provider
        self.mode = mode
        self.analysis = analysis
        self.error = error
    }
}

public struct MealAnalysisBundle: Codable, Equatable, Sendable {
    public var openAI: MealProviderEstimate
    public var gemini: MealProviderEstimate
    public var reconciled: MealAnalysis

    public init(openAI: MealProviderEstimate, gemini: MealProviderEstimate, reconciled: MealAnalysis) {
        self.openAI = openAI
        self.gemini = gemini
        self.reconciled = reconciled
    }
}

public struct LoggedMeal: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var notes: String
    public var imageFilename: String?
    public var estimates: MealAnalysisBundle
    public var accepted: MealAnalysis

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        notes: String,
        imageFilename: String? = nil,
        estimates: MealAnalysisBundle,
        accepted: MealAnalysis
    ) {
        self.id = id
        self.createdAt = createdAt
        self.notes = notes
        self.imageFilename = imageFilename
        self.estimates = estimates
        self.accepted = accepted
    }
}
