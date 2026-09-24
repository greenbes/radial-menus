import XCTest
@testable import RadialCore

final class MenuContextTests: XCTestCase {
    func testEveryAncestorLevelShrinksAndReturningRestoresItsSize() throws {
        let path = try fixture(depth: 8, count: 4)
        var previous: Double = 1
        for depth in 2...8 {
            let entries = MenuContext.entries(path: Array(path.prefix(depth)))
            let root = try XCTUnwrap(entries.first { $0.target == .menu("menu-0") })
            XCTAssertEqual(root.distance, depth - 1)
            XCTAssertGreaterThan(root.scale, 0)
            XCTAssertLessThan(root.scale, previous)
            XCTAssertEqual(root.scale / previous, 0.8, accuracy: 1e-12)
            XCTAssertEqual(root.fontSize(relativeTo: 34), 2 * root.fontSize(relativeTo: 17), accuracy: 1e-12)
            for entry in entries where entry.distance == root.distance {
                XCTAssertEqual(entry.scale, root.scale)
                XCTAssertEqual(entry.fontSize(relativeTo: 17), root.fontSize(relativeTo: 17))
            }
            previous = root.scale
        }
        let atFour = MenuContext.entries(path: Array(path.prefix(4)))
        let atThree = MenuContext.entries(path: Array(path.prefix(3)))
        let rootFour = try XCTUnwrap(atFour.first { $0.target == .menu("menu-0") })
        let rootThree = try XCTUnwrap(atThree.first { $0.target == .menu("menu-0") })
        XCTAssertEqual(rootFour.scale, 0.512, accuracy: 1e-12)
        XCTAssertEqual(rootThree.scale, 0.64, accuracy: 1e-12)
        XCTAssertGreaterThan(rootThree.fontSize(relativeTo: 17), rootFour.fontSize(relativeTo: 17))
    }

    func testContextIncludesAncestorsAndTheirOtherChoicesButNoHiddenDescendants() throws {
        let path = try fixture(depth: 3, count: 4)
        let context = MenuContext.entries(path: path)
        XCTAssertTrue(MenuContext.entries(path: [path[0]]).isEmpty)
        XCTAssertEqual(context.map(\.target), [
            .menu("menu-1"), .item("leaf-1-1"), .item("leaf-1-2"), .item("leaf-1-3"),
            .menu("menu-0"), .item("leaf-0-1"), .item("leaf-0-2"), .item("leaf-0-3")
        ])
        XCTAssertEqual(context.filter(\.isAncestor).map(\.distance), [1, 2])
        XCTAssertEqual(MenuContext.entries(path: path), context)
        XCTAssertNotEqual(ContextID.menu("same"), .item("same"))
    }

