import XCTest
@testable import RadialCore

private struct PointerRun {
    var model = Model(menu: SampleMenu.definition)
    var outputs: [Output] = []
    var scope: InputScope { model.phase.session!.scope }
    var selected: String? { model.phase.session?.selection?.itemID }
    let controller = ConnectionID(1)

    init(settings: PointerSettings = .standard) {
        model = Model(menu: SampleMenu.definition, pointerSettings: settings)
        send(.connected(ControllerInfo(id: controller, name: "Fixture", supported: true), frame(0)))
        send(.open(controller))
        present()
    }

    mutating func send(_ event: Event) {
        let next = update(model, event)
        model = next.model
        outputs += next.outputs
    }

    mutating func present(layout: UInt64 = 1) {
        send(TestPresentation.prepared(model))
        guard case .presenting(_, let operation) = model.phase else {
            XCTFail("Expected pending presentation"); return
        }
        send(.placementObserved(scope, Placement(layout: layout, screenID: "screen",
            bounds: Rect(x: -1000, y: -500, width: 3000, height: 2000),
            frame: Rect(x: 0, y: 0, width: 360, height: 360))))
        send(.pointerBaseline(scope, sample(1, screen: .zero, local: .zero, layout: layout)))
        send(.presented(operation))
        send(.baseline(controller, scope, frame(1)))
    }

    func sample(_ sequence: UInt64, screen: Vector, local: Vector, layout: UInt64 = 1,
                timestamp: Double? = nil) -> PointerSample {
        PointerSample(sequence: sequence, timestamp: timestamp ?? Double(sequence), layout: layout,
                      screenPosition: screen, menuPosition: local)
    }

    mutating func point(_ sequence: UInt64, x: Double, y: Double, screenX: Double? = nil,
                        screenY: Double = 0) {
        send(.pointerMoved(scope, sample(sequence, screen: Vector(x: screenX ?? Double(sequence) * 10, y: screenY),
                                         local: Vector(x: x, y: y))))
    }

    func frame(_ sequence: UInt64, stick: Vector = .zero, buttons: Set<ControllerButton> = []) -> ControllerFrame {
        ControllerFrame(sequence: sequence, timestamp: Double(sequence), stick: stick,
                        buttons: buttons, observedAt: Double(sequence))
    }

    mutating func stick(_ sequence: UInt64, _ stick: Vector, buttons: Set<ControllerButton> = []) {
        send(.controllerFrame(controller, scope, frame(sequence, stick: stick, buttons: buttons), true))
    }
}

final class PointerTests: XCTestCase {
    func testSettingsRejectInvalidMotionThresholds() throws {
        for value in [0.0, -1, .nan, .infinity, -.infinity] {
            XCTAssertThrowsError(try PointerSettings(movementThreshold: value))
        }
        XCTAssertEqual(try PointerSettings(movementThreshold: 3).movementThreshold, 3)
    }

    func testConfiguredThresholdControlsHandoff() throws {
        var run = PointerRun(settings: try PointerSettings(movementThreshold: 4))
        run.send(.step(run.scope, 1))
        run.point(2, x: 100, y: 0, screenX: 3.5)
        XCTAssertEqual(run.selected, "red")
        run.point(3, x: 100, y: 0, screenX: 4)
        XCTAssertEqual(run.selected, "blue")
    }

    func testMissingAndInvalidBaselinesCannotEnableHover() {
        var run = PointerRun()
        run.send(.placementObserved(run.scope, Placement(layout: 2, screenID: "screen",
            bounds: Rect(x: 0, y: 0, width: 1000, height: 1000),
            frame: Rect(x: 0, y: 0, width: 360, height: 360))))
        let sample = run.sample(2, screen: Vector(x: 20, y: 0), local: Vector(x: 100, y: 0), layout: 2)
        let snapshot = run.model
        run.send(.pointerMoved(run.scope, sample))
        run.send(.pointerBaseline(run.scope,
            run.sample(2, screen: Vector(x: .nan, y: 0), local: .zero, layout: 2)))
        run.send(.pointerMoved(run.scope, sample))
        XCTAssertEqual(run.model, snapshot)
        run.send(.pointerBaseline(run.scope, sample))
        run.send(.pointerMoved(run.scope,
            run.sample(3, screen: Vector(x: 22, y: 0), local: Vector(x: 100, y: 0), layout: 2)))
        XCTAssertEqual(run.selected, "blue")
    }

    func testOpeningBaselineDoesNotSelectUnderStationaryPointer() {
        var run = PointerRun()
        run.send(.pointerBaseline(run.scope,
            run.sample(2, screen: Vector(x: 10, y: 10), local: Vector(x: 0, y: -100))))
        run.point(3, x: 0, y: -100, screenX: 10, screenY: 10)
        XCTAssertNil(run.selected)
        run.point(4, x: 0, y: -100, screenX: 12, screenY: 10)
        XCTAssertEqual(run.selected, "red")
    }

