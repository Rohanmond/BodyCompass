import Foundation
import Security
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

struct AccountAPIClient {
    enum ClientError: LocalizedError {
        case invalidURL
        case invalidResponse
        case server(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: "The BodyCompass server URL is invalid."
            case .invalidResponse: "The server returned an unreadable response."
            case let .server(message): message
            }
        }
    }

    private struct ScheduleRequest: Encodable { let items: [ScheduleItem] }
    private struct MealRequest: Encodable {
        let id: String
        let createdAt: Date
        let notes: String
        let estimates: MealAnalysisBundle
        let accepted: MealAnalysis
    }
    private struct ProgressRequest: Encodable {
        let id: String
        let capturedAt: Date
        let analysis: ProgressAnalysisBundle
        let acceptedRange: BodyFatEstimateRange?
        let wasRejected: Bool
    }
    private struct IdentifierRequest: Encodable { let id: String }
    private struct DeleteRequest: Encodable { let confirmation = "DELETE MY BODYCOMPASS DATA" }
    private struct ErrorResponse: Decodable { let error: String; let detail: String? }

    private var baseURL: URL? {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "BODYCOMPASS_API_BASE_URL") as? String, !configured.isEmpty {
            return URL(string: configured)
        }
        return URL(string: "http://127.0.0.1:8080")
    }

    func saveProfile(_ profile: BodyProfile) async throws {
        _ = try await send(path: "api/profile", method: "PUT", body: profile)
    }

    func saveSchedule(_ items: [ScheduleItem]) async throws {
        _ = try await send(path: "api/schedule", method: "PUT", body: ScheduleRequest(items: items))
    }

    func saveHealthSnapshot(_ snapshot: DailyHealthSnapshot) async throws {
        _ = try await send(path: "api/health-snapshots", method: "POST", body: snapshot)
    }

    func saveMeal(_ meal: LoggedMeal) async throws {
        _ = try await send(path: "api/meals/save", method: "POST", body: MealRequest(
            id: meal.id.uuidString,
            createdAt: meal.createdAt,
            notes: meal.notes,
            estimates: meal.estimates,
            accepted: meal.accepted
        ))
    }

    func deleteMeal(id: UUID) async throws {
        _ = try await send(path: "api/meals", method: "DELETE", body: IdentifierRequest(id: id.uuidString))
    }

    func saveProgressCheckIn(_ checkIn: ProgressCheckIn) async throws {
        _ = try await send(path: "api/progress-check-ins/save", method: "POST", body: ProgressRequest(
            id: checkIn.id.uuidString,
            capturedAt: checkIn.date,
            analysis: checkIn.analysis,
            acceptedRange: checkIn.acceptedRange,
            wasRejected: checkIn.wasRejected
        ))
    }

    func deleteProgressCheckIn(id: UUID) async throws {
        _ = try await send(path: "api/progress-check-ins", method: "DELETE", body: IdentifierRequest(id: id.uuidString))
    }

    func exportData() async throws -> Data {
        try await send(path: "api/data/export", method: "GET", body: Optional<String>.none)
    }

    func deleteAllServerData() async throws {
        _ = try await send(path: "api/data", method: "DELETE", body: DeleteRequest())
    }

    private func send<Body: Encodable>(path: String, method: String, body: Body?) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else { throw ClientError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 120
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }
        if let token = ServerCredentialStore.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let error = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw ClientError.server(error?.detail ?? error?.error ?? "Request failed (HTTP \(http.statusCode)).")
        }
        return data
    }
}

enum ServerCredentialStore {
    private static let service = "com.rohanmondal.bodycompass.server"
    private static let account = "api-token"

    static var token: String? {
        get {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var result: AnyObject?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            SecItemDelete(query as CFDictionary)
            guard let newValue, !newValue.isEmpty, let data = newValue.data(using: .utf8) else { return }
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
    }
}
