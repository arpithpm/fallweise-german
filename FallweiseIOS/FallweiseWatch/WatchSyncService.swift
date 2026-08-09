import Foundation
import WatchConnectivity

@MainActor
final class WatchSyncService: NSObject, WCSessionDelegate {
    static let shared = WatchSyncService()
    private weak var store: WatchLearningStore?

    func start(store: WatchLearningStore) {
        self.store = store
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(wordID: String, correct: Bool, level: String) {
        guard WCSession.isSupported() else { return }
        let payload: [String: Any] = ["wordID": wordID, "correct": correct, "level": level, "reviewedAt": Date().timeIntervalSince1970]
        if WCSession.default.isReachable { WCSession.default.sendMessage(payload, replyHandler: nil) }
        else { WCSession.default.transferUserInfo(payload) }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        importProgress(applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        importProgress(userInfo)
    }

    nonisolated private func importProgress(_ payload: [String: Any]) {
        let learned = payload["learnedWords"] as? [String] ?? []
        let level = payload["selectedLevel"] as? String
        let due = payload["dueWordIDs"] as? [String] ?? []
        Task { @MainActor [weak self] in self?.store?.importProgress(learned: learned, selectedLevel: level, dueWordIDs: due) }
    }
}
