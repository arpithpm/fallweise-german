import AVFoundation
import CryptoKit
import Foundation
import OSLog

@MainActor
final class PronunciationService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    enum State: Equatable {
        case idle
        case loading
        case playing
        case failed
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var errorMessage: String?

    private let audioCDN = URL(string: "https://pub-b7374a734fb54fb19c76923b93a2e3b6.r2.dev")!
    private let model = "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice"
    private let speaker = "Vivian"
    private let rate = "0.88"
    private var player: AVAudioPlayer?
    private var preparedText: String?
    private var preparedAudio: Data?
    private var preparationTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.arpithpm.fallweise", category: "pronunciation")

    func prepare(_ text: String) {
        guard !text.isEmpty, text != preparedText else { return }
        preparationTask?.cancel()
        preparationTask = Task { [weak self] in
            guard let self else { return }
            let audio = try? await self.fetch(text)
            guard !Task.isCancelled else { return }
            self.preparedText = text
            self.preparedAudio = audio
        }
    }

    func play(_ text: String) async {
        guard !text.isEmpty else { return }
        player?.stop()
        errorMessage = nil
        state = .loading

        do {
            let audio: Data
            if preparedText == text, let preparedAudio {
                audio = preparedAudio
            } else {
                audio = try await fetch(text)
                preparedText = text
                preparedAudio = audio
            }

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)

            let localURL = try cache(audio, for: text)
            let player = try AVAudioPlayer(contentsOf: localURL)
            player.delegate = self
            guard player.prepareToPlay() else { throw AudioError.couldNotDecode }
            self.player = player
            guard player.play() else { throw AudioError.playbackFailed }
            state = .playing
        } catch {
            logger.error("Pronunciation failed for \(text, privacy: .public): \(error.localizedDescription, privacy: .public)")
            errorMessage = userMessage(for: error)
            player = nil
            state = .failed
        }
    }

    func stop() {
        player?.stop()
        player = nil
        state = .idle
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            self.state = flag ? .idle : .failed
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.player = nil
            self.state = .failed
        }
    }

    private func fetch(_ text: String) async throws -> Data {
        let cachedURL = cachedURL(for: text)
        if let data = try? Data(contentsOf: cachedURL), !data.isEmpty { return data }

        let source = "\(model)|\(speaker)|\(rate)|\(text)"
        let digest = SHA256.hash(data: Data(source.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        let url = audioCDN.appending(path: "\(hash).wav")
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AudioError.invalidResponse }
        guard http.statusCode == 200 else { throw AudioError.httpStatus(http.statusCode) }
        guard data.count > 44 else { throw AudioError.emptyAudio }
        return data
    }

    @discardableResult
    private func cache(_ data: Data, for text: String) throws -> URL {
        let url = cachedURL(for: text)
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        }
        return url
    }

    private func cachedURL(for text: String) -> URL {
        let source = "\(model)|\(speaker)|\(rate)|\(text)"
        let digest = SHA256.hash(data: Data(source.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return URL.cachesDirectory.appending(path: "Pronunciations/\(hash).wav")
    }

    private func userMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet: return "No internet connection."
            case .timedOut: return "Audio download timed out."
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed: return "The audio service could not be reached."
            default: return "Audio download failed (\(urlError.code.rawValue))."
            }
        }
        if case AudioError.httpStatus(let status) = error { return "Audio service returned HTTP \(status)." }
        return "This pronunciation could not be played."
    }

    private enum AudioError: LocalizedError {
        case invalidResponse
        case httpStatus(Int)
        case emptyAudio
        case couldNotDecode
        case playbackFailed

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "Invalid server response"
            case .httpStatus(let status): "HTTP \(status)"
            case .emptyAudio: "Empty audio response"
            case .couldNotDecode: "Audio decoding failed"
            case .playbackFailed: "Audio playback failed"
            }
        }
    }
}
