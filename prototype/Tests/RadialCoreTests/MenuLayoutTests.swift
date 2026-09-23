import XCTest
@testable import RadialCore

final class MenuLayoutTests: XCTestCase {
    func testShortFourItemMenuRetainsMinimumGeometry() throws {
        let menu = try fixture(count: 4)
        let layout = try MenuLayout.make(menu: menu, measurements: measurements(menu))
        XCTAssertEqual(layout.innerRadius, 46)
        XCTAssertEqual(layout.outerRadius, 150)
        XCTAssertEqual(layout.labelRadius, 100)
        XCTAssertEqual(layout.diameter, 360)
    }

    func testMeasuredRectanglesFitRingAndSectorsForEverySupportedCount() throws {
        for count in 1...12 {
            for size in [Size(width: 20, height: 20), Size(width: 96, height: 100), Size(width: 48, height: 240)] {
                let menu = try fixture(count: count)
                let layout = try MenuLayout.make(menu: menu, measurements: measurements(menu, size: size))
                for (index, label) in layout.labels.enumerated() {
                    let r = label.bounds
                    XCTAssertEqual(r.width, size.width)
                    XCTAssertEqual(r.height, size.height)
                    let nearestX = min(max(0, r.x), r.x + r.width)
                    let nearestY = min(max(0, r.y), r.y + r.height)
                    XCTAssertGreaterThan(hypot(nearestX, nearestY), layout.innerRadius)
                    for x in [r.x, r.x + r.width] {
                        for y in [r.y, r.y + r.height] {
                            XCTAssertLessThan(hypot(x, y), layout.outerRadius)
                            if count > 1 {
                                let angle = atan2(x, -y) - Double(index) * 2 * .pi / Double(count)
                                let distance = abs(atan2(sin(angle), cos(angle)))
                                XCTAssertLessThan(distance, .pi / Double(count))
                            }
                        }
                    }
                }
                for a in layout.labels.indices {
                    for b in layout.labels.indices where b > a {
                        let x = layout.labels[a].bounds, y = layout.labels[b].bounds
                        let overlapX = min(x.x + x.width, y.x + y.width) - max(x.x, y.x)
                        let overlapY = min(x.y + x.height, y.y + y.height) - max(x.y, y.y)
                        XCTAssertTrue(overlapX <= 0 || overlapY <= 0)
                    }
                }
            }
        }
    }

    func testSelectedWeightAndMeasurementIdentityDetermineBounds() throws {
        let menu = try fixture(count: 2)
        let measurements = MenuMeasurements(fontSize: 25, wrappingWidth: 120, labels: [
            LabelMeasurement(itemID: "1", normal: Size(width: 10, height: 20), selected: Size(width: 60, height: 80)),
            LabelMeasurement(itemID: "0", normal: Size(width: 40, height: 30), selected: Size(width: 35, height: 50))
        ], center: Size(width: 30, height: 30))
        let layout = try MenuLayout.make(menu: menu, measurements: measurements)
        XCTAssertEqual(layout.labels.map(\.itemID), ["0", "1"])
        XCTAssertEqual(layout.labels[0].bounds.width, 40)
        XCTAssertEqual(layout.labels[0].bounds.height, 50)
        XCTAssertEqual(layout.labels[1].bounds.height, 80)
        XCTAssertEqual(layout.fontSize, 25)
        XCTAssertEqual(layout.wrappingWidth, 120)
    }

    func testLargeCenterContentExpandsTheInnerRing() throws {
        let menu = try fixture(count: 4)
        let measured = MenuMeasurements(fontSize: 34, wrappingWidth: 96, labels: measurements(menu).labels,
                                        center: Size(width: 160, height: 120))
        let layout = try MenuLayout.make(menu: menu, measurements: measured)
        XCTAssertGreaterThanOrEqual(layout.centerRadius, 108)
        XCTAssertGreaterThan(layout.innerRadius, layout.centerRadius)
        XCTAssertGreaterThan(layout.labelRadius, layout.innerRadius)
    }

    func testExpandedRingControlsHitTestingAndFitsNegativeScreenCoordinates() throws {
        let menu = try fixture(count: 12)
        let layout = try MenuLayout.make(menu: menu, measurements: measurements(menu, size: Size(width: 96, height: 100)))
        XCTAssertGreaterThan(layout.outerRadius, 250)
        XCTAssertEqual(layout.hit(Vector(x: 0, y: -250)), 0)
        XCTAssertNil(layout.hit(Vector(x: 0, y: -layout.outerRadius - 0.01)))
        XCTAssertNil(layout.hit(.zero))
        let bounds = Rect(x: -2000, y: -500, width: 1600, height: 1200)
        let placed = try layout.placement(in: ScreenContext(revision: 3, screenID: "left", bounds: bounds,
                                                           anchor: Vector(x: -2000, y: -500)))
        XCTAssertEqual(placed.frame.x, -2000)
        XCTAssertEqual(placed.frame.y, -500)
        XCTAssertEqual(placed.frame.width, layout.diameter)
        XCTAssertTrue(placed.isValid)
    }

    func testInsufficientScreenSpaceFailsInsteadOfShrinkingText() throws {
        let menu = try fixture(count: 12)
        let layout = try MenuLayout.make(menu: menu, measurements: measurements(menu, size: Size(width: 96, height: 100)))
        XCTAssertThrowsError(try layout.placement(in: ScreenContext(revision: 1, screenID: "small",
            bounds: Rect(x: 0, y: 0, width: 360, height: 360), anchor: .zero))) {
            XCTAssertEqual($0 as? LayoutFailure, .doesNotFit)
        }
        XCTAssertEqual(layout.fontSize, 17)
    }

    func testMissingDuplicateInvalidAndOverflowingMeasurementsAreRejected() throws {
        let menu = try fixture(count: 2), valid = measurements(try fixture(count: 2))
        let badLabels = [[], Array(valid.labels.prefix(1)), [valid.labels[0], valid.labels[0]],
                         [LabelMeasurement(itemID: "0", normal: Size(width: .nan, height: 20), selected: Size(width: 10, height: 20)), valid.labels[1]]]
        for labels in badLabels {
            XCTAssertThrowsError(try MenuLayout.make(menu: menu, measurements: MenuMeasurements(
                fontSize: 17, wrappingWidth: 96, labels: labels, center: Size(width: 30, height: 30))))
        }
        XCTAssertThrowsError(try MenuLayout.make(menu: menu, measurements: measurements(menu,
            size: Size(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude))))
        XCTAssertThrowsError(try LayoutSettings(minimumInnerRadius: 46, minimumOuterRadius: 150,
            minimumLabelRadius: 100, contentPadding: .nan, windowPadding: 30))
    }

    private func fixture(count: Int) throws -> Menu {
        try Menu(id: "menu", title: "Layout", items: (0..<count).map { Item(id: String($0), label: "Item \($0)", value: String($0)) })
    }

    private func measurements(_ menu: Menu, size: Size = Size(width: 30, height: 20)) -> MenuMeasurements {
        MenuMeasurements(fontSize: 17, wrappingWidth: 96,
            labels: menu.items.map { LabelMeasurement(itemID: $0.id, normal: size, selected: size) },
            center: Size(width: 36, height: 32))
    }
}
