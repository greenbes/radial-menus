import XCTest
@testable import RadialCore

final class MenuStyleTests: XCTestCase {
    func testStylePreferenceIsCapturedOnOpeningAndPreservedThroughNavigation() throws {
        var model = Model(menu: SampleMenu.definition)
        model = update(model, .setMenuStyle(.selectedMessage)).model
        let opened = update(model, .open(nil))
        model = opened.model
        let scope = try XCTUnwrap(model.phase.session?.scope)
        XCTAssertEqual(opened.effects, [.prepare(scope, model.phase.session!.presentation, model.phase.operation!)])
        model = update(model, .setMenuStyle(.pie)).model
        XCTAssertEqual(model.phase.session?.style, .selectedMessage)
        model = prepared(model)
        let layout = model.phase.session?.layout
        model = update(model, .activate(scope, "more", .keyboard)).model
        XCTAssertEqual(model.phase.session?.style, .selectedMessage)
        model = prepared(model)
        XCTAssertEqual(model.phase.session?.layout?.style, .selectedMessage)
        model = update(model, .back(model.phase.session!.scope)).model
        model = prepared(model)
        XCTAssertEqual(model.phase.session?.layout, layout)
        model = update(model, .cancel(model.phase.session!.scope, .user)).model
        model = update(model, .dismissed(model.phase.operation!)).model
        model = update(model, .open(nil)).model
        XCTAssertEqual(model.phase.session?.style, .pie)
        XCTAssertEqual(model.menuStyle, .pie)
    }

    func testWrongStyleMeasurementsCannotPresent() {
        let opening = update(Model(menu: SampleMenu.definition, menuStyle: .selectedMessage), .open(nil)).model
        let result = update(opening, TestPresentation.prepared(opening))
        guard case .dismissing(_, _, .failed(let failure)) = result.model.phase else { return XCTFail() }
        XCTAssertEqual(failure.message, LayoutFailure.invalidMeasurements.message)
        XCTAssertFalse(result.effects.contains { if case .present = $0 { true } else { false } })
    }

    func testStylePreferenceDoesNotChangeAfterShutdown() {
        let stopped = update(Model(menu: SampleMenu.definition), .stop).model
        XCTAssertEqual(update(stopped, .setMenuStyle(.selectedMessage)).model, stopped)
    }

    func testMessageUsesExplicitFullTextAndNeutralState() throws {
        let item = Item(id: "item", label: "Short", title: "A complete explanatory title", detail: "A longer description.", value: "value")
        let menu = try Menu(id: "menu", title: "Actions", items: [item])
        let messages = MenuMessage.all(in: menu)
        XCTAssertEqual(messages.count, 2)
        XCTAssertNil(messages[0].itemID)
        XCTAssertEqual(messages[0].title, "Actions")
        XCTAssertEqual(messages[1].title, item.title)
        XCTAssertEqual(messages[1].detail, item.detail)
        XCTAssertEqual(MenuMessage.make(title: menu.title, items: menu.items, selectedID: "stale"), messages[0])
        for title in [" ", String(repeating: "a", count: 161)] {
            XCTAssertThrowsError(try Menu(id: "bad", title: "Actions", items: [Item(id: "a", label: "A", title: title, value: "a")]))
        }
        XCTAssertThrowsError(try Menu(id: "bad", title: "Actions", items: [
            Item(id: "a", label: "A", detail: String(repeating: "a", count: 601), value: "a")]))
    }

    func testEveryMessageAndNeutralStateReserveSpaceBeforeSelection() throws {
        let menu = SampleMenu.definition
        let observations = measurements(menu)
        let layout = try MenuLayout.make(menu: menu, measurements: observations)
        XCTAssertEqual(layout.style, .selectedMessage)
        XCTAssertEqual(layout.centerBounds.x, -150)
        XCTAssertEqual(layout.centerBounds.width, 300)
        XCTAssertEqual(layout.centerBounds.height, 280)
        XCTAssertGreaterThanOrEqual(layout.centerBounds.y + 140, layout.labelRadius / 3 - 1e-8)
        var model = prepared(update(Model(menu: menu, menuStyle: .selectedMessage), .open(nil)).model)
        for item in menu.items {
            model = update(model, .select(model.phase.session!.scope, item.id, .keyboard)).model
            XCTAssertEqual(render(model).message.itemID, item.id)
            XCTAssertEqual(render(model).layout, layout)
        }
    }

