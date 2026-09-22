import XCTest
@testable import RadialCore

final class GeometryTests: XCTestCase {
    func testEveryGeneratedBoundaryBelongsToItsClockwiseSector() {
        for count in 2...12 {
            for sector in Geometry.sectors(count: count) {
                XCTAssertEqual(Geometry.sector(angle: sector.start, count: count), sector.index,
                               "count=\(count), index=\(sector.index)")
                XCTAssertEqual(Geometry.sector(angle: sector.start - 1e-8, count: count),
                               (sector.index + count - 1) % count)
                XCTAssertEqual(Geometry.sector(angle: sector.center, count: count), sector.index)
            }
        }
    }

    func testCardinalDirectionsAndExactBoundaryOwnership() {
        XCTAssertEqual(Geometry.sector(angle: 0, count: 4), 0)
        XCTAssertEqual(Geometry.sector(angle: .pi / 2, count: 4), 1)
        XCTAssertEqual(Geometry.sector(angle: .pi, count: 4), 2)
        XCTAssertEqual(Geometry.sector(angle: 3 * .pi / 2, count: 4), 3)
        XCTAssertEqual(Geometry.sector(angle: .pi / 4, count: 4), 1)
        XCTAssertEqual(Geometry.sector(angle: .pi / 4 - 1e-8, count: 4), 0)
        XCTAssertEqual(Geometry.sector(angle: -.pi / 4, count: 4), 0)
    }

    func testSingleItemAndCenterAndOuterBoundaries() {
        for degree in 0..<360 {
            XCTAssertEqual(Geometry.sector(angle: Double(degree) * .pi / 180, count: 1), 0)
        }
        XCTAssertNil(Geometry.hit(Vector(x: 0, y: 0), inner: 0, outer: 100, count: 1))
        XCTAssertNil(Geometry.hit(Vector(x: 20, y: 0), inner: 20, outer: 100, count: 4))
        XCTAssertEqual(Geometry.hit(Vector(x: 100, y: 0), inner: 20, outer: 100, count: 4), 1)
        XCTAssertNil(Geometry.hit(Vector(x: 101, y: 0), inner: 20, outer: 100, count: 4))
        XCTAssertNil(Geometry.sector(angle: .nan, count: 4))
        XCTAssertNil(Geometry.sector(angle: .infinity, count: 4))
    }

    func testMenuValidationRejectsEmptyDuplicatesAndUnboundedLabels() throws {
        XCTAssertThrowsError(try Menu(id: "empty", title: "Empty", items: []))
        XCTAssertThrowsError(try Menu(id: "root", title: "Root", items: [
            Item(id: "x", label: "One", value: "1"), Item(id: "x", label: "Two", value: "2")
        ]))
        XCTAssertThrowsError(try Menu(id: "root", title: "Root", items: [
            Item(id: "x", label: String(repeating: "a", count: 200), value: "1")
        ]))
    }

    func testPlacementUsesCompleteBoundsAndHandlesNegativeScreenCoordinates() {
        let screen = Rect(x: -1000, y: 100, width: 1000, height: 700)
        XCTAssertEqual(Geometry.place(center: Vector(x: -999, y: 799), diameter: 400, in: screen),
                       Rect(x: -1000, y: 400, width: 400, height: 400))
        XCTAssertNil(Geometry.place(center: .zero, diameter: 1001, in: screen))
    }
}