    func testCardinalPositionsUseSharedRingGeometry() {
        var run = PointerRun()
        for (sequence, x, y, item) in [(2, 0.0, -100.0, "red"), (3, 100, 0, "blue"),
                                        (4, 0, 100, "green"), (5, -100, 0, "more")] {
            run.point(UInt64(sequence), x: x, y: y)
            XCTAssertEqual(run.selected, item)
            XCTAssertEqual(run.model.phase.session?.selection?.source, .pointer)
        }
    }

    func testCenterAndOutsideClearOnlyPointerSelection() {
        for position in [Vector.zero, Vector(x: 0, y: -46), Vector(x: 0, y: -151)] {
            var run = PointerRun()
            run.point(2, x: 0, y: -100)
            XCTAssertEqual(run.selected, "red")
            run.point(3, x: position.x, y: position.y)
            XCTAssertNil(run.selected)
            run.send(.step(run.scope, 1))
            run.point(4, x: position.x, y: position.y)
            XCTAssertEqual(run.selected, "red")
        }
    }

    func testOuterBoundaryIsIncludedAndSectorBoundarySelectsClockwiseItem() {
        var run = PointerRun()
        run.point(2, x: 0, y: -150)
        XCTAssertEqual(run.selected, "red")
        run.point(3, x: 100, y: -100)
        XCTAssertEqual(run.selected, "blue")
    }

    func testSmallStepsAccumulateFromLastAcceptedPosition() {
        var run = PointerRun()
        for (sequence, x) in [(2, 0.5), (3, 1.0), (4, 1.5)] {
            run.point(UInt64(sequence), x: 100, y: 0, screenX: x)
            XCTAssertNil(run.selected)
        }
        run.point(5, x: 100, y: 0, screenX: 2)
        XCTAssertEqual(run.selected, "blue")
        run.send(.step(run.scope, 1))
        run.point(6, x: 100, y: 0, screenX: 3.5)
        XCTAssertEqual(run.selected, "green")
        run.point(7, x: 100, y: 0, screenX: 4)
        XCTAssertEqual(run.selected, "blue")
    }

    func testMenuMovingUnderStationaryPointerCannotChangeSelection() {
        var run = PointerRun()
        run.point(2, x: 0, y: -100, screenX: -200, screenY: 600)
        XCTAssertEqual(run.selected, "red")
        // A different local position at the same desktop point is window motion.
        run.point(3, x: 100, y: 0, screenX: -200, screenY: 600)
        XCTAssertEqual(run.selected, "red")
        run.send(.step(run.scope, 1))
        run.point(4, x: -100, y: 0, screenX: -200, screenY: 600)
        XCTAssertEqual(run.selected, "blue")
        run.point(5, x: -100, y: 0, screenX: -202, screenY: 600)
        XCTAssertEqual(run.selected, "more")
    }

    func testKeyboardPointerAndStickTakeControlOnlyOnDeliberateInput() {
        var run = PointerRun()
        run.stick(2, Vector(x: 0, y: 1))
        XCTAssertEqual(run.selected, "red")
        run.point(2, x: 100, y: 0)
        run.stick(3, Vector(x: 0, y: 1))
        XCTAssertEqual(run.selected, "blue")
        run.stick(4, .zero)
        XCTAssertEqual(run.selected, "blue", "Releasing another input cannot clear pointer selection")
        run.send(.step(run.scope, 1))
        run.point(3, x: 100, y: 0, screenX: 20)
        XCTAssertEqual(run.selected, "green", "An unchanged pointer cannot undo a keyboard step")
        run.stick(5, Vector(x: -1, y: 0))
        XCTAssertEqual(run.selected, "more")
        run.point(4, x: 100, y: 0, screenX: 22)
        XCTAssertEqual(run.selected, "blue")
        run.stick(6, Vector(x: -1, y: 0), buttons: [.confirm])
        guard case .dismissing(_, let operation, _) = run.model.phase else { return XCTFail("Missing choice") }
        run.send(.dismissed(operation))
        run.send(.dismissed(operation))
        XCTAssertEqual(run.outputs, [.completed(SessionID(1), .selected(
            Choice(menuPath: ["root"], itemID: "blue", value: "blue")))])
    }

    func testPointerCannotEraseAccessibilitySelectionWithoutEnteringAnItem() {
        var run = PointerRun()
        run.send(.select(run.scope, "green", .accessibility))
        run.point(2, x: 0, y: 0)
        XCTAssertEqual(run.selected, "green")
        run.point(3, x: 0, y: -100)
        XCTAssertEqual(run.selected, "red")
    }

