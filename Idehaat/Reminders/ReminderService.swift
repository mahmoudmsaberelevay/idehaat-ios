import Foundation
import UserNotifications

/// Local notifications before a card expires. Scheduled on the device only.
enum ReminderService {
    static let options: [Int] = [0, 7, 14, 30, 60, 90]

    static func label(for days: Int) -> String {
        days == 0 ? String(localized: "Off") : String(localized: "\(days) days before")
    }

    @discardableResult
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default: return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    @MainActor
    static func schedule(for card: Card) async {
        cancel(cardID: card.id)
        guard card.reminderDaysBefore > 0, let expiry = card.expiryDate else { return }
        guard await requestPermission() else { return }

        let title = card.displayTitle
        let center = UNUserNotificationCenter.current()
        let cal = Calendar.current

        func add(id: String, date: Date, body: String) {
            guard date > .now else { return }
            var comps = cal.dateComponents([.year, .month, .day], from: date)
            comps.hour = 10
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }

        let days = card.reminderDaysBefore
        if let before = cal.date(byAdding: .day, value: -days, to: expiry) {
            add(id: "\(card.id.uuidString)-before", date: before,
                body: String(localized: "Expires in \(days) days — time to renew."))
        }
        add(id: "\(card.id.uuidString)-day", date: expiry,
            body: String(localized: "Expires today."))
    }

    static func cancel(cardID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["\(cardID.uuidString)-before", "\(cardID.uuidString)-day"]
        )
    }
}
