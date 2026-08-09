import Foundation
import UserNotifications

actor ReminderService {
    static let shared = ReminderService()
    private let identifier = "fallweise.daily-review"

    func configure(enabled: Bool, hour: Int, minute: Int, dueCount: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard enabled else { return true }
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else { return false }
            var components = DateComponents(); components.hour = hour; components.minute = minute
            let content = UNMutableNotificationContent()
            content.title = dueCount > 0 ? "Your German memories are ready" : "A small German win?"
            content.body = dueCount > 0 ? "Strengthen \(dueCount) due memories before they fade." : "Two minutes is enough to keep moving."
            content.sound = .default
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
            return true
        } catch { return false }
    }
}
