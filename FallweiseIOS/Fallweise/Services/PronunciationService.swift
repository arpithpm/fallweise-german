import AVFoundation
import CryptoKit
import Foundation
import OSLog

@MainActor
final class PronunciationService: NSObject, ObservableObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    enum State: Equatable {
        case idle
        case loading
        case playing
        case failed
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var errorMessage: String?
    @Published private(set) var isUsingDeviceVoice = false

    private let audioCDN = URL(string: "https://fallweise-voice-session.arpithpmuddi-0ee.workers.dev/audio")!
    private let model = "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice"
    private let speaker = "Vivian"
    private let rate = "1.0"
    private var player: AVAudioPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var preparedText: String?
    private var preparedAudio: Data?
    private var preparationTask: Task<Void, Never>?
    private var queuedTexts: [String] = []
    private var playingText: String?
    private let logger = Logger(subsystem: "com.arpithpm.fallweise", category: "pronunciation")

    override init() {
        super.init()
        speechSynthesizer.delegate = self
    }

    func prepare(_ text: String) {
        prepare([text])
    }

    func prepare(_ texts: [String]) {
        let texts = texts.filter { !$0.isEmpty }
        guard !texts.isEmpty else { return }
        preparationTask?.cancel()
        preparationTask = Task { [weak self] in
            guard let self else { return }
            for text in texts {
                guard !Task.isCancelled else { return }
                guard let audio = try? await self.fetch(text) else { continue }
                _ = try? self.cache(audio, for: text)
                if text == texts.first {
                    self.preparedText = text
                    self.preparedAudio = audio
                }
            }
        }
    }

    func play(_ text: String) async {
        await play([text])
    }

    func play(_ texts: [String]) async {
        let texts = texts.filter { !$0.isEmpty }
        guard let first = texts.first else { return }
        player?.stop()
        speechSynthesizer.stopSpeaking(at: .immediate)
        queuedTexts = Array(texts.dropFirst())
        errorMessage = nil
        isUsingDeviceVoice = false
        state = .loading
        await playNext(first)
    }

    private func playNext(_ text: String) async {
        playingText = text
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
            isUsingDeviceVoice = false
            state = .playing
        } catch {
            logger.error("Pronunciation failed for \(text, privacy: .public): \(error.localizedDescription, privacy: .public)")
            playWithDeviceVoice(text, because: error)
        }
    }

    private func playWithDeviceVoice(_ text: String, because error: Error) {
        player = nil
        isUsingDeviceVoice = true
        errorMessage = "Natural audio unavailable. Using your iPhone's German voice. \(userMessage(for: error))"

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = preferredGermanVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0

        speechSynthesizer.speak(utterance)
        state = .playing
    }

    private func preferredGermanVoice() -> AVSpeechSynthesisVoice? {
        let germanVoices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("de")
        }
        return germanVoices.first(where: { $0.quality == .premium })
            ?? germanVoices.first(where: { $0.quality == .enhanced })
            ?? AVSpeechSynthesisVoice(language: "de-DE")
    }

    func stop() {
        player?.stop()
        speechSynthesizer.stopSpeaking(at: .immediate)
        player = nil
        queuedTexts = []
        isUsingDeviceVoice = false
        state = .idle
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            guard flag else {
                if let text = self.playingText {
                    self.playWithDeviceVoice(text, because: AudioError.playbackFailed)
                } else {
                    self.state = .failed
                }
                return
            }
            if let next = self.queuedTexts.first {
                self.queuedTexts.removeFirst()
                self.state = .loading
                await self.playNext(next)
            } else {
                self.state = .idle
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            await self.playQueuedTextOrFinish()
        }
    }

    private func playQueuedTextOrFinish() async {
        if let next = queuedTexts.first {
            queuedTexts.removeFirst()
            state = .loading
            await playNext(next)
        } else {
            state = .idle
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.player = nil
            if let text = self.playingText {
                self.playWithDeviceVoice(text, because: error ?? AudioError.couldNotDecode)
            } else {
                self.state = .failed
            }
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
        var lastError: Error = AudioError.invalidResponse
        for attempt in 0..<3 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw AudioError.invalidResponse }
                guard http.statusCode == 200 else { throw AudioError.httpStatus(http.statusCode) }
                guard data.count > 44 else { throw AudioError.emptyAudio }
                return data
            } catch {
                lastError = error
                guard attempt < 2, shouldRetry(error) else { break }
                try? await Task.sleep(for: .milliseconds(250 * (attempt + 1)))
            }
        }
        throw lastError
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
        return URL.applicationSupportDirectory.appending(path: "Pronunciations/\(hash).wav")
    }

    private func shouldRetry(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return [.timedOut, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed, .notConnectedToInternet].contains(urlError.code)
        }
        if case AudioError.httpStatus(let status) = error { return status == 408 || status == 429 || status >= 500 }
        return false
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
