import Foundation

enum ProgressPose: String, Codable, CaseIterable, Identifiable {
    case front
    case side
    case back

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .front: "person.fill"
        case .side: "person.crop.rectangle"
        case .back: "person.fill"
        }
    }
}

struct BodyFatEstimateRange: Codable, Equatable {
    var lower: Double
    var upper: Double

    var label: String { "\(lower.formatted(.number.precision(.fractionLength(0...1))))-\(upper.formatted(.number.precision(.fractionLength(0...1))))%" }
}

struct ProgressAnalysis: Codable, Equatable {
    var bodyFatRange: BodyFatEstimateRange
    var confidence: Double
    var imageQuality: String
    var visibleChanges: [String]
    var limitations: [String]
    var suggestions: [String]
    var nextWeekAction: String
}

struct ProgressProviderEstimate: Codable, Equatable {
    var provider: String
    var mode: String
    var analysis: ProgressAnalysis?
    var error: String?
}

struct ProgressAnalysisBundle: Codable, Equatable {
    var openAI: ProgressProviderEstimate
    var gemini: ProgressProviderEstimate
    var reconciled: ProgressAnalysis
}

struct ProgressPhotoReference: Codable, Equatable {
    var pose: ProgressPose
    var filename: String
}

struct ProgressCheckIn: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var photos: [ProgressPhotoReference]
    var analysis: ProgressAnalysisBundle
    var acceptedRange: BodyFatEstimateRange?
    var wasRejected: Bool
}

@MainActor
final class ProgressCheckInStore: ObservableObject {
    private let defaults: UserDefaults
    private let storage = ProgressPhotoStore()
    private let accountAPI = AccountAPIClient()
    private let key = "bodycompass.progressCheckIns"

    @Published private(set) var checkIns: [ProgressCheckIn] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([ProgressCheckIn].self, from: data) {
            checkIns = saved.sorted { $0.date > $1.date }
        }
        Task { await syncAll() }
    }

    var latest: ProgressCheckIn? { checkIns.first }

    func save(images: [ProgressPose: Data], analysis: ProgressAnalysisBundle, acceptedRange: BodyFatEstimateRange?, rejected: Bool) throws {
        let id = UUID()
        var references: [ProgressPhotoReference] = []
        do {
            for pose in ProgressPose.allCases {
                guard let data = images[pose] else { continue }
                references.append(ProgressPhotoReference(pose: pose, filename: try storage.save(data, id: id, pose: pose)))
            }
        } catch {
            references.forEach { storage.delete($0.filename) }
            throw error
        }
        let checkIn = ProgressCheckIn(
            id: id,
            date: Date(),
            photos: references,
            analysis: analysis,
            acceptedRange: acceptedRange,
            wasRejected: rejected
        )
        checkIns.insert(checkIn, at: 0)
        while checkIns.count > 52 {
            delete(checkIns[checkIns.count - 1])
        }
        persist()
        Task { try? await accountAPI.saveProgressCheckIn(checkIn, images: images) }
    }

    func update(_ checkIn: ProgressCheckIn, acceptedRange: BodyFatEstimateRange?, rejected: Bool) {
        guard let index = checkIns.firstIndex(where: { $0.id == checkIn.id }) else { return }
        checkIns[index].acceptedRange = acceptedRange
        checkIns[index].wasRejected = rejected
        persist()
        let updated = checkIns[index]
        let images = imageDictionary(for: updated)
        Task { try? await accountAPI.saveProgressCheckIn(updated, images: images) }
    }

    func delete(_ checkIn: ProgressCheckIn) {
        checkIn.photos.forEach { storage.delete($0.filename) }
        checkIns.removeAll { $0.id == checkIn.id }
        persist()
        Task { try? await accountAPI.deleteProgressCheckIn(id: checkIn.id) }
    }

    func deleteAllLocalData() {
        checkIns.flatMap(\.photos).forEach { storage.delete($0.filename) }
        checkIns = []
        defaults.removeObject(forKey: key)
    }

    func syncAll() async {
        for checkIn in checkIns {
            try? await accountAPI.saveProgressCheckIn(checkIn, images: imageDictionary(for: checkIn))
        }
    }

    func imageData(for checkIn: ProgressCheckIn, pose: ProgressPose) -> Data? {
        guard let filename = checkIn.photos.first(where: { $0.pose == pose })?.filename else { return nil }
        return storage.data(for: filename)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(checkIns) { defaults.set(data, forKey: key) }
    }

    private func imageDictionary(for checkIn: ProgressCheckIn) -> [ProgressPose: Data] {
        Dictionary(uniqueKeysWithValues: ProgressPose.allCases.compactMap { pose in
            imageData(for: checkIn, pose: pose).map { (pose, $0) }
        })
    }
}

private struct ProgressPhotoStore {
    private var directory: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("BodyCompass/ProgressPhotos", isDirectory: true)
    }

    func save(_ data: Data, id: UUID, pose: ProgressPose) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "\(id.uuidString)-\(pose.rawValue).jpg"
        let url = directory.appendingPathComponent(filename)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return filename
    }

    func data(for filename: String) -> Data? { try? Data(contentsOf: directory.appendingPathComponent(filename)) }
    func delete(_ filename: String) { try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename)) }
}