    func testMeasuredContextFitsWithoutChangingActiveDirectionsWidthsOrHitTesting() throws {
        for depth in [2, 3, 8] {
            for count in 1...12 {
                let path = try fixture(depth: depth, count: count)
                let session = Session(scope: InputScope(session: SessionID(1), revision: 1), path: path,
                                      selection: nil, owner: nil, style: .recenteredFloatingLabels)
                let measured = measurements(session)
                let screen = Size(width: 5000, height: 3000)
                let layout = try MenuLayout.make(menu: session.menu, measurements: measured,
                                                context: session.presentation.context, availableSize: screen)
                let plain = try MenuLayout.make(menu: session.menu, measurements: MenuMeasurements(
                    fontSize: 17, wrappingWidth: 240, labels: measured.labels, content: .empty, style: .floatingLabels))
                XCTAssertEqual(layout.labels, plain.labels)
                XCTAssertEqual(layout.sectors, plain.sectors)
                XCTAssertNil(layout.iconRing)
                XCTAssertNil(layout.directionGuide)
                XCTAssertEqual(layout.centerRadius, 0)
                XCTAssertEqual(layout.context.count, (depth - 1) * count)
                XCTAssertEqual(layout.contextArcs.map(\.distance), Array(1..<depth))
                var previousRadius = 0.0, previousLength = Double.infinity
                func outer(_ box: Rect) -> Double {
                    hypot(max(abs(box.x), abs(box.x + box.width)), max(abs(box.y), abs(box.y + box.height)))
                }
                var previousExtent = layout.labels.map { outer($0.bounds) }.max()!
                for arc in layout.contextArcs {
                    XCTAssertGreaterThan(arc.radius, previousRadius)
                    XCTAssertLessThan(arc.length, previousLength)
                    XCTAssertEqual(arc.labels.map(\.target), session.presentation.context.filter { $0.distance == arc.distance }.map(\.target))
                    var previousY = -Double.infinity
                    for label in arc.labels {
                        let r = label.bounds
                        let x = r.x + r.width / 2, y = r.y + r.height / 2
                        XCTAssertEqual(hypot(x, y), arc.radius, accuracy: 1e-8)
                        XCTAssertLessThan(x, 0)
                        XCTAssertGreaterThan(y, previousY)
                        previousY = y
                        // Closest point of the entire rectangle to the origin.
                        let qx = min(max(0, r.x), r.x + r.width)
                        let qy = min(max(0, r.y), r.y + r.height)
                        XCTAssertGreaterThan(hypot(qx, qy), previousExtent)
                    }
                    previousExtent = arc.labels.map { outer($0.bounds) }.max()!
                    previousRadius = arc.radius; previousLength = arc.length
                }
                XCTAssertLessThanOrEqual(layout.size.width, screen.width)
                XCTAssertLessThanOrEqual(layout.size.height, screen.height)
                let rectangles = layout.labels.map(\.bounds) + layout.context.map(\.bounds)
                for (index, box) in rectangles.enumerated() {
                    XCTAssertGreaterThanOrEqual(box.x, -layout.size.width / 2)
                    XCTAssertGreaterThanOrEqual(box.y, -layout.size.height / 2)
                    XCTAssertLessThanOrEqual(box.x + box.width, layout.size.width / 2)
                    XCTAssertLessThanOrEqual(box.y + box.height, layout.size.height / 2)
                    for other in rectangles.dropFirst(index + 1) {
                        XCTAssertTrue(box.x + box.width <= other.x || other.x + other.width <= box.x ||
                                      box.y + box.height <= other.y || other.y + other.height <= box.y)
                    }
                }
                for label in layout.context {
                    XCTAssertNil(layout.hit(Vector(x: label.bounds.x + label.bounds.width / 2,
                                                   y: label.bounds.y + label.bounds.height / 2)))
                }
                let reordered = MenuMeasurements(fontSize: 17, wrappingWidth: 240, labels: measured.labels.reversed(),
                    content: .empty, style: .recenteredFloatingLabels, context: measured.context.reversed())
                XCTAssertEqual(try MenuLayout.make(menu: session.menu, measurements: reordered,
                    context: session.presentation.context, availableSize: screen), layout)
            }
        }
    }

    func testContextRequiresExactCompleteFiniteMeasurementsAndAdequateScreen() throws {
        let path = try fixture(depth: 3, count: 4)
        let session = Session(scope: InputScope(session: SessionID(1), revision: 1), path: path,
                              selection: nil, owner: nil, style: .recenteredFloatingLabels)
        let measured = measurements(session), context = measured.context
        let invalid: [[ContextMeasurement]] = [[], Array(context.dropLast()), context + [context[0]],
            [ContextMeasurement(target: .menu("wrong"), size: context[0].size)] + context.dropFirst(),
            [ContextMeasurement(target: context[0].target, size: Size(width: .nan, height: 44))] + context.dropFirst()]
        for labels in invalid {
            XCTAssertThrowsError(try MenuLayout.make(menu: session.menu,
                measurements: MenuMeasurements(fontSize: 17, wrappingWidth: 240, labels: measured.labels,
                    content: .empty, style: .recenteredFloatingLabels, context: labels),
                context: session.presentation.context, availableSize: Size(width: 2000, height: 1200))) {
                    XCTAssertEqual($0 as? LayoutFailure, .invalidMeasurements)
                }
        }
        XCTAssertThrowsError(try MenuLayout.make(menu: session.menu, measurements: measured,
            context: session.presentation.context, availableSize: Size(width: 400, height: 300))) {
                XCTAssertEqual($0 as? LayoutFailure, .doesNotFit)
            }
    }

