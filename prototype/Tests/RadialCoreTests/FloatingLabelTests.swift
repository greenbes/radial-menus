import XCTest
@testable import RadialCore

final class FloatingLabelTests: XCTestCase {
    func testWrapsAtWordBoundariesCountingSpacesAndKeepsLongWordsWhole() {
        XCTAssertEqual(TitleLines.wrap("123456789 1234567890"), ["123456789 1234567890"])
        XCTAssertEqual(TitleLines.wrap("1234567890 1234567890"), ["1234567890", "1234567890"])
        XCTAssertEqual(TitleLines.wrap("Open recent documents in the research workspace."),
                       ["Open recent", "documents in the", "research workspace."])
        let long = "Supercalifragilisticexpialidocious"
        XCTAssertEqual(TitleLines.wrap("Before \(long) after"), ["Before", long, "after"])
        XCTAssertEqual(TitleLines.wrap("  one\t two\n\nthree\r\nfour  "), ["one two", "", "three", "four"])
    }

    func testCharacterLimitCountsVisibleCharactersWithoutSplittingEmojiOrAccents() {
        let word = String(repeating: "👩🏽‍💻", count: 9)
        let accents = String(repeating: "e\u{301}", count: 10)
        XCTAssertEqual(TitleLines.wrap(word + " " + accents), [word + " " + accents])
        XCTAssertEqual(TitleLines.wrap(word + " " + accents + "é"), [word, accents + "é"])
        XCTAssertEqual(TitleLines.wrap(String(repeating: "界", count: 24)), [String(repeating: "界", count: 24)])
    }

    func testRoundedBoundariesTouchCommonCircleAndBoxesStaySeparated() throws {
        for count in 1...12 {
            for font in [17.0, 34.0] {
                let (menu, measured) = try fixture(count: count, font: font)
                let layout = try MenuLayout.make(menu: menu, measurements: measured)
                XCTAssertNil(layout.directionGuide)
                XCTAssertNil(layout.iconRing)
                XCTAssertEqual(layout.centerRadius, 0)
                XCTAssertNil(layout.hit(.zero))
                for (index, label) in layout.labels.enumerated() {
                    let box = label.bounds, corner = label.cornerRadius
                    let center = Vector(x: box.x + box.width / 2, y: box.y + box.height / 2)
                    // Independently project the origin onto the inset rectangle,
                    // then advance by the corner radius toward the origin.
                    let q = Vector(x: min(max(0, box.x + corner), box.x + box.width - corner),
                                   y: min(max(0, box.y + corner), box.y + box.height - corner))
                    let distance = hypot(q.x, q.y)
                    let nearest = Vector(x: q.x * (1 - corner / distance), y: q.y * (1 - corner / distance))
                    XCTAssertEqual(hypot(nearest.x, nearest.y), layout.labelRadius, accuracy: 1e-8)
                    let angle = Double(index) * 2 * .pi / Double(count)
                    XCTAssertEqual(nearest.x, sin(angle) * layout.labelRadius, accuracy: 1e-8)
                    XCTAssertEqual(nearest.y, -cos(angle) * layout.labelRadius, accuracy: 1e-8)
                    XCTAssertEqual(box.width, measured.labels[index].selected.width)
                    XCTAssertEqual(box.height, measured.labels[index].selected.height)
                    XCTAssertEqual(layout.hit(center), index)
                    XCTAssertNil(layout.hit(Vector(x: box.x + 0.1, y: box.y + 0.1)))
                    XCTAssertGreaterThanOrEqual(box.x, -layout.size.width / 2)
                    XCTAssertLessThanOrEqual(box.x + box.width, layout.size.width / 2)
                    XCTAssertGreaterThanOrEqual(box.y, -layout.size.height / 2)
                    XCTAssertLessThanOrEqual(box.y + box.height, layout.size.height / 2)
                    for other in layout.labels.dropFirst(index + 1) {
                        let b = other.bounds
                        let horizontal = max(b.x - box.x - box.width, box.x - b.x - b.width)
                        let vertical = max(b.y - box.y - box.height, box.y - b.y - b.height)
                        XCTAssertGreaterThanOrEqual(max(horizontal, vertical), 8 - 1e-8)
                    }
                }
            }
        }
    }

    func testVariableWidthsAndRectangularPlacementPreserveContent() throws {
        let (menu, measurements) = try fixture(count: 4)
        let layout = try MenuLayout.make(menu: menu, measurements: measurements)
        XCTAssertEqual(Set(layout.labels.map { $0.bounds.width }).count, 4)
        XCTAssertNotEqual(layout.size.width, layout.size.height)
        let screen = ScreenContext(revision: 1, screenID: "test",
            bounds: Rect(x: -1200, y: 70, width: layout.size.width + 20, height: layout.size.height + 40),
            anchor: Vector(x: 10000, y: -10000))
        let placed = try layout.placement(in: screen)
        XCTAssertEqual(placed.frame, Rect(x: -1180, y: 70, width: layout.size.width, height: layout.size.height))
        XCTAssertThrowsError(try layout.placement(in: ScreenContext(revision: 1, screenID: "small",
            bounds: Rect(x: 0, y: 0, width: layout.size.width - 1, height: layout.size.height), anchor: .zero)))
        let reordered = MenuMeasurements(fontSize: 17, wrappingWidth: measurements.wrappingWidth,
            labels: measurements.labels.reversed(), content: .empty, style: .floatingLabels)
        XCTAssertEqual(try MenuLayout.make(menu: menu, measurements: reordered), layout)
    }

    func testRejectsCenterControlAndOverflowRatherThanProducingInvalidLayout() throws {
        let (menu, measurements) = try fixture(count: 4)
        XCTAssertThrowsError(try MenuLayout.make(menu: menu, measurements: MenuMeasurements(
            fontSize: 17, wrappingWidth: 200, labels: measurements.labels,
            center: Size(width: 40, height: 40), style: .floatingLabels)))
        let enormous = menu.items.map { LabelMeasurement(itemID: $0.id,
            normal: Size(width: .greatestFiniteMagnitude, height: 50),
            selected: Size(width: .greatestFiniteMagnitude, height: 50)) }
        XCTAssertThrowsError(try MenuLayout.make(menu: menu, measurements: MenuMeasurements(
            fontSize: 17, wrappingWidth: 200, labels: enormous, content: .empty, style: .floatingLabels)))
    }

    private func fixture(count: Int, font: Double = 17) throws -> (Menu, MenuMeasurements) {
        let menu = try Menu(id: "root", title: "Floating", items: (0..<count).map {
            Item(id: "\($0)", label: "Item \($0)", value: "\($0)")
        })
        let sizes = menu.items.enumerated().map { index, item in
            LabelMeasurement(itemID: item.id,
                normal: Size(width: Double(80 + index * 23), height: Double(40 + index % 4 * 21)),
                selected: Size(width: Double(90 + index * 23), height: Double(45 + index % 4 * 21)))
        }
        return (menu, MenuMeasurements(fontSize: font, wrappingWidth: 400, labels: sizes,
                                       content: .empty, style: .floatingLabels))
    }
}
