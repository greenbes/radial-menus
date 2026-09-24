import XCTest
@testable import RadialCore

final class ChoiceListTests: XCTestCase {
    func testValidationAndEmptySnapshots() throws {
        XCTAssertTrue(try ChoiceList(title: "Empty", items: []).items.isEmpty)
        let item = ListChoice(id: "a", title: "A", value: "a")
        XCTAssertThrowsError(try ChoiceList(title: " ", items: [item]))
        XCTAssertThrowsError(try ChoiceList(title: "Duplicate", items: [item, item]))
        XCTAssertThrowsError(try ChoiceList(title: "Too many", items: (0...256).map { ListChoice(id: "\($0)", title: "Row", value: "") }))
    }

    func testConfirmationEntersListAndReportsOnlyAfterDismissal() throws {
        var model = try active()
        let scope = model.phase.session!.scope
        model = update(model, .select(scope, "item-0", .keyboard)).model
        XCTAssertEqual(render(model).selectedChoice?.id, "row-0")
        let enter = update(model, .confirm(scope))
        XCTAssertTrue(enter.model.phase.isActive)
        XCTAssertTrue(render(enter.model).browsingChoices)
        XCTAssertEqual(enter.effects, [.baseline(scope)])
        model = update(enter.model, .step(scope, 1)).model
        XCTAssertEqual(render(model).selectedID, "item-0")
        XCTAssertEqual(render(model).selectedChoice?.id, "row-1")
        let confirmed = update(model, .confirm(scope))
        XCTAssertTrue(confirmed.outputs.isEmpty)
        let operation = try XCTUnwrap(confirmed.model.phase.operation)
        let result = update(confirmed.model, .dismissed(operation))
        XCTAssertEqual(result.outputs, [.completed(scope.session, .selected(Choice(menuPath: ["menu"], itemID: "item-0", value: "value-1")))])
        XCTAssertTrue(update(result.model, .dismissed(operation)).outputs.isEmpty)
    }

    func testBackReturnsToMenuAndCategoryClicksDoNotCommitRows() throws {
        var model = try active()
        let scope = model.phase.session!.scope
        model = update(model, .activate(scope, "item-0", .pointer)).model
        model = update(model, .selectChoice(scope, item: "item-0", choice: "row-9")).model
        model = update(model, .activate(scope, "item-0", .pointer)).model
        XCTAssertTrue(model.phase.isActive)
        XCTAssertEqual(render(model).selectedChoice?.id, "row-9")
        model = update(model, .back(scope)).model
        XCTAssertFalse(render(model).browsingChoices)
        XCTAssertTrue(model.phase.isActive)
        model = update(model, .step(scope, 1)).model
        XCTAssertEqual(render(model).selectedID, "item-1")
        XCTAssertEqual(render(model).selectedChoice?.id, "row-0")
    }

    func testPointerGapAndObsoleteRowEventsPreserveTheCurrentList() throws {
        var model = try active()
        let scope = model.phase.session!.scope
        model = update(model, .select(scope, "item-0", .pointer)).model
        XCTAssertEqual(update(model, .select(scope, nil, .pointer)).model, model)
        model = update(model, .select(scope, "item-1", .pointer)).model
        XCTAssertEqual(update(model, .selectChoice(scope, item: "item-0", choice: "row-3")).model, model)
        XCTAssertEqual(update(model, .selectChoice(scope, item: "item-1", choice: "missing")).model, model)
        let stale = InputScope(session: scope.session, revision: scope.revision + 1)
        XCTAssertEqual(update(model, .selectChoice(stale, item: "item-1", choice: "row-3")).model, model)
        let cancelled = update(model, .cancel(scope, .user)).model
        XCTAssertEqual(update(cancelled, .selectChoice(scope, item: "item-1", choice: "row-3")).model, cancelled)
    }

    func testRowsClampAtEndsAndAnEmptyListCannotConfirm() throws {
        var model = try active()
        let scope = model.phase.session!.scope
        model = update(model, .activate(scope, "item-0", .keyboard)).model
        for _ in 0..<30 { model = update(model, .step(scope, 1)).model }
        XCTAssertEqual(render(model).selectedChoice?.id, "row-15")
        for _ in 0..<30 { model = update(model, .step(scope, -1)).model }
        XCTAssertEqual(render(model).selectedChoice?.id, "row-0")
        let empty = try Menu(id: "empty", title: "Empty", items: [Item(id: "empty-item", label: "Empty", choices: ChoiceList(title: "Nothing", items: []))])
        model = try active(menu: empty)
        let emptyScope = model.phase.session!.scope
        model = update(model, .activate(emptyScope, "empty-item", .keyboard)).model
        XCTAssertNil(render(model).selectedChoice)
        XCTAssertEqual(update(model, .confirm(emptyScope)).model, model)
    }

