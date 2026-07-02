import Foundation

/// Delivers a user-facing alert banner. An abstraction so `PriceAlertEngine`
/// depends on *posting an alert*, not on any particular delivery mechanism.
protocol Notifier {
    /// Ask the system for permission to alert, once at launch. Most channels need
    /// nothing, so the default is a no-op.
    func requestAuthorization()
    func post(title: String, body: String)
}

extension Notifier {
    func requestAuthorization() {}
}

/// The right delivery for the current run: real user notifications when launched
/// from the app bundle — proper permission prompt, banners attributed to the app
/// with its icon — and `osascript` otherwise. A bare `.build` binary has no
/// bundle, where `UNUserNotificationCenter.current()` traps, so it can't use the
/// real path.
func makeNotifier() -> Notifier {
    Bundle.main.bundleIdentifier != nil ? UserNotificationNotifier() : SystemNotifier()
}

/// Posts a Notification Center banner via `osascript`. This path works whether
/// the app runs as a bare binary in development or from the signed bundle, and
/// needs no authorization prompt — unlike `UNUserNotificationCenter`, which
/// requires a bundle and a permission grant. Swapping to that later is a change
/// confined to this file, since the engine only sees `Notifier`.
struct SystemNotifier: Notifier {
    func post(title: String, body: String) {
        let script = "display notification \(escaped(body)) with title \(escaped(title)) sound name \"Glass\""
        // Off the main thread: spawning a process must not stall the UI tick.
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            try? process.run()
        }
    }

    /// AppleScript string literal with backslashes and quotes escaped, so a coin
    /// name or formatted price can never break out of the `display notification`.
    private func escaped(_ string: String) -> String {
        let body = string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(body)\""
    }
}
