import XCTest
@testable import RadialCore

final class IconLabelLayoutTests: XCTestCase {
    func testIconsRemainSeparatedAlignedAndOutsidePointerTargets() throws {
        for count in 1...12 {
            for size in [Size(width: 18, height: 20), Size(width: 60, height: 80)] {
                let menu = try menu(count)
                let layout = try MenuLayout.make(menu: menu, measurements: measurements(menu, glyph: size))
                let ring = try XCTUnwrap(layout.iconRing)
                XCTAssertNil(layout.directionGuide)
                XCTAssertEqual(layout.centerBounds, Rect(x: 0, y: 0, width: 0, height: 0))
                XCTAssertEqual(layout.centerRadius, 0)
                XCTAssertNil(layout.hit(.zero))
                XCTAssertEqual(ring.icons.map(\.itemID), menu.items.map(\.id))
                XCTAssertGreaterThan(ring.badgeRadius, hypot(size.width, size.height) / 2)
                for (index, icon) in ring.icons.enumerated() {
                    XCTAssertEqual(hypot(icon.center.x, icon.center.y), ring.radius, accuracy: 1e-8)
                    XCTAssertEqual(Geometry.sector(angle: atan2(icon.center.x, -icon.center.y), count: count), index)
                    XCTAssertNil(layout.hit(icon.center))
                    for other in ring.icons where other.itemID != icon.itemID {
                        XCTAssertGreaterThan(hypot(icon.center.x - other.center.x, icon.center.y - other.center.y), 2 * ring.badgeRadius)
                    }
                    let r = layout.labels[index].bounds
                    let nearest = Vector(x: min(max(0, r.x), r.x + r.width), y: min(max(0, r.y), r.y + r.height))
                    XCTAssertGreaterThan(hypot(nearest.x, nearest.y), ring.radius + ring.badgeRadius)
                    XCTAssertEqual(layout.hit(Vector(x: r.x + r.width / 2, y: r.y + r.height / 2)), index)
                }
            }
        }
    }

    func testSelectedGlyphSizeAndMeasurementIdentityDetermineReservedSpace() throws {
        let menu = try menu(12)
        let small = try MenuLayout.make(menu: menu, measurements: measurements(menu))
        let big = try MenuLayout.make(menu: menu, measurements: measurements(menu, selected: Size(width: 120, height: 100)))
        XCTAssertGreaterThan(big.iconRing!.badgeRadius, small.iconRing!.badgeRadius)
        XCTAssertGreaterThan(big.iconRing!.radius, small.iconRing!.radius)
        let measured = measurements(menu)
        let reordered = MenuMeasurements(fontSize: measured.fontSize, wrappingWidth: measured.wrappingWidth,
            labels: measured.labels.reversed(), content: .empty, style: .iconLabels, icons: measured.icons.reversed())
        XCTAssertEqual(try MenuLayout.make(menu: menu, measurements: reordered), small)
    }

    func testRejectsMissingDuplicateUnknownNonfiniteAndEmptyIconMeasurements() throws {
        let menu = try menu(4), measured = measurements(menu)
        for invalid in [[], Array(measured.icons.dropLast()), Array(repeating: measured.icons[0], count: 4),
                        [LabelMeasurement(itemID: "wrong", normal: Size(width: 20, height: 20), selected: Size(width: 20, height: 20))] + measured.icons.dropFirst(),
                        [LabelMeasurement(itemID: "0", normal: Size(width: .nan, height: 20), selected: Size(width: 20, height: 20))] + measured.icons.dropFirst(),
                        [LabelMeasurement(itemID: "0", normal: Size(width: 20, height: 20), selected: Size(width: 0, height: 20))] + measured.icons.dropFirst()] {
            let value = MenuMeasurements(fontSize: 17, wrappingWidth: 226, labels: measured.labels,
                                         content: .empty, style: .iconLabels, icons: invalid)
            XCTAssertThrowsError(try MenuLayout.make(menu: menu, measurements: value))
        }
    }

    func testEmptyCenterAndIconMeasurementsBelongOnlyToIconLabels() throws {
        let menu = try menu(4), measured = measurements(menu)
        for style in MenuStyle.allCases where style != .iconLabels {
            let empty = MenuMeasurements(fontSize: 17, wrappingWidth: 226, labels: measured.labels,
                                         content: .empty, style: style, icons: measured.icons)
            XCTAssertThrowsError(try MenuLayout.make(menu: menu, measurements: empty))
        }
        let control = MenuMeasurements(fontSize: 17, wrappingWidth: 226, labels: measured.labels,
                                       center: Size(width: 40, height: 40), style: .iconLabels)
        XCTAssertThrowsError(try MenuLayout.make(menu: menu, measurements: control))
    }

    private func menu(_ count: Int) throws -> Menu {
        try Menu(id: "root", title: "Icons", items: (0..<count).map { Item(id: "\($0)", label: "Action", value: "\($0)") })
    }

    private func measurements(_ menu: Menu, glyph: Size = Size(width: 18, height: 20),
                              selected: Size = Size(width: 20, height: 22)) -> MenuMeasurements {
        MenuMeasurements(fontSize: 17, wrappingWidth: 226, labels: menu.items.map {
            LabelMeasurement(itemID: $0.id, normal: Size(width: 226, height: 60), selected: Size(width: 226, height: 80))
        }, content: .empty, style: .iconLabels, icons: menu.items.map {
            LabelMeasurement(itemID: $0.id, normal: glyph, selected: selected)
        })
    }
}
