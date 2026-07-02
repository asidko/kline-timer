import XCTest
@testable import KlineCore

final class CandleClockTests: XCTestCase {
    // 90s into a 5m candle must leave 210s — the readout drives a trader's entry timing,
    // so an off-by-one here is a wrong "time to close".
    func testSecondsLeftMidCandle() {
        XCTAssertEqual(CandleClock.secondsLeft(timeframe: .m5, now: 90), 210)
    }

    // Exactly on a boundary is a fresh candle: the full interval remains, never 0.
    func testSecondsLeftOnBoundary() {
        XCTAssertEqual(CandleClock.secondsLeft(timeframe: .m5, now: 300), 300)
        XCTAssertEqual(CandleClock.secondsLeft(timeframe: .m1, now: 0), 60)
    }

    // The last fraction of a second before close shows 1, never 0 — the UI must
    // not flash 0:00 before restarting.
    func testSecondsLeftNeverZero() {
        XCTAssertEqual(CandleClock.secondsLeft(timeframe: .m5, now: 299.4), 1)
    }

    // 4h candles align to UTC 00:00/04:00/…; the index must advance exactly on
    // the boundary so the chime fires once per real close, not on app-relative time.
    func testCandleIndexAdvancesOnClose() {
        let h4 = TimeInterval(4 * 3600)
        XCTAssertEqual(
            CandleClock.candleIndex(timeframe: .h4, now: h4 - 1),
            CandleClock.candleIndex(timeframe: .h4, now: 0)
        )
        XCTAssertEqual(
            CandleClock.candleIndex(timeframe: .h4, now: h4),
            CandleClock.candleIndex(timeframe: .h4, now: 0) + 1
        )
    }

    // The final-minute red alert is for the last 60s of a multi-minute candle.
    // A 1m candle must NEVER be "final" — otherwise it would be red its whole
    // life and permanently override the hide-countdown toggle (the bug that
    // made the toggle look dead on 1m).
    func testFinalMinuteOnlyForCandlesOverAMinute() {
        XCTAssertFalse(CandleClock.isFinalMinute(timeframe: .m1, secondsLeft: 30))
        XCTAssertFalse(CandleClock.isFinalMinute(timeframe: .m1, secondsLeft: 1))
        XCTAssertTrue(CandleClock.isFinalMinute(timeframe: .m5, secondsLeft: 59))
        XCTAssertFalse(CandleClock.isFinalMinute(timeframe: .m5, secondsLeft: 60))
        XCTAssertTrue(CandleClock.isFinalMinute(timeframe: .h4, secondsLeft: 12))
    }

    // Under an hour shows m:ss; an hour or more shows h:mm:ss — the format the
    // design specifies for the menu bar and readout.
    func testFormat() {
        XCTAssertEqual(CandleClock.format(secondsLeft: 204), "3:24")
        XCTAssertEqual(CandleClock.format(secondsLeft: 47), "0:47")
        XCTAssertEqual(CandleClock.format(secondsLeft: 3661), "1:01:01")
    }

    // Close alerts pick the just-closed candle by its exchange open time, so the
    // index→open-time mapping must invert candleIndex exactly — a mismatch means
    // alerts silently judge the wrong candle.
    func testOpenTimeMsInvertsCandleIndex() {
        let now: TimeInterval = 1_700_003_456
        let index = CandleClock.candleIndex(timeframe: .m5, now: now)
        let openTimeMs = CandleClock.openTimeMs(candleIndex: index, timeframe: .m5)
        XCTAssertEqual(CandleClock.candleIndex(timeframe: .m5, now: TimeInterval(openTimeMs) / 1000), index)
        XCTAssertEqual(openTimeMs % (5 * 60 * 1000), 0)  // aligned to the 5m grid
    }

    // The chart fits to the series extremes: lowest low and highest high across
    // all candles, not just the first or last. A wrong range squashes the chart.
    func testPriceRangeSpansAllCandles() {
        let candles = [
            Candle(openTime: 0, open: 10, high: 12, low: 9, close: 11),
            Candle(openTime: 1, open: 11, high: 15, low: 8, close: 14),
            Candle(openTime: 2, open: 14, high: 14, low: 13, close: 13),
        ]
        let range = candles.priceRange
        XCTAssertEqual(range?.low, 8)
        XCTAssertEqual(range?.high, 15)
    }

    // An empty series has no extent — the chart must draw nothing, not crash.
    func testPriceRangeEmptyIsNil() {
        XCTAssertNil([Candle]().priceRange)
    }
}
