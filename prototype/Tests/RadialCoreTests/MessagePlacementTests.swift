import XCTest
@testable import RadialCore

final class MessagePlacementTests: XCTestCase {
    func testCardUsesLowerThirdWithBackCenteredBelowIt() throws {
        let placement = try XCTUnwrap(MessagePlacement.make(card: Size(width: 240, height: 80),
            back: Size(width: 80, height: 24), radius: 360, spacing: 10, padding: 8))
        XCTAssertEqual(placement.card, Rect(x: -120, y: 200, width: 240, height: 80))
        XCTAssertEqual(placement.back, Rect(x: -40, y: 290, width: 80, height: 24))
        let root = try XCTUnwrap(MessagePlacement.make(card: Size(width: 240, height: 80),
            back: nil, radius: 360, spacing: 10, padding: 8))
        XCTAssertEqual(root.card, placement.card)
        XCTAssertNil(root.back)
    }

    func testMinimumRingFitsCompleteCardAndBackWithoutMovingAboveLowerThird() throws {
        for card in [Size(width: 300, height: 150), Size(width: 600, height: 300), Size(width: 180, height: 400)] {
            for back in [nil, Size(width: 90, height: 30), Size(width: 320, height: 50)] {
                let minimum = MessagePlacement.minimumRadius(card: card, back: back, spacing: 12, padding: 8)
                XCTAssertNil(MessagePlacement.make(card: card, back: back, radius: minimum - 0.01, spacing: 12, padding: 8))
                for radius in [minimum, minimum * 1.2, minimum * 2] {
                    let placement = try XCTUnwrap(MessagePlacement.make(card: card, back: back,
                        radius: radius, spacing: 12, padding: 8))
                    let center = placement.card.y + placement.card.height / 2
                    XCTAssertGreaterThanOrEqual(center, radius / 3 - 1e-8)
                    XCTAssertLessThanOrEqual(center, 2 * radius / 3)
                    if let control = placement.back {
                        XCTAssertEqual(control.y - placement.card.y - placement.card.height, 12, accuracy: 1e-8)
                        XCTAssertEqual(control.x + control.width / 2, 0)
                    }
                    for box in [placement.card] + [placement.back].compactMap({ $0 }) {
                        for x in [box.x, box.x + box.width] {
                            for y in [box.y, box.y + box.height] {
                                XCTAssertLessThanOrEqual(hypot(x, y), radius - 8 + 1e-8)
                            }
                        }
                    }
                }
            }
        }
    }

    func testInvalidBackMeasurementIsRejectedBeforeLayout() {
        let menu = SampleMenu.definition
        let measured = MenuMeasurements(fontSize: 17, wrappingWidth: 150,
            labels: TestPresentation.measurements(menu).labels,
            content: .messages(wrappingWidth: 300, states: MenuMessage.all(in: menu).map {
                MessageMeasurement(itemID: $0.itemID, size: Size(width: 300, height: 120))
            }, back: Size(width: .nan, height: 30)), style: .selectedMessage)
        XCTAssertThrowsError(try MenuLayout.make(menu: menu, measurements: measured))
    }
}
