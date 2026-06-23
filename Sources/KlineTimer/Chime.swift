import AppKit

/// Plays a short system beep when a candle closes.
enum Chime {
    static func play() {
        NSSound(named: "Tink")?.play()
    }
}
