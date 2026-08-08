import Foundation
import LiveKit

@MainActor
final class VoiceService: ObservableObject {
    enum Event { case ready, speechStarted(String), speechFinished(String), transcript(String), state(String), failure(String) }
    @Published var isConnected = false
    var onEvent: ((Event) -> Void)?
    private var room: Room?
    private let endpoint = URL(string: "https://fallweise-voice-session.arpithpmuddi-0ee.workers.dev/api/livekit/session")!

    func connect(microphoneEnabled: Bool = true) async throws {
        if isConnected { return }
        var accessToken = try await SupabaseService.shared.accessToken()
        var result = try await requestCredentials(accessToken: accessToken)
        if result.response.statusCode == 401 {
            accessToken = try await SupabaseService.shared.renewedAccessToken()
            result = try await requestCredentials(accessToken: accessToken)
        }
        guard result.response.statusCode == 201 else {
            let message = (try? JSONDecoder().decode(SessionError.self, from: result.data).error)
                ?? "Mia's voice service returned HTTP \(result.response.statusCode)."
            throw VoiceConnectionError.service(message)
        }
        let credentials = try JSONDecoder().decode(Credentials.self, from: result.data)
        let room = Room(delegate: self)
        self.room = room
        try await room.connect(url: credentials.serverURL, token: credentials.participantToken)
        if microphoneEnabled {
            try await room.localParticipant.setMicrophone(enabled: true)
        }
        isConnected = true
        try await publish(["type": "hello"])
    }

    private func requestCredentials(accessToken: String) async throws -> (data: Data, response: HTTPURLResponse) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, httpResponse)
    }

    func speak(_ text: String, id: String) async throws {
        try await publish(["type": "speak", "id": id, "text": text])
    }

    func interrupt() async { try? await publish(["type": "interrupt"]); await disconnect() }
    func disconnect() async { await room?.disconnect(); room = nil; isConnected = false }

    private func publish(_ value: [String: String]) async throws {
        guard let room else { throw URLError(.notConnectedToInternet) }
        let data = try JSONSerialization.data(withJSONObject: value)
        try await room.localParticipant.publish(data: data, options: DataPublishOptions(topic: "fallweise.lesson", reliable: true))
    }
}

extension VoiceService: RoomDelegate {
    nonisolated func room(_ room: Room, participant: RemoteParticipant?, didReceiveData data: Data, forTopic topic: String, encryptionType: EncryptionType) {
        guard topic == "fallweise.agent", let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let type = message["type"] as? String else { return }
        Task { @MainActor in
            switch type {
            case "ready": onEvent?(.ready)
            case "speech_started": onEvent?(.speechStarted(message["id"] as? String ?? ""))
            case "speech_finished": onEvent?(.speechFinished(message["id"] as? String ?? ""))
            case "transcript": onEvent?(.transcript(message["text"] as? String ?? ""))
            case "agent_state", "user_state": onEvent?(.state(message["state"] as? String ?? ""))
            case "speech_failed": onEvent?(.failure("Mia could not speak. Please retry."))
            default: break
            }
        }
    }
}

private struct Credentials: Decodable {
    let serverURL: String
    let participantToken: String
    enum CodingKeys: String, CodingKey { case serverURL = "server_url", participantToken = "participant_token" }
}

private struct SessionError: Decodable { let error: String }

private enum VoiceConnectionError: LocalizedError {
    case service(String)
    var errorDescription: String? {
        switch self { case .service(let message): message }
    }
}
