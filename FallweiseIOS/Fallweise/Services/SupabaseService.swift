import Foundation

actor SupabaseService {
    static let shared = SupabaseService()
    private let baseURL = URL(string: "https://xysuwcwgcbbnbpmfdwor.supabase.co")!
    private let publishableKey = "sb_publishable_IDqV0lx_vx3OYR3RrJsA9g_rwuRDVV0"
    private let tokenKey = "fallweise.supabase.session"
    private var session: AuthSession?

    struct AuthSession: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Date
        let userID: String
    }

    func accessToken() async throws -> String {
        if session == nil { session = loadSession() }
        if let session, session.expiresAt.timeIntervalSinceNow > 60 { return session.accessToken }
        if let session { return try await refresh(session.refreshToken).accessToken }
        return try await signInAnonymously().accessToken
    }

    func saveLesson(_ progress: SavedLesson) async throws {
        let token = try await accessToken()
        guard let userID = session?.userID else { throw URLError(.userAuthenticationRequired) }
        var request = URLRequest(url: baseURL.appending(path: "/rest/v1/lesson_progress"))
        request.httpMethod = "POST"
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder.api.encode([LessonPayload(progress: progress, userID: userID)])
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else { throw URLError(.badServerResponse) }
    }

    func fetchVoiceLessons() async throws -> [SavedLesson] {
        let token = try await accessToken()
        var components = URLComponents(url: baseURL.appending(path: "/rest/v1/lesson_progress"), resolvingAgainstBaseURL: false)!
        components.queryItems = [.init(name: "select", value: "*"), .init(name: "lesson_id", value: "like.voice-tutor:%")]
        var request = URLRequest(url: components.url!)
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder.api.decode([SavedLesson].self, from: data)
    }

    private func signInAnonymously() async throws -> AuthSession {
        var request = URLRequest(url: baseURL.appending(path: "/auth/v1/signup"))
        request.httpMethod = "POST"
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        return try await auth(request)
    }

    private func refresh(_ refreshToken: String) async throws -> AuthSession {
        var request = URLRequest(url: baseURL.appending(path: "/auth/v1/token?grant_type=refresh_token"))
        request.httpMethod = "POST"
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])
        return try await auth(request)
    }

    private func auth(_ request: URLRequest) async throws -> AuthSession {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else { throw URLError(.userAuthenticationRequired) }
        let payload = try JSONDecoder().decode(AuthPayload.self, from: data)
        let value = AuthSession(accessToken: payload.accessToken, refreshToken: payload.refreshToken, expiresAt: Date().addingTimeInterval(TimeInterval(payload.expiresIn)), userID: payload.user.id)
        session = value
        UserDefaults.standard.set(try JSONEncoder().encode(value), forKey: tokenKey)
        return value
    }

    private func loadSession() -> AuthSession? {
        guard let data = UserDefaults.standard.data(forKey: tokenKey) else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }
}

private struct LessonPayload: Encodable {
    let userID: String
    let lessonID: String
    let status: String
    let mastery: Double
    let currentStep: Int
    let totalSteps: Int
    let lastActivityAt: Date
    let completedAt: Date?

    init(progress: SavedLesson, userID: String) {
        self.userID = userID; lessonID = progress.lessonID; status = progress.status; mastery = progress.mastery
        currentStep = progress.currentStep; totalSteps = progress.totalSteps; lastActivityAt = progress.lastActivityAt; completedAt = progress.completedAt
    }
}

private struct AuthPayload: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: User
    struct User: Decodable { let id: String }
    enum CodingKeys: String, CodingKey { case accessToken = "access_token", refreshToken = "refresh_token", expiresIn = "expires_in", user }
}

extension JSONEncoder {
    static let api: JSONEncoder = { let value = JSONEncoder(); value.dateEncodingStrategy = .iso8601; value.keyEncodingStrategy = .convertToSnakeCase; return value }()
}
extension JSONDecoder {
    static let api: JSONDecoder = { let value = JSONDecoder(); value.dateDecodingStrategy = .iso8601; value.keyDecodingStrategy = .convertFromSnakeCase; return value }()
}
