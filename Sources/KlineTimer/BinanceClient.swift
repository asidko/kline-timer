import Foundation
import KlineCore

/// Reads recent candles from Binance's public REST API. No key, no websocket —
/// a single GET per refresh keeps the app light. The `interval` codes Binance
/// expects ("1m", "5m", "4h", …) are exactly `Timeframe.label`, so callers pass
/// the label straight through.
enum BinanceClient {
    enum Failure: Error { case badStatus(Int), malformed }

    private static let host = "https://api.binance.com/api/v3/klines"

    /// The last `limit` candles for `symbol` (a full Binance pair, e.g. "BTCUSDT")
    /// on `interval`. Throws on a non-200 response or an unparseable body.
    static func klines(symbol: String, interval: String, limit: Int) async throws -> [Candle] {
        var components = URLComponents(string: host)!
        components.queryItems = [
            .init(name: "symbol", value: symbol),
            .init(name: "interval", value: interval),
            .init(name: "limit", value: String(limit)),
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse else { throw Failure.malformed }
        guard http.statusCode == 200 else { throw Failure.badStatus(http.statusCode) }
        return try decode(data)
    }

    /// Binance returns each candle as a heterogeneous array; index 0 is the open
    /// time (epoch ms) and indices 1–4 are open, high, low, close as decimal
    /// strings — the fields that matter to us.
    private static func decode(_ data: Data) throws -> [Candle] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[Any]] else {
            throw Failure.malformed
        }
        return try rows.map { row in
            guard row.count >= 5,
                  let openTimeMs = number(row[0]),
                  let open = number(row[1]), let high = number(row[2]),
                  let low = number(row[3]), let close = number(row[4]) else {
                throw Failure.malformed
            }
            // Epoch-millisecond values are exactly representable in Double.
            return Candle(openTime: Int(openTimeMs), open: open, high: high, low: low, close: close)
        }
    }

    /// A kline field is a decimal string like "63100.10" (prices) or a raw JSON
    /// number (the open time); tolerate either shape for any field.
    private static func number(_ value: Any) -> Double? {
        if let string = value as? String { return Double(string) }
        if let number = value as? Double { return number }
        return nil
    }
}