struct ProgressAPIClient {
    enum ClientError: LocalizedError {
        case invalidURL
        case invalidResponse
        case server(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: "The BodyCompass server URL is invalid."
            case .invalidResponse: "The server returned an unreadable progress result."
            case let .server(message): message
            }
        }
    }

    private struct Photo: Encodable {
        let pose: String
        let imageBase64: String
        let imageMimeType = "image/jpeg"
    }
    private struct Confirmations: Encodable {
        let morning = true
        let consistentLighting = true
        let fullBody = true
    }
    private struct Context: Encodable {
        let currentWeightKg: Double
        let currentBodyFatPercentage: Double
        let recentHealth: [HealthContext]
        let previousAcceptedRange: BodyFatEstimateRange?
    }
    private struct HealthContext: Encodable {
        let date: String
        let weightKg: Double?
        let bodyFatPercentage: Double?
        let steps: Int
        let sleepHours: Double?
    }
    private struct Request: Encodable {
        let currentPhotos: [Photo]
        let previousPhotos: [Photo]
        let confirmations: Confirmations
        let context: Context
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
        let bodyFatRange: [Double]?
        let confidence: Double?
        let imageQuality: String?
        let visibleChanges: [String]?
        let limitations: [String]?
        let suggestions: [String]?
        let nextWeekAction: String?

        func model() -> ProgressProviderEstimate {
            ProgressProviderEstimate(provider: provider, mode: mode, analysis: try? analysis(), error: error)
        }
        private func analysis() throws -> ProgressAnalysis {
            guard let bodyFatRange, bodyFatRange.count == 2, let confidence, let imageQuality,
                  let visibleChanges, let limitations, let suggestions, let nextWeekAction else {
                throw ClientError.invalidResponse
            }
            return ProgressAnalysis(
                bodyFatRange: BodyFatEstimateRange(lower: min(bodyFatRange[0], bodyFatRange[1]), upper: max(bodyFatRange[0], bodyFatRange[1])),
                confidence: confidence,
                imageQuality: imageQuality,
                visibleChanges: visibleChanges,
                limitations: limitations,
                suggestions: suggestions,
                nextWeekAction: nextWeekAction
            )
        }
    }
    private struct AnalysisDTO: Decodable {
        let bodyFatRange: [Double]
        let confidence: Double
        let imageQuality: String
        let visibleChanges: [String]
        let limitations: [String]
        let suggestions: [String]
        let nextWeekAction: String

        func model() throws -> ProgressAnalysis {
            guard bodyFatRange.count == 2 else { throw ClientError.invalidResponse }
            return ProgressAnalysis(
                bodyFatRange: BodyFatEstimateRange(lower: min(bodyFatRange[0], bodyFatRange[1]), upper: max(bodyFatRange[0], bodyFatRange[1])),
                confidence: confidence,
                imageQuality: imageQuality,
                visibleChanges: visibleChanges,
                limitations: limitations,
                suggestions: suggestions,
                nextWeekAction: nextWeekAction
            )
        }
    }
    private struct ErrorResponse: Decodable { let error: String; let detail: String? }

    private var baseURL: URL? {
        if let value = Bundle.main.object(forInfoDictionaryKey: "BODYCOMPASS_API_BASE_URL") as? String, !value.isEmpty {
            return URL(string: value)
        }
        return URL(string: "http://127.0.0.1:8080")
    }

    @MainActor
    func analyze(current: [ProgressPose: Data], previous: [ProgressPose: Data], app: AppStore, previousRange: BodyFatEstimateRange?) async throws -> ProgressAnalysisBundle {
        guard let url = baseURL?.appendingPathComponent("api/progress-check-ins/analyze") else { throw ClientError.invalidURL }
        let currentPhotos = ProgressPose.allCases.compactMap { pose in
            current[pose].map { Photo(pose: pose.rawValue, imageBase64: $0.base64EncodedString()) }
        }
        let previousPhotos = ProgressPose.allCases.compactMap { pose in
            previous[pose].map { Photo(pose: pose.rawValue, imageBase64: $0.base64EncodedString()) }
        }
        let health = app.healthHistory.sorted { $0.date > $1.date }.prefix(14).map {
            HealthContext(date: $0.date, weightKg: $0.weightKg, bodyFatPercentage: $0.bodyFatPercentage, steps: $0.steps, sleepHours: $0.sleepHours)
        }
        let payload = Request(
            currentPhotos: currentPhotos,
            previousPhotos: previousPhotos,
            confirmations: Confirmations(),
            context: Context(
                currentWeightKg: app.today.weightKg ?? app.profile.weightKg,
                currentBodyFatPercentage: app.today.bodyFatPercentage ?? app.profile.bodyFatPercentage,
                recentHealth: health,
                previousAcceptedRange: previousRange
            )
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = ServerCredentialStore.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 120
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data)).map { $0.detail ?? $0.error }
            throw ClientError.server(message ?? "Progress analysis failed (HTTP \(http.statusCode)).")
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return ProgressAnalysisBundle(openAI: decoded.openai.model(), gemini: decoded.gemini.model(), reconciled: try decoded.reconciled.model())
    }
}