    func testInvalidDuplicateAndOutOfOrderSamplesCannotChangeSelectionOrAnchor() {
        var run = PointerRun()
        run.point(10, x: 0, y: -100)
        let snapshot = run.model
        let scope = run.scope
        for sample in [
            run.sample(10, screen: Vector(x: 200, y: 0), local: Vector(x: 100, y: 0)),
            run.sample(9, screen: Vector(x: 200, y: 0), local: Vector(x: 100, y: 0)),
            run.sample(11, screen: Vector(x: 200, y: 0), local: Vector(x: 100, y: 0), timestamp: 9),
            run.sample(11, screen: Vector(x: .nan, y: 0), local: Vector(x: 100, y: 0)),
            run.sample(11, screen: Vector(x: 200, y: 0), local: Vector(x: .infinity, y: 0)),
            run.sample(11, screen: Vector(x: 200, y: 0), local: Vector(x: 100, y: 0), layout: 2),
            run.sample(11, screen: Vector(x: 200, y: 0), local: Vector(x: 100, y: 0), timestamp: .nan)
        ] {
            run.send(.pointerMoved(scope, sample))
            XCTAssertEqual(run.model, snapshot)
        }
        run.point(11, x: 100, y: 0)
        XCTAssertEqual(run.selected, "blue")
    }

    func testNavigationRequiresNewBaselineAndRejectsParentPointerEvents() {
        var run = PointerRun()
        let parent = run.scope
        run.point(2, x: -100, y: 0)
        run.send(.confirm(parent))
        let child = run.scope
        run.send(.pointerMoved(child, run.sample(3, screen: Vector(x: 40, y: 0), local: Vector(x: 0, y: -100))))
        XCTAssertNil(run.selected)
        run.present(layout: 2)
        let snapshot = run.model
        run.send(.pointerMoved(parent, run.sample(100, screen: Vector(x: 100, y: 0), local: Vector(x: 0, y: -100), layout: 2)))
        XCTAssertEqual(run.model, snapshot)
        run.send(.pointerMoved(child, run.sample(2, screen: .zero, local: Vector(x: 0, y: -100), layout: 2)))
        XCTAssertNil(run.selected)
        run.send(.pointerMoved(child, run.sample(3, screen: Vector(x: 2, y: 0), local: Vector(x: 0, y: -100), layout: 2)))
        XCTAssertEqual(run.selected, "amber")
    }

    func testScreenChangePreservesSelectionButNeedsNewPointerBaseline() {
        var run = PointerRun()
        run.point(2, x: 0, y: -100)
        run.send(.placementObserved(run.scope, Placement(layout: 2, screenID: "other",
            bounds: Rect(x: -2000, y: 0, width: 1800, height: 1200),
            frame: Rect(x: -1500, y: 0, width: 360, height: 360))))
        run.point(3, x: 100, y: 0)
        XCTAssertEqual(run.selected, "red")
        run.send(.pointerBaseline(run.scope, run.sample(4, screen: Vector(x: -500, y: 0), local: Vector(x: 100, y: 0), layout: 2)))
        run.send(.pointerMoved(run.scope, run.sample(5, screen: Vector(x: -500, y: 0), local: Vector(x: 100, y: 0), layout: 2)))
        XCTAssertEqual(run.selected, "red")
        run.send(.pointerMoved(run.scope, run.sample(6, screen: Vector(x: -502, y: 0), local: Vector(x: 100, y: 0), layout: 2)))
        XCTAssertEqual(run.selected, "blue")
    }

    func testClickChoosesNamedItemDespiteDifferentHoverAndRejectsLateInput() {
        var run = PointerRun()
        let scope = run.scope
        run.point(2, x: 0, y: -100)
        run.send(.activate(scope, "blue", .pointer))
        let pending = run.model
        run.point(3, x: 0, y: 100)
        XCTAssertEqual(run.model, pending)
        let operation = run.model.phase.operation!
        run.send(.dismissed(operation))
        XCTAssertEqual(run.outputs, [.completed(scope.session, .selected(
            Choice(menuPath: ["root"], itemID: "blue", value: "blue")))])
        run.send(.open(nil))
        run.present()
        let reopened = run.model
        run.send(.pointerMoved(scope, run.sample(100, screen: Vector(x: 100, y: 0), local: Vector(x: 0, y: 100))))
        XCTAssertEqual(run.model, reopened)
    }

    func testCancelFromSubmenuEndsWholeInteractionWhileBackReturnsToParent() {
        for cancel in [false, true] {
            var run = PointerRun()
            run.send(.activate(run.scope, "more", .pointer))
            run.present(layout: 2)
            run.send(cancel ? .cancel(run.scope, .user) : .back(run.scope))
            if cancel {
                XCTAssertEqual(run.model.phase.name, "Dismissing")
                run.send(.dismissed(run.model.phase.operation!))
                XCTAssertEqual(run.outputs, [.completed(SessionID(1), .cancelled(.user))])
            } else {
                XCTAssertEqual(run.model.phase.name, "Preparing")
                XCTAssertEqual(run.model.phase.session?.menu.id, "root")
                XCTAssertTrue(run.outputs.isEmpty)
            }
        }
    }
}