    func testHistoryItemsCannotBeSelectedOrActivated() throws {
        let path = try fixture(depth: 3, count: 4)
        var model = ready(update(Model(menu: path[0], menuStyle: .recenteredFloatingLabels), .open(nil)).model)
        model = ready(update(model, .activate(model.phase.session!.scope, "branch-0", .keyboard)).model)
        model = ready(update(model, .activate(model.phase.session!.scope, "branch-1", .keyboard)).model)
        let scope = model.phase.session!.scope
        for entry in model.phase.session!.presentation.context {
            guard case .item(let id) = entry.target else { continue }
            for source in [SelectionSource.pointer, .keyboard, .accessibility, .stick] {
                for event in [Event.select(scope, id, source), .activate(scope, id, source)] {
                    let transition = update(model, event)
                    XCTAssertEqual(transition.model, model)
                    XCTAssertTrue(transition.effects.isEmpty)
                    XCTAssertTrue(transition.outputs.isEmpty)
                }
            }
        }
    }

    func testBackTraversesOneLevelAndRejectsPreviousScope() throws {
        let path = try fixture(depth: 3, count: 4)
        var model = ready(update(Model(menu: path[0], menuStyle: .recenteredFloatingLabels), .open(nil)).model)
        model = ready(update(model, .activate(model.phase.session!.scope, "branch-0", .keyboard)).model)
        model = ready(update(model, .activate(model.phase.session!.scope, "branch-1", .keyboard)).model)
        let old = model.phase.session!.scope
        model = ready(update(model, .back(old)).model)
        XCTAssertEqual(model.phase.session?.path.map(\.id), ["menu-0", "menu-1"])
        XCTAssertEqual(model.phase.session?.presentation.context.count, 4)
        XCTAssertNil(model.phase.session?.selection)
        XCTAssertEqual(update(model, .activate(old, "branch-1", .pointer)).model, model)
        model = ready(update(model, .back(model.phase.session!.scope)).model)
        XCTAssertEqual(model.phase.session?.path.map(\.id), ["menu-0"])
        XCTAssertTrue(model.phase.session!.presentation.context.isEmpty)
        let cancelled = update(model, .back(model.phase.session!.scope))
        guard case .dismissing(_, let operation, .cancelled(.user)) = cancelled.model.phase else { return XCTFail() }
        XCTAssertEqual(update(cancelled.model, .dismissed(operation)).outputs, [.completed(old.session, .cancelled(.user))])
    }

    private func fixture(depth: Int, count: Int) throws -> [Menu] {
        var path: [Menu] = []
        for level in (0..<depth).reversed() {
            var items: [Item] = []
            if let child = path.first { items.append(Item(id: "branch-\(level)", label: "Child", menu: child)) }
            else { items.append(Item(id: "leaf-\(level)-0", label: "First", value: "0")) }
            items += (1..<count).map { Item(id: "leaf-\(level)-\($0)", label: "Choice \($0)", value: "\($0)") }
            path.insert(try Menu(id: "menu-\(level)", title: "Menu \(level)", items: items), at: 0)
        }
        return path
    }

    private func measurements(_ session: Session) -> MenuMeasurements {
        MenuMeasurements(fontSize: 17, wrappingWidth: 240, labels: session.menu.items.enumerated().map { index, item in
            LabelMeasurement(itemID: item.id, normal: Size(width: Double(90 + index * 7), height: 48),
                             selected: Size(width: Double(100 + index * 7), height: 52))
        }, content: .empty, style: session.style, context: session.presentation.context.enumerated().map { index, entry in
            ContextMeasurement(target: entry.target, size: Size(width: Double(70 + index % 3 * 15) * entry.scale, height: 40 * entry.scale))
        })
    }

    private func ready(_ model: Model) -> Model {
        guard case .preparing(let session, let operation) = model.phase else { XCTFail("Expected preparation"); return model }
        let screen = ScreenContext(revision: operation.value, screenID: "test",
            bounds: Rect(x: 0, y: 0, width: 2000, height: 1200), anchor: Vector(x: 1000, y: 600))
        let presenting = update(model, .prepared(session.scope, operation, measurements(session), screen)).model
        guard case .presenting(_, let presentation) = presenting.phase else { XCTFail("Expected presentation"); return presenting }
        return update(presenting, .presented(presentation)).model
    }
}
