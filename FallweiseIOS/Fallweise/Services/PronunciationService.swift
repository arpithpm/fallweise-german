import AVFoundation
import CryptoKit
import Foundation

@MainActor
final class PronunciationService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    enum State: Equatable {
        case idle
        case loading
        case playing
        case failed
    }

    @Published private(set) var state: State = .idle

    private let audioCDN = URL(string: "https://pub-b7374a734fb54fb19c76923b93a2e3b6.r2.dev")!
    private let model = "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice"
    private let speaker = "Vivian"
    private let rate = "0.88"
    private var player: AVAudioPlayer?
    private var preparedText: String?
    private var preparedAudio: Data?
    private var preparationTask: Task<Void, Never>?

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

            let player = try AVAudioPlayer(data: audio)
            player.delegate = self
            player.prepareToPlay()
            guard player.play() else { throw AudioError.playbackFailed }
            self.player = player
            state = .playing
        } catch {
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
        let source = "\(model)|\(speaker)|\(rate)|\(text)"
        let digest = SHA256.hash(data: Data(source.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        let url = audioCDN.appending(path: "\(hash).wav")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200, !data.isEmpty else {
            throw AudioError.unavailable
        }
        return data
    }

    private enum AudioError: Error {
        case unavailable
        case playbackFailed
    }
}
