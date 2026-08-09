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
        if let session {
            do { return try await refresh(session.refreshToken).accessToken }
            catch { clearSession() }
        }
        return try await signInAnonymously().accessToken
    }

    /// Renews credentials after an API has rejected a cached access token.
    /// If the refresh token is no longer accepted, start a new anonymous session.
    func renewedAccessToken() async throws -> String {
        if session == nil { session = loadSession() }
        if let session {
            do { return try await refresh(session.refreshToken).accessToken }
            catch { clearSession() }
        }
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

    func saveLearning(memory: MemoryRecord, outcome: ReviewOutcome) async throws {
        let token = try await accessToken()
        guard let userID = session?.userID else { throw URLError(.userAuthenticationRequired) }
        async let review: Void = upsert(path: "/rest/v1/review_items", payload: [ReviewPayload(memory: memory, userID: userID)], token: token)
        async let mastery: Void = upsert(path: "/rest/v1/skill_mastery", payload: [SkillPayload(memory: memory, userID: userID)], token: token)
        async let attempt: Void = insert(path: "/rest/v1/exercise_attempts", payload: [AttemptPayload(outcome: outcome, userID: userID)], token: token)
        _ = try await (review, mastery, attempt)
    }

    func fetchMemories() async throws -> [MemoryRecord] {
        let token = try await accessToken()
        var components = URLComponents(url: baseURL.appending(path: "/rest/v1/review_items"), resolvingAgainstBaseURL: false)!
        components.queryItems = [.init(name: "select", value: "*")]
        var request = URLRequest(url: components.url!)
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder.api.decode([ReviewRow].self, from: data).compactMap(\.memory)
    }

    private func upsert<T: Encodable>(path: String, payload: T, token: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder.api.encode(payload)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else { throw URLError(.badServerResponse) }
    }

    private func insert<T: Encodable>(path: String, payload: T, token: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.api.encode(payload)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else { throw URLError(.badServerResponse) }
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

    private func clearSession() {
        session = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
}

private struct ReviewPayload: Encodable {
    let userID: String
    let itemID: String
    let skillID: String
    let itemType: String
    let intervalDays: Int
    let easeFactor: Double
    let repetitions: Int
    let lapses: Int
    let dueAt: Date
    let lastReviewedAt: Date?
    let suspended = false

    init(memory: MemoryRecord, userID: String) {
        self.userID = userID; itemID = memory.itemID; skillID = memory.skillID; itemType = memory.kind.rawValue
        intervalDays = Int(memory.stabilityDays.rounded()); easeFactor = min(3.5, max(1.3, 3.6 - memory.difficulty * 0.23))
        repetitions = memory.repetitions; lapses = memory.lapses; dueAt = memory.dueAt; lastReviewedAt = memory.lastReviewedAt
    }
}

private struct SkillPayload: Encodable {
    let userID: String
    let skillID: String
    let level: String
    let domain: String
    let mastery: Double
    let attempts: Int
    let correctAttempts: Int
    let currentStreak: Int
    let lastPractisedAt: Date?

    init(memory: MemoryRecord, userID: String) {
        self.userID = userID; skillID = memory.skillID; level = memory.level.rawValue; domain = memory.kind.domain
        mastery = memory.mastery; attempts = memory.attempts; correctAttempts = memory.correctAttempts
        currentStreak = memory.currentStreak; lastPractisedAt = memory.lastReviewedAt
    }
}

private struct AttemptPayload: Encodable {
    let userID: String
    let exerciseID: String
    let skillID: String
    let lessonID: String?
    let exerciseType: String
    let answer: [String: String]
    let correct: Bool
    let hintsUsed: Int
    let responseMS: Int
    let misconception: String?
    let attemptedAt: Date

    init(outcome: ReviewOutcome, userID: String) {
        self.userID = userID; exerciseID = outcome.itemID; skillID = outcome.skillID; lessonID = outcome.lessonID
        exerciseType = outcome.kind == .listening ? "dictation" : outcome.kind == .speaking ? "speaking" : outcome.kind == .sentence ? "sentence_builder" : outcome.kind == .grammar ? "fill_blank" : "choice"
        answer = ["text": outcome.answer, "confidence": String(outcome.confidence.rawValue), "rating": outcome.rating.rawValue]
        correct = outcome.correct; hintsUsed = outcome.hintsUsed; responseMS = outcome.responseMS
        misconception = outcome.misconception; attemptedAt = outcome.attemptedAt
    }
}

private struct ReviewRow: Decodable {
    let itemID: String
    let skillID: String
    let itemType: String
    let intervalDays: Int
    let easeFactor: Double
    let repetitions: Int
    let lapses: Int
    let dueAt: Date
    let lastReviewedAt: Date?

    var memory: MemoryRecord? {
        guard let kind = ReviewKind(rawValue: itemType), let level = CourseLevel.allCases.first(where: { itemID.contains(":\($0.rawValue):") }) else { return nil }
        return MemoryRecord(itemID: itemID, skillID: skillID, level: level, kind: kind,
            stabilityDays: Double(intervalDays), difficulty: min(10, max(1, (3.6 - easeFactor) / 0.23)),
            repetitions: repetitions, lapses: lapses, dueAt: dueAt, lastReviewedAt: lastReviewedAt,
            attempts: repetitions + lapses, correctAttempts: repetitions, currentStreak: repetitions,
            averageResponseMS: nil, lastConfidence: nil, lastMisconception: nil)
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
