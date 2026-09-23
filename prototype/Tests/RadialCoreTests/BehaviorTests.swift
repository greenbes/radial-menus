import XCTest
@testable import RadialCore

private struct Interaction {
    var model = Model(menu: SampleMenu.definition)
    var effects: [Effect] = []
    var outputs: [Output] = []

    mutating func send(_ event: Event) {
        let transition = update(model, event)
        model = transition.model
        effects = transition.effects
        outputs += transition.outputs
    }

    mutating func open(owner: ConnectionID? = nil) {
        send(.open(owner))
        acknowledgePresentation()
    }

    mutating func acknowledgePresentation() {
        guard case .presenting(_, let operation) = model.phase else {
            XCTFail("Expected pending presentation"); return
        }
        send(.presented(operation))
    }

    mutating func finishDismissal() {
        guard case .dismissing(_, let operation, _) = model.phase else {
            XCTFail("Expected pending dismissal"); return
        }
        send(.dismissed(operation))
    }

    var scope: InputScope { model.phase.session!.scope }
}

final class BehaviorTests: XCTestCase {
    func testSelectionIsDeliveredOnceAndOnlyAfterDismissal() {
        var run = Interaction()
        run.open()
        let scope = run.scope
        run.send(.select(scope, "blue", .keyboard))
        XCTAssertEqual(render(run.model).selectedID, "blue")
        run.send(.confirm(scope))
        XCTAssertTrue(run.outputs.isEmpty)
        let pending = run.model
        run.send(.confirm(scope))
        XCTAssertEqual(run.model, pending)
        XCTAssertTrue(run.effects.isEmpty)
        guard case .dismissing(_, let operation, _) = run.model.phase else {
            return XCTFail("Expected dismissal")
        }
        run.finishDismissal()
        XCTAssertEqual(run.outputs, [.completed(scope.session, .selected(
            Choice(menuPath: ["root"], itemID: "blue", value: "blue")))])
        run.send(.dismissed(operation))
        XCTAssertEqual(run.outputs.count, 1)
    }

    func testPresentationRequiresCurrentOperationAndDisablesSelection() {
        var run = Interaction()
        run.send(.open(nil))
        let pending = run.model
        run.send(.presented(OperationID(99)))
        run.send(.activate(run.scope, "red", .accessibility))
        XCTAssertEqual(run.model, pending)
        run.acknowledgePresentation()
        XCTAssertTrue(render(run.model).acceptsInput)
    }

    func testOldSessionCannotChangeOrHideNewSession() {
        var run = Interaction()
        run.open()
        let old = run.scope
        run.send(.cancel(old, .user))
        guard case .dismissing(_, let oldOperation, _) = run.model.phase else {
            return XCTFail("Expected dismissal")
        }
        run.finishDismissal()
        run.open()
        let current = run.model
        for event in [Event.confirm(old), .activate(old, "red", .pointer),
                      .dismissed(oldOperation), .presented(oldOperation), .focusLost(old)] {
            run.send(event)
            XCTAssertEqual(run.model, current)
            XCTAssertTrue(run.effects.isEmpty)
        }
    }

    func testNavigationKeepsSessionButRequiresNewPresentation() {
        var run = Interaction()
        run.open()
        let root = run.scope
        run.send(.activate(root, "more", .keyboard))
        XCTAssertEqual(run.scope.session, root.session)
        XCTAssertNotEqual(run.scope, root)
        XCTAssertFalse(render(run.model).acceptsInput)
        XCTAssertEqual(render(run.model).items.map(\.id), ["amber", "violet"])
        run.acknowledgePresentation()
        XCTAssertNil(render(run.model).selectedID)
        let child = run.scope
        run.send(.activate(root, "red", .accessibility))
        XCTAssertEqual(run.scope, child)
        run.send(.back(child))
        run.acknowledgePresentation()
        XCTAssertEqual(render(run.model).items.map(\.id), ["red", "blue", "green", "more"])
        XCTAssertTrue(run.outputs.isEmpty)
    }

