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
            "selectedLevel": store?.selectedLevel.rawValue ?? "A1",
            "dueWordIDs": Array(Set(store?.reviewCatalog.filter { $0.word != nil && store?.isDue($0) == true }.compactMap { $0.word?.id } ?? [])),
            "practiceDays": practicePayload
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
        let practiceDay = payload["practiceDay"] as? String
        let practiceAttempts = payload["practiceAttempts"] as? Int ?? 0
        let practiceCorrect = payload["practiceCorrect"] as? Int ?? 0
        let practiceFocusedSeconds = payload["practiceFocusedSeconds"] as? Int ?? 0
        Task { @MainActor in
            self.store?.markWord(id: wordID, correct: correct)
            if let day = practiceDay {
                self.store?.mergePracticeDay(PracticeDay(day: day,
                    attempts: practiceAttempts, correctAttempts: practiceCorrect,
                    focusedSeconds: practiceFocusedSeconds))
            }
            self.sendProgress()
        }
    }

    private var practicePayload: [[String: Any]] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: .now) ?? .distantPast
        return store?.practiceDays.values.compactMap { day in
            guard PracticeCalendarMath.date(for: day.day).map({ $0 >= cutoff }) == true else { return nil }
            return ["day": day.day, "attempts": day.attempts, "correct": day.correctAttempts,
                "lessonSteps": day.lessonSteps, "completedLessons": day.completedLessons,
                "focusedSeconds": day.focusedSeconds]
        } ?? []
    }
}
