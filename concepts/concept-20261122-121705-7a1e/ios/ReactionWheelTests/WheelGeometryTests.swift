import XCTest
@testable import ReactionWheel

final class WheelGeometryTests: XCTestCase {
    private let phoneSafeRect = CGRect(x: 0, y: 59, width: 390, height: 751)

    func testMidScreenFixture() {
        let placement = WheelGeometry.place(anchor: CGPoint(x: 195, y: 500), safeRect: phoneSafeRect, scale: 1, rtl: false, persistent: false)
        XCTAssertFalse(placement.compact)
        XCTAssertEqual(placement.axis, .up)
        XCTAssertEqual(placement.center.x, 195, accuracy: 1)
        XCTAssertEqual(placement.center.y, 500, accuracy: 1)
        assertFit(placement, safeRect: phoneSafeRect, scale: 1)
    }

    func testLeftEdgeFixtureUsesMinimalRightFacingShift() {
        let anchor = CGPoint(x: 20, y: 500)
        let placement = WheelGeometry.place(anchor: anchor, safeRect: phoneSafeRect, scale: 1, rtl: false, persistent: false)
        XCTAssertFalse(placement.compact)
        XCTAssertEqual(placement.axis, .right)
        XCTAssertEqual(placement.center.x - anchor.x, 22, accuracy: 1)
        XCTAssertEqual(placement.center.y, anchor.y, accuracy: 1)
        assertFit(placement, safeRect: phoneSafeRect, scale: 1)
    }

    func testTopCenterFixtureFacesDown() {
        let placement = WheelGeometry.place(anchor: CGPoint(x: 195, y: 110), safeRect: phoneSafeRect, scale: 1, rtl: false, persistent: false)
        XCTAssertFalse(placement.compact)
        XCTAssertEqual(placement.axis, .down)
        XCTAssertEqual(placement.center.x, 195, accuracy: 1)
        XCTAssertEqual(placement.center.y, 110, accuracy: 1)
        assertFit(placement, safeRect: phoneSafeRect, scale: 1)
    }

    func testTopLeftFixtureUsesSmallestValidFallback() {
        let anchor = CGPoint(x: 20, y: 110)
        let placement = WheelGeometry.place(anchor: anchor, safeRect: phoneSafeRect, scale: 1, rtl: false, persistent: false)
        XCTAssertFalse(placement.compact)
        XCTAssertEqual(placement.axis, .downRight)
        XCTAssertLessThanOrEqual(hypot(placement.center.x - anchor.x, placement.center.y - anchor.y), 120.5)
        assertFit(placement, safeRect: phoneSafeRect, scale: 1)
    }

    func testLargeTypeFixtureChoosesRightAxisAndMinimalShift() {
        let safe = CGRect(x: 0, y: 48, width: 360, height: 728)
        let anchor = CGPoint(x: 180, y: 500)
        let placement = WheelGeometry.place(anchor: anchor, safeRect: safe, scale: 1.3, rtl: false, persistent: false)
        XCTAssertFalse(placement.compact)
        XCTAssertEqual(placement.axis, .right)
        XCTAssertEqual(placement.center.x, 167.6, accuracy: 1)
        assertFit(placement, safeRect: safe, scale: 1.3)
    }

    func testIndexOrderMirrorsInRTL() {
        let ltr = WheelGeometry.centers(center: CGPoint(x: 200, y: 400), axis: .up, scale: 1, rtl: false)
        let rtl = WheelGeometry.centers(center: CGPoint(x: 200, y: 400), axis: .up, scale: 1, rtl: true)
        XCTAssertLessThan(ltr[0].x, ltr[5].x)
        XCTAssertGreaterThan(rtl[0].x, rtl[5].x)
    }

    func testTinyWindowUsesCompact() {
        let placement = WheelGeometry.place(anchor: CGPoint(x: 120, y: 200), safeRect: CGRect(x: 0, y: 0, width: 240, height: 400), scale: 1.3, rtl: false, persistent: true)
        XCTAssertTrue(placement.compact)
    }

    func testHeldAnchorInvariant() {
        let anchor = CGPoint(x: 195, y: 500)
        let placement = WheelGeometry.place(anchor: anchor, safeRect: phoneSafeRect, scale: 1, rtl: false, persistent: false)
        XCTAssertGreaterThanOrEqual(placement.itemCenters.map { hypot($0.x - anchor.x, $0.y - anchor.y) }.min()!, 96)
    }

    private func assertFit(_ placement: WheelPlacement, safeRect: CGRect, scale: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        let inset = ceil(8 + 0.5 * 1.4 * 48 * scale)
        let allowed = safeRect.insetBy(dx: inset, dy: inset)
        XCTAssertEqual(Set(placement.itemCenters.map { "\(round($0.x)),\(round($0.y))" }).count, 6, file: file, line: line)
        XCTAssertTrue(placement.itemCenters.allSatisfy(allowed.contains), file: file, line: line)
        XCTAssertTrue(safeRect.insetBy(dx: 8, dy: 8).contains(placement.labelFrame), file: file, line: line)
        let selectedRadius = 0.5 * 1.4 * 48 * scale
        for center in placement.itemCenters {
            let closestX = min(max(center.x, placement.labelFrame.minX), placement.labelFrame.maxX)
            let closestY = min(max(center.y, placement.labelFrame.minY), placement.labelFrame.maxY)
            XCTAssertGreaterThanOrEqual(hypot(center.x - closestX, center.y - closestY), selectedRadius, file: file, line: line)
        }
    }
}