    func testBackAtRootCancelsAndAccessibilityActivationChoosesNamedItem() {
        var run = Interaction()
        run.open()
        run.send(.back(run.scope))
        run.finishDismissal()
        XCTAssertEqual(run.outputs, [.completed(SessionID(1), .cancelled(.user))])
        run.open()
        run.send(.select(run.scope, "red", .keyboard))
        run.send(.activate(run.scope, "green", .accessibility))
        run.finishDismissal()
        XCTAssertEqual(run.outputs.last, .completed(SessionID(2), .selected(
            Choice(menuPath: ["root"], itemID: "green", value: "green"))))
    }

    func testCancellationDuringOpeningDoesNotAllowLatePresentation() {
        var run = Interaction()
        run.send(.open(nil))
        guard case .presenting(_, let showing) = run.model.phase else {
            return XCTFail("Expected presentation")
        }
        run.send(.cancel(run.scope, .user))
        let dismissing = run.model
        run.send(.presented(showing))
        XCTAssertEqual(run.model, dismissing)
        run.finishDismissal()
        XCTAssertEqual(run.outputs.count, 1)
    }

    func testCleanupFailureCannotReturnSuccessfulSelectionOrOpenAgain() {
        var run = Interaction()
        run.open()
        run.send(.activate(run.scope, "red", .keyboard))
        guard case .dismissing(_, let operation, _) = run.model.phase else {
            return XCTFail("Expected dismissal")
        }
        run.send(.deadline(operation))
        guard case .unavailable = run.model.phase else { return XCTFail("Must block opening") }
        guard case .completed(_, .failed(let failure)) = run.outputs.first else {
            return XCTFail("Must report failure")
        }
        XCTAssertEqual(failure.committedChoice?.itemID, "red")
        XCTAssertFalse(failure.cleanupConfirmed)
        run.send(.open(nil))
        XCTAssertEqual(run.outputs.last, .rejected(.unavailable))
        run.send(.recover)
        guard case .unavailable(_, let recovery?) = run.model.phase else { return XCTFail("No recovery") }
        run.send(.recovered(recovery))
        XCTAssertEqual(run.model.phase, .idle)
        XCTAssertEqual(run.outputs.filter { if case .completed = $0 { true } else { false } }.count, 1)
    }

    func testPresentationTimeoutCleansUpBeforeFailureResult() {
        var run = Interaction()
        run.send(.open(nil))
        guard case .presenting(_, let operation) = run.model.phase else { return XCTFail() }
        run.send(.deadline(operation))
        XCTAssertTrue(run.outputs.isEmpty)
        run.finishDismissal()
        guard case .completed(_, .failed(let failure)) = run.outputs.first else { return XCTFail() }
        XCTAssertTrue(failure.cleanupConfirmed)
        XCTAssertEqual(run.model.phase, .idle)
    }

    func testBusyOpenAndConfirmWithoutSelectionDoNotReplaceSession() {
        var run = Interaction()
        run.open()
        let active = run.model
        run.send(.confirm(run.scope))
        XCTAssertEqual(run.model, active)
        run.send(.open(nil))
        XCTAssertEqual(run.model, active)
        XCTAssertEqual(run.outputs, [.rejected(.busy)])
    }

    func testBoundedTracesKeepValidSelectionAndAtMostOneCompletion() {
        var start = Interaction()
        start.open()
        let scope = start.scope
        let events: [Event] = [.select(scope, "red", .keyboard), .select(scope, "missing", .pointer),
                               .confirm(scope), .cancel(scope, .user), .dismissed(OperationID(2)),
                               .presented(OperationID(99))]
        var visited = 0
        func explore(_ model: Model, _ completed: Int, _ depth: Int) {
            let view = render(model)
            if let selected = view.selectedID { XCTAssertTrue(view.items.contains { $0.id == selected }) }
            XCTAssertLessThanOrEqual(completed, 1)
            visited += 1
            guard depth > 0 else { return }
            for event in events {
                let next = update(model, event)
                let count = next.outputs.filter { if case .completed = $0 { true } else { false } }.count
                explore(next.model, completed + count, depth - 1)
            }
        }
        explore(start.model, 0, 5)
        XCTAssertEqual(visited, 9331)
    }
}

