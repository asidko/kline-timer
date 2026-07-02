import XCTest
@testable import KlineCore

final class PriceLevelTests: XCTestCase {
    // A line drawn above the market arms upward: the alert exists to catch price
    // rising INTO the level, so anything still below it is not yet beyond.
    func testAboveSideArmsUpward() {
        let level = PriceLevel(price: 100, side: .above)
        XCTAssertFalse(level.isBeyond(99.99))
        XCTAssertTrue(level.isBeyond(100))      // touching the line counts as reached
        XCTAssertTrue(level.isBeyond(101))
    }

    // A line drawn below the market arms downward — the mirror case.
    func testBelowSideArmsDownward() {
        let level = PriceLevel(price: 100, side: .below)
        XCTAssertFalse(level.isBeyond(100.01))
        XCTAssertTrue(level.isBeyond(100))
        XCTAssertTrue(level.isBeyond(99))
    }

    // The armed direction is fixed by where the line lands relative to the live
    // price, so the same line means "alert me on the way up" or "on the way down"
    // depending on the market when it was drawn. A line on the market arms upward.
    func testSideDerivation() {
        XCTAssertEqual(PriceLevel.side(forLineAt: 120, market: 100), .above)
        XCTAssertEqual(PriceLevel.side(forLineAt: 80, market: 100), .below)
        XCTAssertEqual(PriceLevel.side(forLineAt: 100, market: 100), .above)
    }
}
