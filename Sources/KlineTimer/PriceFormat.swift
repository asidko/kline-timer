import Foundation

/// Group-separated price with a precision that suits the magnitude: coarse for
/// four-figure coins, finer for sub-dollar ones. Shared by the coin header, the
/// chart's price-level controls, and the alert messages.
enum PriceFormat {
    // One reusable formatter per precision — NumberFormatter is costly to build,
    // and the header re-renders on every price tick.
    private static let formatters: [Int: NumberFormatter] = Dictionary(
        uniqueKeysWithValues: [1, 2, 4, 6].map { digits in
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = digits
            formatter.maximumFractionDigits = digits
            return (digits, formatter)
        }
    )

    static func string(_ price: Double) -> String {
        let digits: Int
        switch abs(price) {
        case 1000...: digits = 1
        case 1...: digits = 2
        case 0.01...: digits = 4
        default: digits = 6
        }
        return formatters[digits]?.string(from: NSNumber(value: price)) ?? String(price)
    }
}