final class ControllerTests: XCTestCase {
    let connection = ConnectionID(1)
    func frame(_ sequence: UInt64, _ buttons: Set<ControllerButton> = [],
               x: Double = 0, y: Double = 0) -> ControllerFrame {
        ControllerFrame(sequence: sequence, timestamp: Double(sequence),
                        stick: Vector(x: x, y: y), buttons: buttons, observedAt: Double(sequence))
    }

    func testHeldConfirmAcrossSubmenuWaitsForBaselineReleaseAndNewPress() {
        var run = Interaction()
        run.send(.connected(ControllerInfo(id: connection, name: "Test", supported: true), frame(0)))
        run.open(owner: connection)
        let root = run.scope
        run.send(.baseline(connection, root, frame(1)))
        run.send(.select(root, "more", .keyboard))
        run.send(.controllerFrame(connection, root, frame(2, [.confirm]), true))
        let child = run.scope
        XCTAssertNotEqual(child, root)
        run.acknowledgePresentation()
        run.send(.controllerFrame(connection, root, frame(3, [.confirm]), true))
        XCTAssertNil(render(run.model).selectedID)
        run.send(.baseline(connection, child, frame(4, [.confirm])))
        run.send(.select(child, "amber", .keyboard))
        run.send(.controllerFrame(connection, child, frame(5, [.confirm]), true))
        XCTAssertTrue(run.model.phase.isActive)
        run.send(.controllerFrame(connection, child, frame(6), true))
        run.send(.controllerFrame(connection, child, frame(7, [.confirm]), true))
        run.finishDismissal()
        XCTAssertEqual(run.outputs.last, .completed(root.session, .selected(
            Choice(menuPath: ["root", "colors"], itemID: "amber", value: "amber"))))
    }

    func testMenuHeldAtConnectionDoesNotOpenUntilReleased() {
        var run = Interaction()
        run.send(.connected(ControllerInfo(id: connection, name: "Test", supported: true), frame(0, [.menu])))
        run.send(.controllerFrame(connection, nil, frame(1, [.menu]), true))
        XCTAssertEqual(run.model.phase, .idle)
        run.send(.controllerFrame(connection, nil, frame(2), true))
        run.send(.controllerFrame(connection, nil, frame(3, [.menu]), true))
        XCTAssertNotNil(run.model.phase.session)
    }

    func testDisconnectOnlyCancelsOwningConnection() {
        var run = Interaction()
        run.send(.connected(ControllerInfo(id: connection, name: "Test", supported: true), frame(0)))
        run.open(owner: connection)
        run.send(.disconnected(ConnectionID(9)))
        XCTAssertTrue(run.model.phase.isActive)
        run.send(.disconnected(connection))
        run.finishDismissal()
        XCTAssertEqual(run.outputs.last, .completed(SessionID(1), .cancelled(.controllerLost)))
    }

    func testBackWinsOverConfirmAndNeutralCannotEraseKeyboardSelection() {
        var run = Interaction()
        run.send(.connected(ControllerInfo(id: connection, name: "Test", supported: true), frame(0)))
        run.open(owner: connection)
        let scope = run.scope
        run.send(.baseline(connection, scope, frame(1)))
        run.send(.select(scope, "red", .keyboard))
        run.send(.controllerFrame(connection, scope, frame(2), true))
        XCTAssertEqual(render(run.model).selectedID, "red")
        run.send(.controllerFrame(connection, scope, frame(3, [.back, .confirm]), true))
        run.finishDismissal()
        XCTAssertEqual(run.outputs.last, .completed(scope.session, .cancelled(.user)))
    }

