import AVFoundation
import CryptoKit
import Foundation

@MainActor
final class WatchPronunciationService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    private var player: AVAudioPlayer?
    private let base = URL(string: "https://pub-b7374a734fb54fb19c76923b93a2e3b6.r2.dev")!

    func play(_ text: String) async {
        guard !text.isEmpty else { return }
        player?.stop()
        isLoading = true
        defer { isLoading = false }
        do {
            let source = "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice|Vivian|0.88|\(text)"
            let hash = SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
            let (data, response) = try await URLSession.shared.data(from: base.appending(path: "\(hash).wav"))
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            player.prepareToPlay()
            self.player = player
            isPlaying = player.play()
        } catch { isPlaying = false }
    }

    func stop() { player?.stop(); player = nil; isPlaying = false }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.isPlaying = false; self.player = nil }
    }
}
