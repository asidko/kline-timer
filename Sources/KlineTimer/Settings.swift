import Foundation
import Combine
import KlineCore

/// Persisted user preferences, observable by both the popover and the status item.
final class Settings: ObservableObject {
    @Published var timeframe: Timeframe { didSet { defaults.set(timeframe.rawValue, forKey: Keys.timeframe) } }
    @Published var showCountdown: Bool { didSet { defaults.set(showCountdown, forKey: Keys.showCountdown) } }
    @Published var chimeOnClose: Bool { didSet { defaults.set(chimeOnClose, forKey: Keys.chimeOnClose) } }

    private let defaults: UserDefaults

    private enum Keys {
        static let timeframe = "timeframe"
        static let showCountdown = "showCountdown"
        static let chimeOnClose = "chimeOnClose"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedTimeframe = (defaults.object(forKey: Keys.timeframe) as? Int).flatMap(Timeframe.init(rawValue:))
        self.timeframe = storedTimeframe ?? .m5
        self.showCountdown = (defaults.object(forKey: Keys.showCountdown) as? Bool) ?? true
        self.chimeOnClose = (defaults.object(forKey: Keys.chimeOnClose) as? Bool) ?? false
    }
}