    func testMessageButtonsHaveExplicitPointerTargetsAndCenterDoesNotSelect() throws {
        let menu = SampleMenu.definition
        let layout = try MenuLayout.make(menu: menu, measurements: measurements(menu))
        XCTAssertNil(layout.hit(.zero))
        XCTAssertNil(layout.hit(Vector(x: .nan, y: 0)))
        // The decorative circle between buttons is not a pointer target.
        let diagonal = layout.labelRadius / 2.squareRoot()
        XCTAssertNil(layout.hit(Vector(x: diagonal, y: -diagonal)))
        for (index, label) in layout.labels.enumerated() {
            let r = label.bounds
            XCTAssertEqual(layout.hit(Vector(x: r.x + r.width / 2, y: r.y + r.height / 2)), index)
            XCTAssertNil(layout.hit(Vector(x: r.x, y: r.y)))
            XCTAssertNil(layout.hit(Vector(x: r.x - 0.01, y: r.y)))
            let c = layout.centerBounds
            XCTAssertTrue(r.x + r.width < c.x || r.x > c.x + c.width ||
                          r.y + r.height < c.y || r.y > c.y + c.height)
        }
    }

    func testIncompleteDuplicateOversizedAndNonFiniteMessagesAreRejected() throws {
        let menu = SampleMenu.definition
        let states = MenuMessage.all(in: menu).map { MessageMeasurement(itemID: $0.itemID, size: Size(width: 300, height: 100)) }
        let invalid = [Array(states.dropFirst()), Array(states.dropLast()) + [states[0]],
                       states + [states[0]],
                       [MessageMeasurement(itemID: nil, size: Size(width: 301, height: 100))] + states.dropFirst(),
                       [MessageMeasurement(itemID: nil, size: Size(width: 300, height: .nan))] + states.dropFirst()]
        for values in invalid {
            XCTAssertThrowsError(try MenuLayout.make(menu: menu, measurements: MenuMeasurements(
                fontSize: 17, wrappingWidth: 150, labels: TestPresentation.measurements(menu).labels,
                content: .messages(wrappingWidth: 300, states: values), style: .selectedMessage)))
        }
    }

    func testMessageRingGrowsTenPercentAndCardinalLabelsTouchItsOutside() throws {
        let menu = SampleMenu.definition
        let measured = MenuMeasurements(fontSize: 17, wrappingWidth: 80,
            labels: menu.items.map { LabelMeasurement(itemID: $0.id, normal: Size(width: 80, height: 40),
                                                      selected: Size(width: 80, height: 40)) },
            content: .messages(wrappingWidth: 300, states: MenuMessage.all(in: menu).map {
                MessageMeasurement(itemID: $0.itemID, size: Size(width: 300, height: 100))
            }), style: .selectedMessage)
        let layout = try MenuLayout.make(menu: menu, measurements: measured)
        // Horizontal message half-width 150 + label half-width 40 + padding 8
        // gives a 198-point baseline. Ten percent larger is 217.8 points.
        XCTAssertEqual(layout.labelRadius, 217.8, accuracy: 1e-9)
        XCTAssertEqual(layout.labels[0].bounds.y + 40, -217.8, accuracy: 1e-9)
        XCTAssertEqual(layout.labels[1].bounds.x, 217.8, accuracy: 1e-9)
        XCTAssertEqual(layout.labels[2].bounds.y, 217.8, accuracy: 1e-9)
        XCTAssertEqual(layout.labels[3].bounds.x + 80, -217.8, accuracy: 1e-9)
        XCTAssertEqual(layout.size, Size(width: 656, height: 576))
    }

