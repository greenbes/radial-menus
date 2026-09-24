import XCTest
@testable import RadialCore

final class DesktopTests: XCTestCase {
    func testAdjacentDisplaysAllowStraddlingAndContinuousMovementToBothOuterEdges() throws {
        let desktop = make([Rect(x: -1000, y: 0, width: 1000, height: 800),
                            Rect(x: 0, y: 0, width: 1000, height: 800)])
        let start = Rect(x: -100, y: 300, width: 200, height: 100)
        XCTAssertTrue(desktop.contains(start))
        XCTAssertEqual(desktop.place(start), start)
        let left = try XCTUnwrap(desktop.move(start, by: Vector(x: -600, y: 0)))
        XCTAssertEqual(left.x, -700)
        let right = try XCTUnwrap(desktop.move(left, by: Vector(x: 1200, y: 0)))
        XCTAssertEqual(right.x, 500)
        XCTAssertEqual(desktop.move(right, by: Vector(x: 10000, y: 0))?.x, 800)
        XCTAssertEqual(desktop.move(right, by: Vector(x: -10000, y: 0))?.x, -1000)
        XCTAssertNotEqual(desktop.displayID(for: left), desktop.displayID(for: right))
    }

    func testStackedDisplaysCrossVerticallyAndClampOuterEdges() {
        let desktop = make([Rect(x: 0, y: -800, width: 1000, height: 800),
                            Rect(x: 0, y: 0, width: 1000, height: 800)])
        let frame = Rect(x: 300, y: -100, width: 200, height: 200)
        XCTAssertTrue(desktop.contains(frame))
        XCTAssertEqual(desktop.move(frame, by: Vector(x: 0, y: 500))?.y, 400)
        XCTAssertEqual(desktop.move(frame, by: Vector(x: 0, y: 10000))?.y, 600)
        XCTAssertEqual(desktop.move(frame, by: Vector(x: 0, y: -10000))?.y, -800)
    }

    func testLargeMovementCannotJumpADesktopGap() {
        let desktop = make([Rect(x: -1000, y: 0, width: 980, height: 800),
                            Rect(x: 20, y: 0, width: 980, height: 800)])
        let frame = Rect(x: -500, y: 300, width: 200, height: 200)
        XCTAssertEqual(desktop.move(frame, by: Vector(x: 10000, y: 0))?.x, -220)
        XCTAssertFalse(desktop.contains(Rect(x: -100, y: 300, width: 200, height: 200)))
        XCTAssertTrue(desktop.bounds.width == 2000, "The bounding rectangle alone would incorrectly include the gap")
    }

    func testOffsetDisplaysOnlyAllowCrossingWhereTheCompleteMenuFits() throws {
        let desktop = make([Rect(x: 0, y: 0, width: 1000, height: 800),
                            Rect(x: 1000, y: 400, width: 1000, height: 800)])
        let low = Rect(x: 800, y: 100, width: 200, height: 200)
        XCTAssertEqual(desktop.move(low, by: Vector(x: 600, y: 0)), low)
        let raised = try XCTUnwrap(desktop.move(low, by: Vector(x: 600, y: 400)))
        XCTAssertEqual(raised, Rect(x: 800, y: 500, width: 200, height: 200))
        XCTAssertEqual(desktop.move(raised, by: Vector(x: 600, y: 0))?.x, 1400)
        let atCorner = Rect(x: 800, y: 600, width: 200, height: 200)
        XCTAssertEqual(desktop.move(atCorner, by: Vector(x: 200, y: 200)),
                       Rect(x: 1000, y: 800, width: 200, height: 200))
    }

    func testDisplaysTouchingOnlyAtACornerDoNotCreateAnInvisiblePassage() {
        let desktop = make([Rect(x: -800, y: 0, width: 800, height: 800),
                            Rect(x: 0, y: 800, width: 800, height: 800)])
        let frame = Rect(x: -200, y: 600, width: 200, height: 200)
        XCTAssertEqual(desktop.move(frame, by: Vector(x: 1000, y: 1000)), frame)
        XCTAssertFalse(desktop.contains(Rect(x: -100, y: 700, width: 200, height: 200)))
    }

    func testPlacementSpansDisplaysAndRecoversToRemainingDisplay() {
        let left = Rect(x: -1000, y: 0, width: 1000, height: 800)
        let right = Rect(x: 0, y: 0, width: 1000, height: 800)
        let spanning = Rect(x: -600, y: 100, width: 1200, height: 400)
        XCTAssertEqual(make([left, right]).place(spanning), spanning)
        XCTAssertNil(make([right]).place(spanning))
        XCTAssertEqual(make([right]).place(Rect(x: -600, y: 100, width: 400, height: 400)),
                       Rect(x: 0, y: 100, width: 400, height: 400))
    }

