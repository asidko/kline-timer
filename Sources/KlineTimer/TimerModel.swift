import Foundation
import Combine

/// Live countdown the popover observes while it is open. The timeframe it
/// belongs to comes from `Settings` (the source of truth); this only carries
/// the per-second value.
final class TimerModel: ObservableObject {
    @Published private(set) var secondsLeft: Int = 0

    func update(secondsLeft: Int) {
        self.secondsLeft = secondsLeft
    }
}
