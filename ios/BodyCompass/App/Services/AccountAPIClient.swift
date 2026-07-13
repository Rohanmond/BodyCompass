import Foundation
import Security
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

struct AuthenticatedUser: Codable, Equatable, Identifiable {
    let id: String
    let email: String
    let displayName: String
}

private struct AuthSessionResponse: Decodable {
    let token: String
    let expiresAt: String
    let user: AuthenticatedUser
}

private struct CurrentAccountResponse: Decodable {
    let user: AuthenticatedUser
}

struct EmailCodeChallenge: Decodable, Equatable {
    let challengeId: String
    let expiresAt: String
    let message: String
    let developmentCode: String?
}

struct AuthenticationAPIClient {
    private struct EmailCodeRequest: Encodable { let email: String }
    private struct EmailCodeVerification: Encodable {
        let challengeId: String
        let code: String
    }
    private struct ErrorResponse: Decodable { let error: String }

    func requestEmailCode(email: String) async throws -> EmailCodeChallenge {
        try await send(
            path: "api/auth/email/request",
            method: "POST",
            body: EmailCodeRequest(email: email),
            authorized: false
        )
    }

    func verifyEmailCode(challengeId: String, code: String) async throws -> AuthenticatedUser {
        let response: AuthSessionResponse = try await send(
            path: "api/auth/email/verify",
            method: "POST",
            body: EmailCodeVerification(challengeId: challengeId, code: code),
            authorized: false
        )
        SessionCredentialStore.save(token: response.token, user: response.user)
        return response.user
    }

    func currentUser() async throws -> AuthenticatedUser {
        let response: CurrentAccountResponse = try await send(
            path: "api/auth/me",
            method: "GET",
            body: Optional<String>.none,
            authorized: true
        )
        SessionCredentialStore.user = response.user
        return response.user
    }

    func logout() async {
        let _: EmptyResponse? = try? await send(
            path: "api/auth/logout",
            method: "POST",
            body: Optional<String>.none,
            authorized: true
        )
    }

    private struct EmptyResponse: Decodable {}

    private func send<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body?,
        authorized: Bool
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: BodyCompassAPI.baseURL)?.absoluteURL else {
            throw AccountAPIClient.ClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        if authorized { BodyCompassAPI.authorize(&request) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AccountAPIClient.ClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error
            throw AccountAPIClient.ClientError.server(message ?? "Account request failed (HTTP \(http.statusCode)).")
        }
        if Response.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! Response
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

@MainActor
final class AuthenticationStore: ObservableObject {
    enum State: Equatable {
        case checking
        case signedOut
        case signedIn(AuthenticatedUser)
    }

    @Published private(set) var state: State = .checking
    private let client = AuthenticationAPIClient()

    init() {
        SessionCredentialStore.removeLegacyServerToken()
        Task { await restoreSession() }
    }

    var user: AuthenticatedUser? {
        guard case let .signedIn(user) = state else { return nil }
        return user
    }

    func requestEmailCode(email: String) async throws -> EmailCodeChallenge {
        try await client.requestEmailCode(email: email)
    }

    func verifyEmailCode(challengeId: String, code: String) async throws {
        let user = try await client.verifyEmailCode(challengeId: challengeId, code: code)
        state = .signedIn(user)
    }

    func signOut() async {
        await client.logout()
        SessionCredentialStore.clear()
        state = .signedOut
    }

    func accountWasDeleted() {
        SessionCredentialStore.clear()
        state = .signedOut
    }

    private func restoreSession() async {
        guard SessionCredentialStore.token != nil else {
            state = .signedOut
            return
        }
        do {
            state = .signedIn(try await client.currentUser())
        } catch {
            SessionCredentialStore.clear()
            state = .signedOut
        }
    }
}

enum BodyCompassAPI {
    static var baseURL: URL? {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "BODYCOMPASS_API_BASE_URL") as? String,
           !configured.isEmpty {
            return URL(string: configured)
        }
        return URL(string: "http://127.0.0.1:8080")
    }

    static func authorize(_ request: inout URLRequest) {
        guard let token = SessionCredentialStore.token, !token.isEmpty else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}

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
        guard let url = URL(string: path, relativeTo: BodyCompassAPI.baseURL)?.absoluteURL else { throw ClientError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 120
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }
        BodyCompassAPI.authorize(&request)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let error = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw ClientError.server(error?.detail ?? error?.error ?? "Request failed (HTTP \(http.statusCode)).")
        }
        return data
    }
}

enum SessionCredentialStore {
    private static let service = "com.rohanmondal.bodycompass.server"
    private static let tokenAccount = "account-session"
    private static let userAccount = "account-user"

    static var token: String? {
        get { read(account: tokenAccount).flatMap { String(data: $0, encoding: .utf8) } }
        set { write(newValue?.data(using: .utf8), account: tokenAccount) }
    }

    static var user: AuthenticatedUser? {
        get { read(account: userAccount).flatMap { try? JSONDecoder().decode(AuthenticatedUser.self, from: $0) } }
        set { write(newValue.flatMap { try? JSONEncoder().encode($0) }, account: userAccount) }
    }

    static func save(token: String, user: AuthenticatedUser) {
        self.token = token
        self.user = user
    }

    static func clear() {
        token = nil
        user = nil
    }

    static func removeLegacyServerToken() {
        delete(account: "api-token")
    }

    private static func read(account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func write(_ data: Data?, account: String) {
        delete(account: account)
        guard let data else { return }
        var item = baseQuery(account: account)
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private static func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