    func testDisplayOrderDoesNotChangeGeometryOrIdentity() {
        let desktop = make([Rect(x: -1000, y: 0, width: 1000, height: 800),
                            Rect(x: 0, y: 0, width: 1000, height: 800)])
        XCTAssertEqual(Desktop(displays: desktop.displays.reversed()), desktop)
        XCTAssertEqual(desktop.displayID(for: Rect(x: -100, y: 100, width: 200, height: 100)), "0")
    }

    func testInvalidDesktopsAndFramesCannotBeUsed() {
        let valid = Rect(x: 0, y: 0, width: 100, height: 100)
        for desktop in [make([]), make([Rect(x: .nan, y: 0, width: 100, height: 100)]),
                        make([Rect(x: 0, y: 0, width: 0, height: 100)]),
                        Desktop(displays: [DisplayArea(id: "", bounds: valid)]),
                        Desktop(displays: [DisplayArea(id: "same", bounds: valid), DisplayArea(id: "same", bounds: valid)])] {
            XCTAssertFalse(desktop.isValid)
            XCTAssertFalse(desktop.contains(valid))
            XCTAssertNil(desktop.place(valid))
            XCTAssertNil(desktop.move(valid, by: .zero))
        }
        let desktop = make([valid])
        XCTAssertNil(desktop.move(valid, by: Vector(x: .nan, y: 0)))
        XCTAssertNil(desktop.place(Rect(x: .infinity, y: 0, width: 10, height: 10)))
    }

    func testCoveragePlacementAndSweepsAgreeWithIndependentUnitCellOracle() throws {
        let arrangements = [
            [Rect(x: -6, y: 0, width: 6, height: 8), Rect(x: 0, y: 2, width: 6, height: 6)],
            [Rect(x: -6, y: 0, width: 5, height: 8), Rect(x: 1, y: 0, width: 5, height: 8)],
            [Rect(x: -6, y: 0, width: 12, height: 3), Rect(x: -6, y: 5, width: 12, height: 3),
             Rect(x: -6, y: 3, width: 4, height: 2), Rect(x: 2, y: 3, width: 4, height: 2)]
        ]
        for boxes in arrangements {
            let desktop = make(boxes)
            // Integer display/frame edges make unit-cell centers an exact,
            // independent coverage oracle, including the interior desktop hole.
            func visible(_ x: Int, _ y: Int) -> Bool {
                (x..<(x + 3)).allSatisfy { xx in (y..<(y + 2)).allSatisfy { yy in
                    boxes.contains { Double(xx) + 0.5 >= $0.x && Double(xx) + 0.5 < $0.x + $0.width &&
                        Double(yy) + 0.5 >= $0.y && Double(yy) + 0.5 < $0.y + $0.height }
                } }
            }
            let legal = (-6...6).flatMap { x in (0...8).compactMap { y in visible(x, y) ? (x, y) : nil } }
            for x in -7...7 {
                for y in -1...9 {
                    let frame = Rect(x: Double(x), y: Double(y), width: 3, height: 2)
                    XCTAssertEqual(desktop.contains(frame), visible(x, y))
                    let placed = try XCTUnwrap(desktop.place(frame))
                    let nearest = legal.map { hypot(Double($0.0 - x), Double($0.1 - y)) }.min()!
                    XCTAssertEqual(hypot(placed.x - frame.x, placed.y - frame.y), nearest, accuracy: 1e-9)
                    if visible(x, y) {
                        for (dx, dy) in [(-12, -12), (12, 12), (-12, 12), (12, -12)] {
                            var xx = x, yy = y
                            for _ in 0..<abs(dx) { if visible(xx + (dx < 0 ? -1 : 1), yy) { xx += dx < 0 ? -1 : 1 } }
                            for _ in 0..<abs(dy) { if visible(xx, yy + (dy < 0 ? -1 : 1)) { yy += dy < 0 ? -1 : 1 } }
                            XCTAssertEqual(desktop.move(frame, by: Vector(x: Double(dx), y: Double(dy))),
                                           Rect(x: Double(xx), y: Double(yy), width: 3, height: 2))
                        }
                    }
                }
            }
        }
    }

    private func make(_ bounds: [Rect]) -> Desktop {
        Desktop(displays: bounds.enumerated().map { DisplayArea(id: String($0.offset), bounds: $0.element) })
    }
}
