import KlineCore

/// One coin's state as the alert engine sees it: just the numbers it judges
/// against, never a `WatchedCoin` or any view. The engine is fed these so it
/// stays decoupled from the data layer and the UI.
struct CoinAlertSnapshot {
    let name: String        // header label, e.g. "BTC"
    let value: Double       // the live price (for crosses) or a candle close
    let levels: [PriceLevel]
}

/// Watches drawn price levels and fires an alert the moment a value crosses one
/// in its armed direction. Two independent streams feed it: live prices (every
/// poll) drive the "crossed" alert, candle closes drive the "closed above/below"
/// alert. Each is edge-triggered — it fires on the transition onto the far side,
/// not on every sample while there — and re-arms when the value comes back, so a
/// price oscillating around a line alerts once per genuine crossing.
///
/// Crossing state is runtime-only, seeded silently from the first sample so a
/// level already beyond its line at launch doesn't fire. Only the level's config
/// (`PriceLevel`) is persisted; this engine holds nothing worth saving.
@MainActor
final class PriceAlertEngine {
    private let notifier: Notifier

    // Per level, whether the last seen value was beyond the line. `nil` means
    // unseen — the next sample seeds it without alerting.
    private var priceBeyond: [PriceLevel.ID: Bool] = [:]
    private var closeBeyond: [PriceLevel.ID: Bool] = [:]

    init(notifier: Notifier) {
        self.notifier = notifier
    }

    /// Live prices: fire "<coin> crossed <price>" as price moves through a line.
    func observePrices(_ snapshots: [CoinAlertSnapshot]) {
        evaluate(snapshots, state: &priceBeyond) { name, level in
            "\(name) crossed \(PriceFormat.string(level.price))"
        }
    }

    /// Candle closes: fire "<coin> closed above/below <price>" once a candle ends
    /// on the far side of a line.
    func observeCloses(_ snapshots: [CoinAlertSnapshot]) {
        evaluate(snapshots, state: &closeBeyond) { name, level in
            let direction = level.side == .above ? "above" : "below"
            return "\(name) closed \(direction) \(PriceFormat.string(level.price))"
        }
    }

    /// Shared edge detector for both streams: among armed levels, alert on the
    /// false→true transition of `isBeyond` and seed a newly armed level silently.
    /// State is tracked only while the bell is on, so muting a level forgets its
    /// position and re-arming starts fresh from the current side — never from a
    /// crossing that happened while it was off (which would otherwise leave it
    /// stuck "already beyond" and unable to fire). Deleted levels drop out the
    /// same way.
    private func evaluate(
        _ snapshots: [CoinAlertSnapshot],
        state: inout [PriceLevel.ID: Bool],
        message: (String, PriceLevel) -> String
    ) {
        var armed: Set<PriceLevel.ID> = []
        for snapshot in snapshots {
            for level in snapshot.levels where level.bell {
                armed.insert(level.id)
                let beyond = level.isBeyond(snapshot.value)
                defer { state[level.id] = beyond }
                guard let was = state[level.id] else { continue }  // first armed sight: seed only
                if beyond && !was {
                    notifier.post(title: snapshot.name, body: message(snapshot.name, level))
                }
            }
        }
        state = state.filter { armed.contains($0.key) }
    }
}