    func testControllerTiltStepsOnceUntilNeutralAndHeldConfirmDoesNotChoose() throws {
        var model = try active(owner: ConnectionID(1))
        let scope = model.phase.session!.scope
        func frame(_ n: UInt64, _ stick: Vector = .zero, _ buttons: Set<ControllerButton> = []) -> ControllerFrame {
            ControllerFrame(sequence: n, timestamp: Double(n), stick: stick, buttons: buttons, observedAt: Double(n))
        }
        model = update(model, .baseline(ConnectionID(1), scope, frame(1))).model
        model = update(model, .select(scope, "item-0", .stick)).model
        model = update(model, .controllerFrame(ConnectionID(1), scope, frame(2, .zero, [.confirm]), true)).model
        model = update(model, .baseline(ConnectionID(1), scope, frame(3, .zero, [.confirm]))).model
        model = update(model, .controllerFrame(ConnectionID(1), scope, frame(4, .zero, [.confirm]), true)).model
        XCTAssertTrue(model.phase.isActive)
        model = update(model, .controllerFrame(ConnectionID(1), scope, frame(5, Vector(x: 0, y: -1)), true)).model
        XCTAssertEqual(render(model).selectedChoice?.id, "row-1")
        for n in 6...8 { model = update(model, .controllerFrame(ConnectionID(1), scope, frame(UInt64(n), Vector(x: 0, y: -0.8)), true)).model }
        XCTAssertEqual(render(model).selectedChoice?.id, "row-1")
        model = update(model, .controllerFrame(ConnectionID(1), scope, frame(9), true)).model
        model = update(model, .controllerFrame(ConnectionID(1), scope, frame(10, Vector(x: 0, y: -1)), true)).model
        XCTAssertEqual(render(model).selectedChoice?.id, "row-2")
        XCTAssertEqual(render(model).selectedID, "item-0")
    }

    func testOvalLayoutContainsDistinctTargetsAndKeepsTheListOnTheRight() throws {
        for count in 1...12 {
            let menu = try fixture(count: count)
            let layout = try MenuLayout.make(menu: menu, measurements: measured(menu))
            let panel = try XCTUnwrap(layout.choicePanel)
            XCTAssertEqual(panel.bounds.y + panel.bounds.height / 2, layout.ringCenter.y, accuracy: 1e-9)
            XCTAssertGreaterThan(panel.bounds.x, layout.labels.map { $0.bounds.x + $0.bounds.width }.max()!)
            XCTAssertGreaterThan(layout.centerBounds.y, layout.labels.map { $0.bounds.y + $0.bounds.height }.max()!)
            let rectangles = layout.labels.map(\.bounds) + [layout.centerBounds, panel.bounds] + [layout.messageBackBounds].compactMap { $0 }
            for (i, a) in rectangles.enumerated() {
                XCTAssertGreaterThanOrEqual(a.x, -layout.size.width / 2)
                XCTAssertLessThanOrEqual(a.x + a.width, layout.size.width / 2)
                XCTAssertGreaterThanOrEqual(a.y, -layout.size.height / 2)
                XCTAssertLessThanOrEqual(a.y + a.height, layout.size.height / 2)
                for b in rectangles.dropFirst(i + 1) {
                    XCTAssertTrue(a.x + a.width < b.x || b.x + b.width < a.x || a.y + a.height < b.y || b.y + b.height < a.y)
                }
            }
            for (i, label) in layout.labels.enumerated() {
                let x = label.bounds.x + label.bounds.width / 2, y = label.bounds.y + label.bounds.height / 2
                XCTAssertEqual(layout.hit(Vector(x: x, y: y)), i)
                XCTAssertEqual((x - layout.ringCenter.x) / layout.labelRadius, sin(Double(i) * 2 * .pi / Double(count)), accuracy: 1e-9)
                XCTAssertEqual((y - layout.ringCenter.y) / layout.labelRadius, -0.64 * cos(Double(i) * 2 * .pi / Double(count)), accuracy: 1e-9)
            }
            XCTAssertNil(layout.hit(layout.ringCenter))
            XCTAssertThrowsError(try layout.placement(in: ScreenContext(revision: 1, screenID: "small", bounds: Rect(x: 0, y: 0, width: 100, height: 100), anchor: .zero)))
        }
    }

