import XCTest
@testable import RadialCore

final class FullLabelLayoutTests: XCTestCase {
    func testFullLabelsAndConnectionsRemainSeparateForEverySupportedCount() throws {
        for count in 1...12 {
            for size in [Size(width: 226, height: 46), Size(width: 226, height: 160), Size(width: 452, height: 240)] {
                let layout = try make(count: count, size: size)
                let guide = try XCTUnwrap(layout.directionGuide)
                XCTAssertGreaterThan(guide.radius - guide.markerRadius, layout.centerRadius)
                for (index, connection) in guide.connections.enumerated() {
                    let r = layout.labels[index].bounds
                    XCTAssertEqual(connection.itemID, layout.labels[index].itemID)
                    XCTAssertEqual(hypot(connection.marker.x, connection.marker.y), guide.radius, accuracy: 1e-8)
                    XCTAssertEqual(Geometry.sector(angle: atan2(connection.marker.x, -connection.marker.y), count: count), index)
                    let p = connection.labelEdge
                    XCTAssertTrue(p.x >= r.x - 1e-8 && p.x <= r.x + r.width + 1e-8)
                    XCTAssertTrue(p.y >= r.y - 1e-8 && p.y <= r.y + r.height + 1e-8)
                    XCTAssertTrue([abs(p.x - r.x), abs(p.x - r.x - r.width),
                                   abs(p.y - r.y), abs(p.y - r.y - r.height)].min()! < 1e-8)
                    // Sampling the whole visible connection catches wrong endpoints
                    // and crossings, independently of the layout's sector formula.
                    for step in 0..<100 {
                        let t = Double(step) / 100
                        let point = Vector(x: connection.marker.x + (p.x - connection.marker.x) * t,
                                           y: connection.marker.y + (p.y - connection.marker.y) * t)
                        XCTAssertNil(layout.hit(point))
                    }
                    let nearest = Vector(x: min(max(0, r.x), r.x + r.width), y: min(max(0, r.y), r.y + r.height))
                    XCTAssertGreaterThan(hypot(nearest.x, nearest.y), guide.radius + guide.markerRadius)
                    for other in layout.labels where other.itemID != connection.itemID {
                        let b = other.bounds
                        XCTAssertTrue(r.x + r.width < b.x || b.x + b.width < r.x ||
                                      r.y + r.height < b.y || b.y + b.height < r.y)
                    }
                    for x in [r.x, r.x + r.width] {
                        for y in [r.y, r.y + r.height] {
                            XCTAssertLessThan(abs(x), layout.diameter / 2)
                            XCTAssertLessThan(abs(y), layout.diameter / 2)
                        }
                    }
                }
            }
        }
    }

    func testLongerTitlesMoveLabelsWithoutExpandingTheDirectionRing() throws {
        let short = try make(count: 6, size: Size(width: 226, height: 46))
        let long = try make(count: 6, size: Size(width: 226, height: 160))
        XCTAssertEqual(short.directionGuide?.radius, long.directionGuide?.radius)
        XCTAssertEqual(short.directionGuide?.connections.map(\.marker), long.directionGuide?.connections.map(\.marker))
        XCTAssertGreaterThan(long.labelRadius, short.labelRadius)
        XCTAssertGreaterThan(long.diameter, short.diameter)
        XCTAssertEqual(long.fontSize, 17)
    }

    func testOnlyFullLabelRectanglesArePointerTargets() throws {
        let layout = try make(count: 6, size: Size(width: 226, height: 80))
        XCTAssertNil(layout.hit(.zero))
        XCTAssertNil(layout.hit(Vector(x: .infinity, y: 0)))
        XCTAssertNil(layout.hit(Vector(x: 0, y: .nan)))
        for (index, label) in layout.labels.enumerated() {
            let r = label.bounds
            XCTAssertEqual(layout.hit(Vector(x: r.x + r.width / 2, y: r.y + r.height / 2)), index)
            XCTAssertEqual(layout.hit(Vector(x: r.x, y: r.y)), index)
            XCTAssertNil(layout.hit(Vector(x: r.x - 0.1, y: r.y)))
        }
    }

    func testMeasurementStyleMustAgreeWithCenterContent() throws {
        let menu = SampleMenu.definition
        let labels = TestPresentation.measurements(menu).labels
        for style in MenuStyle.allCases where style != .selectedMessage {
            let invalid = MenuMeasurements(fontSize: 17, wrappingWidth: 226, labels: labels,
                content: .messages(wrappingWidth: 300, states: MenuMessage.all(in: menu).map {
                    MessageMeasurement(itemID: $0.itemID, size: Size(width: 300, height: 100))
                }), style: style)
            XCTAssertThrowsError(try MenuLayout.make(menu: menu, measurements: invalid))
        }
        let invalid = MenuMeasurements(fontSize: 17, wrappingWidth: 226, labels: labels,
                                       center: Size(width: 36, height: 32), style: .selectedMessage)
        XCTAssertThrowsError(try MenuLayout.make(menu: menu, measurements: invalid))
    }

    func testFullLabelsKeepTextSizeAndFailWhenScreenIsTooSmall() throws {
        let layout = try make(count: 12, size: Size(width: 226, height: 160))
        XCTAssertThrowsError(try layout.placement(in: ScreenContext(revision: 1, screenID: "small",
            bounds: Rect(x: 0, y: 0, width: 360, height: 360), anchor: .zero))) {
            XCTAssertEqual($0 as? LayoutFailure, .doesNotFit)
        }
        XCTAssertEqual(layout.fontSize, 17)
    }

    private func make(count: Int, size: Size) throws -> MenuLayout {
        let menu = try Menu(id: "menu", title: "Actions", items: (0..<count).map {
            Item(id: "\($0)", label: "Short", title: "An entire title for action \($0)", value: "\($0)")
        })
        let measurements = MenuMeasurements(fontSize: 17, wrappingWidth: size.width,
            labels: menu.items.map { LabelMeasurement(itemID: $0.id, normal: size, selected: size) },
            center: Size(width: 36, height: 32), style: .fullLabels)
        return try MenuLayout.make(menu: menu, measurements: measurements)
    }
}