    func testLostOrMalformedHistoryCannotConfirm() {
        for invalid in [false, true] {
            var run = Interaction()
            run.send(.connected(ControllerInfo(id: connection, name: "Test", supported: true), frame(0)))
            run.open(owner: connection)
            let scope = run.scope
            run.send(.baseline(connection, scope, frame(1)))
            run.send(.select(scope, "red", .keyboard))
            run.send(.controllerFrame(connection, scope,
                frame(2, [.confirm], x: invalid ? .nan : 0), invalid))
            run.finishDismissal()
            XCTAssertEqual(run.outputs.last, .completed(scope.session, .cancelled(.inputLost)))
        }
    }

    func testStationaryDeflectedStickCannotReclaimKeyboardSelection() {
        var run = Interaction()
        run.send(.connected(ControllerInfo(id: connection, name: "Test", supported: true), frame(0)))
        run.open(owner: connection)
        let scope = run.scope
        run.send(.baseline(connection, scope, frame(1)))
        run.send(.controllerFrame(connection, scope, frame(2, x: 0, y: 1), true))
        XCTAssertEqual(render(run.model).selectedID, "red")
        run.send(.select(scope, "blue", .keyboard))
        run.send(.controllerFrame(connection, scope, frame(3, x: 0, y: 1), true))
        XCTAssertEqual(render(run.model).selectedID, "blue")
    }

    func testFreshMenuPressCanCancelBeforePresentationBaseline() {
        var run = Interaction()
        run.send(.connected(ControllerInfo(id: connection, name: "Test", supported: true), frame(0)))
        run.send(.controllerFrame(connection, nil, frame(1, [.menu]), true))
        XCTAssertEqual(run.model.phase.name, "Presenting")
        run.send(.controllerFrame(connection, nil, frame(2), true))
        run.send(.controllerFrame(connection, nil, frame(3, [.menu]), true))
        XCTAssertEqual(run.model.phase.name, "Dismissing")
        run.finishDismissal()
        XCTAssertEqual(run.outputs.last, .completed(SessionID(1), .cancelled(.user)))
    }

    func testOtherControllerCannotSelectConfirmOrCancelOwnersMenu() {
        var run = Interaction()
        let other = ConnectionID(2)
        for id in [connection, other] {
            run.send(.connected(ControllerInfo(id: id, name: "Test", supported: true), frame(0)))
        }
        run.open(owner: connection)
        let scope = run.scope
        run.send(.baseline(other, scope, frame(1)))
        for (index, buttons) in [Set<ControllerButton>([.confirm]), [.back], [.menu], [.next]].enumerated() {
            run.send(.controllerFrame(other, scope, frame(UInt64(index + 2), buttons, x: 1), true))
            XCTAssertTrue(run.model.phase.isActive)
            XCTAssertNil(render(run.model).selectedID)
            XCTAssertTrue(run.outputs.isEmpty)
        }
    }

    func testNewerSequenceWithRegressingTimestampInvalidatesHistory() {
        var run = Interaction()
        run.send(.connected(ControllerInfo(id: connection, name: "Test", supported: true), frame(0)))
        run.open(owner: connection)
        let scope = run.scope
        run.send(.baseline(connection, scope, frame(10)))
        run.send(.select(scope, "red", .keyboard))
        let regressed = ControllerFrame(sequence: 11, timestamp: 9, stick: .zero, buttons: [.confirm], observedAt: 11)
        run.send(.controllerFrame(connection, scope, regressed, true))
        run.finishDismissal()
        XCTAssertEqual(run.outputs.last, .completed(scope.session, .cancelled(.inputLost)))
    }

    func testDeflectedStickAtNewBaselineRequiresNeutralBeforeSelecting() {
        var run = Interaction()
        run.send(.connected(ControllerInfo(id: connection, name: "Test", supported: true), frame(0)))
        run.open(owner: connection)
        let scope = run.scope
        run.send(.baseline(connection, scope, frame(1, x: 1)))
        run.send(.controllerFrame(connection, scope, frame(2, x: 0, y: 1), true))
        XCTAssertNil(render(run.model).selectedID)
        run.send(.controllerFrame(connection, scope, frame(3), true))
        run.send(.controllerFrame(connection, scope, frame(4, x: 1), true))
        XCTAssertEqual(render(run.model).selectedID, "blue")
    }
}