    func testMessageLabelsAreTangentAtEveryDirectionWithStableRoundedTargets() throws {
        for count in 1...12 {
            let menu = try Menu(id: "menu", title: "Actions", items: (0..<count).map {
                Item(id: "\($0)", label: "Item", value: "\($0)")
            })
            let measured = MenuMeasurements(fontSize: 17, wrappingWidth: 150,
                labels: menu.items.enumerated().map { index, item in
                    LabelMeasurement(itemID: item.id, normal: Size(width: 140, height: Double(40 + index * 8)),
                                     selected: Size(width: 150, height: Double(44 + index * 8)))
                }, content: .messages(wrappingWidth: 300, states: MenuMessage.all(in: menu).map {
                    MessageMeasurement(itemID: $0.itemID, size: Size(width: 300, height: 180))
                }), style: .selectedMessage)
            let layout = try MenuLayout.make(menu: menu, measurements: measured)
            for (index, label) in layout.labels.enumerated() {
                let r = label.bounds, corner = label.cornerRadius
                // Project the origin onto the inset box, then onto its rounded
                // boundary. This checks the actual closest point independently.
                let qx = min(max(0, r.x + corner), r.x + r.width - corner)
                let qy = min(max(0, r.y + corner), r.y + r.height - corner)
                let distance = hypot(qx, qy)
                let x = qx * (1 - corner / distance), y = qy * (1 - corner / distance)
                let angle = Double(index) * 2 * .pi / Double(count)
                XCTAssertEqual(x, sin(angle) * layout.labelRadius, accuracy: 1e-8)
                XCTAssertEqual(y, -cos(angle) * layout.labelRadius, accuracy: 1e-8)
                XCTAssertNil(layout.hit(Vector(x: x * 0.99, y: y * 0.99)))
                XCTAssertEqual(layout.hit(Vector(x: r.x + r.width / 2, y: r.y + r.height / 2)), index)
                XCTAssertNil(layout.hit(Vector(x: r.x + 0.1, y: r.y + 0.1)))
                for other in layout.labels.dropFirst(index + 1) {
                    let b = other.bounds
                    XCTAssertGreaterThanOrEqual(max(b.x - r.x - r.width, r.x - b.x - b.width,
                                                    b.y - r.y - r.height, r.y - b.y - b.height), 8 - 1e-8)
                }
            }
        }
    }

    func testSeparateButtonsFitTheirVisibleExtentWithoutReservingAnOuterDisk() throws {
        let menu = try Menu(id: "menu", title: "Actions", items: (0..<6).map { Item(id: "\($0)", label: "Item", value: "\($0)") })
        let measured = MenuMeasurements(fontSize: 34, wrappingWidth: 300,
            labels: menu.items.map { LabelMeasurement(itemID: $0.id, normal: Size(width: 300, height: 160), selected: Size(width: 300, height: 160)) },
            content: .messages(wrappingWidth: 600, states: MenuMessage.all(in: menu).map {
                MessageMeasurement(itemID: $0.itemID, size: Size(width: 600, height: 380))
            }), style: .selectedMessage)
        let layout = try MenuLayout.make(menu: menu, measurements: measured)
        // Larger rings with external labels can exceed a short display. Keep
        // the requested text size and reject that placement instead of clipping.
        XCTAssertThrowsError(try layout.placement(in: ScreenContext(revision: 1, screenID: "short",
            bounds: Rect(x: 0, y: 0, width: 2000, height: 1410), anchor: .zero)))
        XCTAssertLessThan(layout.diameter, layout.outerRadius * 2)
        for rect in layout.labels.map(\.bounds) + [layout.centerBounds] {
            XCTAssertGreaterThanOrEqual(rect.x, -layout.size.width / 2)
            XCTAssertGreaterThanOrEqual(rect.y, -layout.size.height / 2)
            XCTAssertLessThanOrEqual(rect.x + rect.width, layout.size.width / 2)
            XCTAssertLessThanOrEqual(rect.y + rect.height, layout.size.height / 2)
        }
    }

    private func measurements(_ menu: Menu) -> MenuMeasurements {
        let states = MenuMessage.all(in: menu).enumerated().map { index, message in
            MessageMeasurement(itemID: message.itemID, size: Size(width: 300, height: index == 2 ? 280 : 100))
        }
        return MenuMeasurements(fontSize: 17, wrappingWidth: 150, labels: TestPresentation.measurements(menu).labels,
                                content: .messages(wrappingWidth: 300, states: states), style: .selectedMessage)
    }

    private func prepared(_ model: Model) -> Model {
        let session = model.phase.session!
        let reply = Event.prepared(session.scope, model.phase.operation!, measurements(session.menu),
            ScreenContext(revision: 1, screenID: "screen", bounds: Rect(x: 0, y: 0, width: 2000, height: 2000), anchor: .zero))
        let presenting = update(model, reply).model
        return update(presenting, .presented(presenting.phase.operation!)).model
    }
}
