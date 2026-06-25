import Foundation

/// One pickable coin: its base ticker and full name. The monogram is the first
/// letter, shown in the picker's avatar circle.
struct CoinInfo: Identifiable {
    let symbol: String   // base ticker, e.g. "BTC" (paired with USDT when watched)
    let name: String
    var id: String { symbol }
    var monogram: String { String(symbol.prefix(1)) }
}

/// The fixed list the Watch-coin picker browses and searches. Curated and
/// ordered biggest-first by market cap; all trade as `<symbol>USDT` on Binance.
enum CoinCatalog {
    static let all: [CoinInfo] = [
        CoinInfo(symbol: "BTC", name: "Bitcoin"),
        CoinInfo(symbol: "ETH", name: "Ethereum"),
        CoinInfo(symbol: "SOL", name: "Solana"),
        CoinInfo(symbol: "XRP", name: "XRP"),
        CoinInfo(symbol: "DOGE", name: "Dogecoin"),
        CoinInfo(symbol: "BNB", name: "BNB"),
        CoinInfo(symbol: "ADA", name: "Cardano"),
        CoinInfo(symbol: "AVAX", name: "Avalanche"),
        CoinInfo(symbol: "LINK", name: "Chainlink"),
        CoinInfo(symbol: "TON", name: "Toncoin"),
        CoinInfo(symbol: "TRX", name: "Tron"),
        CoinInfo(symbol: "DOT", name: "Polkadot"),
        CoinInfo(symbol: "SUI", name: "Sui"),
        CoinInfo(symbol: "NEAR", name: "NEAR Protocol"),
        CoinInfo(symbol: "APT", name: "Aptos"),
        CoinInfo(symbol: "OP", name: "Optimism"),
        CoinInfo(symbol: "ARB", name: "Arbitrum"),
        CoinInfo(symbol: "PEPE", name: "Pepe"),
    ]

    /// Live autocomplete: case-insensitive match on ticker or name. Empty query
    /// returns nothing (the caller shows the browse sections instead).
    static func search(_ query: String) -> [CoinInfo] {
        let needle = query.trimmingCharacters(in: .whitespaces).uppercased()
        guard !needle.isEmpty else { return [] }
        return all.filter { $0.symbol.contains(needle) || $0.name.uppercased().contains(needle) }
    }

    static func info(base: String) -> CoinInfo? {
        all.first { $0.symbol == base.uppercased() }
    }
}