    func testEveryStyleCanPresentTheSameListContentAndRejectsMissingMeasurements() throws {
        let menu = try fixture()
        for style in MenuStyle.allCases {
            let layout = try MenuLayout.make(menu: menu, measurements: measured(menu, style: style))
            XCTAssertNotNil(layout.choicePanel)
            XCTAssertEqual(layout.style, style)
            if style == .pie {
                let radius = (layout.innerRadius + layout.outerRadius) / 2
                XCTAssertEqual(layout.hit(Vector(x: layout.ringCenter.x, y: layout.ringCenter.y - radius)), 0)
            }
        }
        let observations = measured(menu)
        XCTAssertThrowsError(try MenuLayout.make(menu: menu, measurements: MenuMeasurements(fontSize: 17, wrappingWidth: 160,
            labels: observations.labels, content: observations.center, style: .iconLabelsCards, icons: observations.icons)))
        let missing = ChoiceListMeasurements(width: 280, rowWidth: 248, placeholder: Size(width: 280, height: 40), sections: [])
        XCTAssertThrowsError(try MenuLayout.make(menu: menu, measurements: MenuMeasurements(fontSize: 17, wrappingWidth: 160,
            labels: observations.labels, content: observations.center, style: .iconLabelsCards, icons: observations.icons, choices: missing)))
    }

    private func fixture(count: Int = 6) throws -> Menu {
        let choices = try ChoiceList(title: "Sessions", items: (0..<16).map { ListChoice(id: "row-\($0)", title: "Session \($0)", value: "value-\($0)") })
        return try Menu(id: "menu", title: "Choices", items: (0..<count).map { Item(id: "item-\($0)", label: "Item \($0)", choices: choices) })
    }

    private func measured(_ menu: Menu, style: MenuStyle = .iconLabelsCards) -> MenuMeasurements {
        let center: MenuMeasurements.Center = style.showsMessageCard ? .messages(wrappingWidth: 300,
            states: MenuMessage.all(in: menu).map { MessageMeasurement(itemID: $0.itemID, size: Size(width: 300, height: 140)) },
            back: Size(width: 70, height: 30)) : style.hasEmptyCenter ? .empty : .control(Size(width: 40, height: 35))
        return MenuMeasurements(fontSize: 17, wrappingWidth: 160, labels: menu.items.enumerated().map { i, item in
            LabelMeasurement(itemID: item.id, normal: Size(width: 150, height: Double(40 + i * 3)), selected: Size(width: 160, height: Double(46 + i * 3)))
        }, content: center, style: style, icons: style.usesIconRing ? menu.items.map {
            LabelMeasurement(itemID: $0.id, normal: Size(width: 20, height: 20), selected: Size(width: 22, height: 22))
        } : [], choices: ChoiceListMeasurements(width: 280, rowWidth: 248, placeholder: Size(width: 280, height: 40), sections: menu.items.compactMap { item in
            item.choices.map { list in ChoiceSectionMeasurement(itemID: item.id, header: Size(width: 280, height: 40), rows: list.items.map {
                LabelMeasurement(itemID: $0.id, normal: Size(width: 248, height: 48), selected: Size(width: 248, height: 50))
            }) }
        }))
    }

    private func active(menu: Menu? = nil, owner: ConnectionID? = nil) throws -> Model {
        let menu = try menu ?? fixture()
        var model = Model(menu: menu, menuStyle: .iconLabelsCards)
        if let owner {
            model = update(model, .connected(ControllerInfo(id: owner, name: "Fixture", supported: true),
                ControllerFrame(sequence: 0, timestamp: 0, stick: .zero, buttons: [], observedAt: 0))).model
        }
        model = update(model, .open(owner)).model
        let scope = try XCTUnwrap(model.phase.session?.scope), operation = try XCTUnwrap(model.phase.operation)
        model = update(model, .prepared(scope, operation, measured(menu), ScreenContext(revision: 1, screenID: "screen",
            bounds: Rect(x: 0, y: 0, width: 5000, height: 4000), anchor: Vector(x: 2000, y: 1500)))).model
        return update(model, .presented(try XCTUnwrap(model.phase.operation))).model
    }
}
