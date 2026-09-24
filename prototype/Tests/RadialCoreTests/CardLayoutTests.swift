import XCTest
@testable import RadialCore

final class CardLayoutTests: XCTestCase {
    func testCardsWithUnequalTextSizesDoNotOverlapOrObscureConnections() throws {
        let profiles = [Size(width: 260, height: 50), Size(width: 260, height: 320),
                        Size(width: 520, height: 120), Size(width: 120, height: 520)]
        for count in 1...12 {
            for rotation in profiles.indices {
                let sizes = (0..<count).map { profiles[($0 + rotation) % profiles.count] }
                let layout = try make(sizes)
                let guide = try XCTUnwrap(layout.directionGuide)
                for (index, label) in layout.labels.enumerated() {
                    let r = label.bounds
                    XCTAssertEqual(layout.hit(Vector(x: r.x + r.width / 2, y: r.y + r.height / 2)), index)
                    XCTAssertEqual(r.width, sizes[index].width)
                    XCTAssertEqual(r.height, sizes[index].height)
                    XCTAssertLessThan(abs(r.x), layout.diameter / 2)
                    XCTAssertLessThan(abs(r.y), layout.diameter / 2)
                    XCTAssertLessThan(abs(r.x + r.width), layout.diameter / 2)
                    XCTAssertLessThan(abs(r.y + r.height), layout.diameter / 2)
                    for other in layout.labels where other.itemID != label.itemID {
                        let b = other.bounds
                        XCTAssertTrue(r.x + r.width < b.x || b.x + b.width < r.x ||
                                      r.y + r.height < b.y || b.y + b.height < r.y)
                    }
                    for connection in guide.connections where connection.itemID != label.itemID {
                        XCTAssertFalse(intersects(connection.marker, connection.labelEdge, r))
                    }
                }
                XCTAssertNil(layout.hit(.zero))
                XCTAssertNil(layout.hit(Vector(x: .nan, y: 0)))
                for marker in guide.connections.map(\.marker) { XCTAssertNil(layout.hit(marker)) }
            }
        }
    }

    func testThinCardsFitWithoutReservingEmptySectorCorners() throws {
        let layout = try make(Array(repeating: Size(width: 261, height: 69), count: 12))
        XCTAssertLessThan(layout.diameter, 1410)
        let screen = ScreenContext(revision: 1, screenID: "left",
            bounds: Rect(x: -2560, y: 0, width: 2560, height: 1410), anchor: .zero)
        XCTAssertNoThrow(try layout.placement(in: screen))
        XCTAssertEqual(layout.fontSize, 17)
    }

    func testWideCardCannotCoverTheConnectionToANeighboringSmallCard() throws {
        var sizes = Array(repeating: Size(width: 20, height: 20), count: 8)
        sizes[2] = Size(width: 800, height: 400)
        let layout = try make(sizes)
        let guide = try XCTUnwrap(layout.directionGuide)
        let wide = layout.labels[2].bounds
        for index in [1, 3] {
            let connection = guide.connections[index]
            XCTAssertFalse(intersects(connection.marker, connection.labelEdge, wide))
        }
    }

    func testLongDescriptionBoundsCanFailWithoutChangingTextSize() throws {
        let layout = try make(Array(repeating: Size(width: 260, height: 2000), count: 12))
        XCTAssertThrowsError(try layout.placement(in: ScreenContext(revision: 1, screenID: "screen",
            bounds: Rect(x: 0, y: 0, width: 2560, height: 1410), anchor: .zero))) {
            XCTAssertEqual($0 as? LayoutFailure, .doesNotFit)
        }
        XCTAssertEqual(layout.fontSize, 17)
        XCTAssertEqual(layout.labels[0].bounds.height, 2000)
    }

    private func make(_ sizes: [Size]) throws -> MenuLayout {
        let menu = try Menu(id: "menu", title: "Cards", items: sizes.indices.map {
            Item(id: "\($0)", label: "Item", title: "A complete title", detail: "A complete description.", value: "\($0)")
        })
        return try MenuLayout.make(menu: menu, measurements: MenuMeasurements(fontSize: 17, wrappingWidth: 260,
            labels: sizes.enumerated().map { LabelMeasurement(itemID: "\($0.offset)", normal: $0.element, selected: $0.element) },
            center: Size(width: 39, height: 36), style: .cards))
    }

    /// Clip the finite segment to the rectangle; independent of the solver's
    /// projection tests and radius calculation.
    private func intersects(_ start: Vector, _ end: Vector, _ rectangle: Rect) -> Bool {
        var lower = 0.0, upper = 1.0
        for (a, b, minimum, length) in [(start.x, end.x, rectangle.x, rectangle.width),
                                        (start.y, end.y, rectangle.y, rectangle.height)] {
            let delta = b - a
            if abs(delta) < 1e-12 {
                if a < minimum || a > minimum + length { return false }
            } else {
                let first = (minimum - a) / delta, last = (minimum + length - a) / delta
                lower = max(lower, min(first, last)); upper = min(upper, max(first, last))
                if lower > upper { return false }
            }
        }
        return true
    }
}
