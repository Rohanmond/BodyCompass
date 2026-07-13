import Foundation
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

struct CoachRoutineChange: Codable, Equatable {
    let weekday: String
    let target: String
    let sessionTitle: String
    let exerciseName: String
    let action: String
    let targetMinutes: Int
    let intensity: String
    let workingSets: Int
    let repRangeLower: Int
    let repRangeUpper: Int
    let targetRIR: Int
    let restSeconds: Int
}

struct CoachRoutineInstruction: Codable, Equatable {
    let summary: String
    let reasons: [String]
    let expectedBenefit: String
    let recoveryImpact: String
    let changes: [CoachRoutineChange]
}

struct CoachProviderAnswer: Codable, Equatable {
    let provider: String
    let mode: String
    let answer: String?
    let nextAction: String?
    let safetyNotice: String?
    let routineProposal: CoachRoutineInstruction?
    let error: String?
}

struct CoachCombinedAnswer: Codable, Equatable {
    let answer: String
    let nextAction: String
    let safetyNotice: String
    let routineProposal: CoachRoutineInstruction?
    let confidence: String
}

struct CoachAnswerBundle: Codable, Equatable {
    let combined: CoachCombinedAnswer
    let openai: CoachProviderAnswer
    let gemini: CoachProviderAnswer
}

struct CoachExchange: Codable, Equatable, Identifiable {
    let id: UUID
    let createdAt: Date
    let question: String
    let response: CoachAnswerBundle

    init(id: UUID = UUID(), createdAt: Date = Date(), question: String, response: CoachAnswerBundle) {
        self.id = id
        self.createdAt = createdAt
        self.question = question
        self.response = response
    }
}

@MainActor
final class CoachHistoryStore: ObservableObject {
    private static let storageKey = "bodycompass.coach.exchanges"
    private let defaults: UserDefaults

    @Published private(set) var exchanges: [CoachExchange]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode([CoachExchange].self, from: data) {
            exchanges = stored
        } else {
            exchanges = []
        }
    }

    func append(question: String, response: CoachAnswerBundle) {
        exchanges.append(CoachExchange(question: question, response: response))
        exchanges = Array(exchanges.suffix(50))
        persist()
    }

    func clear() {
        exchanges = []
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(exchanges) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}

struct CoachAPIClient {
    enum ClientError: LocalizedError {
        case invalidURL
        case invalidResponse
        case server(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: "The BodyCompass server URL is invalid."
            case .invalidResponse: "The server returned an unreadable Coach answer."
            case let .server(message): message
            }
        }
    }

    private struct Request: Encodable {
        let message: String
        let context: Context
        let history: [HistoryItem]
    }

    private struct Context: Encodable {
        let profile: BodyProfile
        let today: DailyHealthSnapshot
        let recentMeals: [MealAnalysis]
        let schedule: [ScheduleItem]
        let goal: GoalProjection
        let dailyAdherence: Double
        let weeklyAdherence: Double?
        let training: TrainingContext
    }

    private struct TrainingContext: Encodable {
        let setupComplete: Bool
        let setup: TrainingSetup?
        let activeRoutine: TrainingRoutine
        let recentStrengthLogs: [ExerciseSetLog]
        let recentSwimLogs: [SwimSessionLog]
    }

    private struct HistoryItem: Encodable {
        let question: String
        let answer: String
    }

    private struct ErrorResponse: Decodable {
        let error: String
        let detail: String?
    }

    private var baseURL: URL? {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "BODYCOMPASS_API_BASE_URL") as? String,
           !configured.isEmpty {
            return URL(string: configured)
        }
        return URL(string: "http://127.0.0.1:8080")
    }

    @MainActor
    func ask(
        message: String,
        app: AppStore,
        training: TrainingStore,
        exchanges: [CoachExchange]
    ) async throws -> CoachAnswerBundle {
        guard let url = baseURL?.appendingPathComponent("api/chat") else {
            throw ClientError.invalidURL
        }
        let context = Context(
            profile: app.profile,
            today: app.today,
            recentMeals: Array(app.meals.prefix(10)),
            schedule: Array(app.schedule.prefix(20)),
            goal: app.projection,
            dailyAdherence: app.dailyAdherence.score,
            weeklyAdherence: app.weeklyAdherence,
            training: TrainingContext(
                setupComplete: !training.needsSetup,
                setup: training.setup,
                activeRoutine: training.activeRoutine,
                recentStrengthLogs: Array(training.strengthLogs.suffix(40)),
                recentSwimLogs: Array(training.swimLogs.suffix(20))
            )
        )
        let history = exchanges.suffix(8).map {
            HistoryItem(question: $0.question, answer: $0.response.combined.answer)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = ServerCredentialStore.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 90
        request.httpBody = try JSONEncoder().encode(
            Request(message: message, context: context, history: history)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let serverError = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw ClientError.server(
                serverError?.detail ?? serverError?.error ?? "Coach request failed (HTTP \(httpResponse.statusCode))."
            )
        }
        do {
            return try JSONDecoder().decode(CoachAnswerBundle.self, from: data)
        } catch {
            throw ClientError.invalidResponse
        }
    }
}
