import Foundation
import UserNotifications

public enum NotificationManager {
    public static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    public static func rescheduleAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let now = Date()
        for item in TareasStore.load() {
            if item.isFinished(at: now) { continue }
            let triggerDate = item.criticalDate()
            guard triggerDate > now.addingTimeInterval(60) else { continue }
            if let endsAt = item.endsAt, triggerDate >= endsAt { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(item.icon) \(item.name)"
            content.body = "Necesita atención · vence \(item.remainingText(at: triggerDate))"
            content.sound = .default
            content.threadIdentifier = item.category

            let interval = triggerDate.timeIntervalSince(now)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

            let request = UNNotificationRequest(
                identifier: item.id.uuidString,
                content: content,
                trigger: trigger
            )

            center.add(request)
        }
    }

    public static func cancel(taskID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [taskID.uuidString])
    }
}
