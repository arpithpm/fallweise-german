import Foundation
import WatchConnectivity

@MainActor
final class PhoneWatchSyncService: NSObject, WCSessionDelegate {
    static let shared = PhoneWatchSyncService()
    private weak var store: LearningStore?

    func start(store: LearningStore) {
        self.store = store
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendProgress() {
        guard WCSession.isSupported() else { return }
        let context: [String: Any] = [
            "learnedWords": Array(store?.learnedWords ?? []),
            "selectedLevel": store?.selectedLevel.rawValue ?? "A1"
        ]
        try? WCSession.default.updateApplicationContext(context)
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.sendProgress() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        apply(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        apply(userInfo)
    }

    nonisolated private func apply(_ payload: [String: Any]) {
        guard let wordID = payload["wordID"] as? String, let correct = payload["correct"] as? Bool else { return }
        Task { @MainActor in
            self.store?.markWord(id: wordID, correct: correct)
            self.sendProgress()
        }
    }
}
