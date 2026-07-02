import UserNotifications

/// Delivers real user notifications through `UNUserNotificationCenter`, so banners
/// are attributed to the app with its icon and live under its own entry in
/// Notifications settings. Valid only from the signed app bundle —
/// `current()` traps without one — so the app picks this path only when bundled.
final class UserNotificationNotifier: NSObject, Notifier, UNUserNotificationCenterDelegate {
    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Present the banner even while the panel is open and the app is active; a
    /// foreground app would otherwise only get the notification in the list.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
