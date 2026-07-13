import Foundation
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

struct MealAPIClient {
    enum ClientError: LocalizedError {
        case invalidURL
        case invalidResponse
        case server(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: "The BodyCompass server URL is invalid."
            case .invalidResponse: "The server returned an unreadable meal result."
            case let .server(message): message
            }
        }
    }

    private struct Request: Encodable {
        let notes: String
        let imageBase64: String
        let imageMimeType: String
        let context: Context
    }

    private struct Context: Encodable {
        let targetProteinGrams: Int
    }

    private struct Response: Decodable {
        let openai: ProviderDTO
        let gemini: ProviderDTO
        let reconciled: AnalysisDTO
    }

    private struct ProviderDTO: Decodable {
        let provider: String
        let mode: String
        let error: String?
        let title: String?
        let caloriesRange: [Int]?
        let proteinGrams: Int?
        let carbsGrams: Int?
        let fatGrams: Int?
        let confidence: Double?
        let likelyMistakes: [String]?
        let recommendation: String?
        let greenSigns: [String]?
        let redFlags: [String]?
        let improvements: [String]?
        let nextAction: String?

        func model() -> MealProviderEstimate {
            MealProviderEstimate(
                provider: provider,
                mode: mode,
                analysis: analysis(),
                error: error
            )
        }

        private func analysis() -> MealAnalysis? {
            guard let title, let caloriesRange, caloriesRange.count == 2,
                  let proteinGrams, let carbsGrams, let fatGrams,
                  let confidence, let likelyMistakes, let recommendation else { return nil }
            return MealAnalysis(
                title: title,
                caloriesRange: min(caloriesRange[0], caloriesRange[1])...max(caloriesRange[0], caloriesRange[1]),
                proteinGrams: proteinGrams,
                carbsGrams: carbsGrams,
                fatGrams: fatGrams,
                confidence: confidence,
                likelyMistakes: likelyMistakes,
                recommendation: recommendation,
                greenSigns: greenSigns,
                redFlags: redFlags,
                improvements: improvements,
                nextAction: nextAction
            )
        }
    }

    private struct AnalysisDTO: Decodable {
        let title: String
        let caloriesRange: [Int]
        let proteinGrams: Int
        let carbsGrams: Int
        let fatGrams: Int
        let confidence: Double
        let likelyMistakes: [String]
        let recommendation: String
        let greenSigns: [String]?
        let redFlags: [String]?
        let improvements: [String]?
        let nextAction: String?

        func model() throws -> MealAnalysis {
            guard caloriesRange.count == 2 else { throw ClientError.invalidResponse }
            return MealAnalysis(
                title: title,
                caloriesRange: min(caloriesRange[0], caloriesRange[1])...max(caloriesRange[0], caloriesRange[1]),
                proteinGrams: proteinGrams,
                carbsGrams: carbsGrams,
                fatGrams: fatGrams,
                confidence: confidence,
                likelyMistakes: likelyMistakes,
                recommendation: recommendation,
                greenSigns: greenSigns,
                redFlags: redFlags,
                improvements: improvements,
                nextAction: nextAction
            )
        }
    }

    private struct ErrorResponse: Decodable {
        let error: String
        let detail: String?
    }

    var baseURL: URL? {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "BODYCOMPASS_API_BASE_URL") as? String,
           !configured.isEmpty {
            return URL(string: configured)
        }
        return URL(string: "http://127.0.0.1:8080")
    }

    func analyze(imageData: Data, notes: String, targetProteinGrams: Int) async throws -> MealAnalysisBundle {
        guard let url = baseURL?.appendingPathComponent("api/meals/analyze") else {
            throw ClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = ServerCredentialStore.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 90
        request.httpBody = try JSONEncoder().encode(
            Request(
                notes: notes,
                imageBase64: imageData.base64EncodedString(),
                imageMimeType: "image/jpeg",
                context: Context(targetProteinGrams: targetProteinGrams)
            )
        )

        let (data, urlResponse) = try await URLSession.shared.data(for: request)
        guard let httpResponse = urlResponse as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data))
                .map { $0.detail ?? $0.error } ?? "Meal analysis failed (HTTP \(httpResponse.statusCode))."
            throw ClientError.server(message)
        }

        let response = try JSONDecoder().decode(Response.self, from: data)
        return MealAnalysisBundle(
            openAI: response.openai.model(),
            gemini: response.gemini.model(),
            reconciled: try response.reconciled.model()
        )
    }
}
