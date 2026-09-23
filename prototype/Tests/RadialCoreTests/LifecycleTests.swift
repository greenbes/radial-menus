import XCTest
@testable import RadialCore

private struct LifecycleRun {
    var model = Model(menu: SampleMenu.definition)
    var effects: [Effect] = []
    var outputs: [Output] = []
    var scope: InputScope { model.phase.session!.scope }

    mutating func send(_ event: Event) {
        let next = update(model, event)
        model = next.model; effects = next.effects; outputs += next.outputs
    }
    mutating func open(presented: Bool = true) {
        send(.open(nil))
        if presented {
            send(TestPresentation.prepared(model))
            send(.presented(model.phase.operation!))
        }
    }
    mutating func dismiss() {
        guard case .dismissing(_, let operation, _) = model.phase else { return XCTFail("Expected dismissal") }
        send(.dismissed(operation))
    }
    var shutdown: Shutdown? {
        if case .stopping(let value) = model.lifecycle { value } else { nil }
    }
}

final class LifecycleTests: XCTestCase {
    func testExhaustedShutdownIdentityPreservesCommittedChoiceInFailure() throws {
        var run = LifecycleRun()
        run.open()
        let scope = run.scope
        run.send(.activate(scope, "blue", .keyboard))
        let model = run.model
        run.model = Model(menu: model.menu, phase: model.phase, controllers: model.controllers,
                          lifecycle: model.lifecycle, nextSession: model.nextSession, nextOperation: UInt64.max)
        run.send(.stop)
        guard case .completed(scope.session, .failed(let failure)) = run.outputs.first else {
            return XCTFail("Missing terminal session failure")
        }
        XCTAssertEqual(failure.committedChoice, Choice(menuPath: ["root"], itemID: "blue", value: "blue"))
        XCTAssertFalse(failure.cleanupConfirmed)
        guard case .shutdownCompleted(.failed) = run.outputs.last else { return XCTFail("Missing shutdown failure") }
        XCTAssertEqual(run.outputs.count, 2)
        XCTAssertTrue(subscriptions(run.model).isEmpty)
    }

    func testIdleShutdownWaitsForResourceReleaseAndCompletesOnce() throws {
        var run = LifecycleRun()
        run.send(.stop)
        let shutdown = try XCTUnwrap(run.shutdown)
        let release = try XCTUnwrap(shutdown.releaseOperation)
        XCTAssertFalse(run.model.running)
        XCTAssertFalse(run.model.canOpen)
        XCTAssertEqual(run.effects, [.releaseResources(release)])
        XCTAssertEqual(subscriptions(run.model), [.shutdownDeadline(shutdown.deadline)])
        XCTAssertTrue(run.outputs.isEmpty)
        run.send(.resourcesReleased(OperationID(999)))
        XCTAssertTrue(run.outputs.isEmpty)
        run.send(.resourcesReleased(release))
        XCTAssertEqual(run.model.lifecycle, .stopped(.completed))
        XCTAssertEqual(run.outputs, [.shutdownCompleted(.completed)])
        XCTAssertTrue(subscriptions(run.model).isEmpty)
        let snapshot = run.model
        run.send(.stop)
        run.send(.resourcesReleased(release))
        run.send(.shutdownDeadline(shutdown.deadline))
        XCTAssertEqual(run.model, snapshot)
        XCTAssertEqual(run.outputs.count, 1)
    }

    func testOpeningAndActiveShutdownCancelOnlyAfterDismissal() throws {
        for presented in [false, true] {
            var run = LifecycleRun()
            run.open(presented: presented)
            let scope = run.scope
            let oldPresentation = run.model.phase.operation
            run.send(.stop)
            let shutdown = try XCTUnwrap(run.shutdown)
            XCTAssertNil(shutdown.releaseOperation)
            XCTAssertEqual(run.model.phase.name, "Dismissing")
            XCTAssertFalse(render(run.model).acceptsInput)
            XCTAssertTrue(run.outputs.isEmpty)
            if let oldPresentation { run.send(.presented(oldPresentation)) }
            run.send(.confirm(scope))
            run.dismiss()
            XCTAssertEqual(run.outputs, [.completed(scope.session, .cancelled(.applicationStopping))])
            let release = try XCTUnwrap(run.shutdown?.releaseOperation)
            run.send(.resourcesReleased(release))
            XCTAssertEqual(run.outputs, [.completed(scope.session, .cancelled(.applicationStopping)),
                                         .shutdownCompleted(.completed)])
        }
    }

    func testShutdownPreservesAChoiceAlreadyCommittedBeforeItStarts() throws {
        var run = LifecycleRun()
        run.open()
        let scope = run.scope
        run.send(.activate(scope, "red", .keyboard))
        let dismissal = run.model.phase.operation
        run.send(.stop)
        XCTAssertEqual(run.model.phase.operation, dismissal)
        run.dismiss()
        let choice = Choice(menuPath: ["root"], itemID: "red", value: "red")
        XCTAssertEqual(run.outputs, [.completed(scope.session, .selected(choice))])
        let release = try XCTUnwrap(run.shutdown?.releaseOperation)
        run.send(.resourcesReleased(release))
        XCTAssertEqual(run.outputs.last, .shutdownCompleted(.completed))
    }

    func testRepeatedStopKeepsOriginalDeadlineAndRejectsReopening() throws {
        var run = LifecycleRun()
        run.open()
        run.send(.stop)
        let shutdown = try XCTUnwrap(run.shutdown)
        let operation = run.model.phase.operation
        run.send(.stop)
        XCTAssertEqual(run.shutdown, shutdown)
        XCTAssertEqual(run.model.phase.operation, operation)
        XCTAssertTrue(run.effects.isEmpty)
        run.send(.open(nil))
        XCTAssertEqual(run.outputs, [.rejected(.stopped)])
    }

    func testOverallDeadlineFailsPendingChoiceAndCannotBecomeLateSuccess() throws {
        var run = LifecycleRun()
        run.open()
        let scope = run.scope
        run.send(.activate(scope, "blue", .keyboard))
        let dismissal = try XCTUnwrap(run.model.phase.operation)
        run.send(.stop)
        let shutdown = try XCTUnwrap(run.shutdown)
        run.send(.shutdownDeadline(shutdown.deadline))
        guard case .completed(scope.session, .failed(let failure)) = run.outputs.first else {
            return XCTFail("Missing terminal failure")
        }
        XCTAssertEqual(failure.committedChoice, Choice(menuPath: ["root"], itemID: "blue", value: "blue"))
        XCTAssertFalse(failure.cleanupConfirmed)
        guard case .shutdownCompleted(.failed) = run.outputs.last else { return XCTFail("Missing shutdown failure") }
        XCTAssertEqual(run.outputs.count, 2)
        XCTAssertTrue(subscriptions(run.model).isEmpty)
        XCTAssertTrue(run.effects.contains { if case .releaseResources = $0 { true } else { false } })
        let snapshot = run.model
        run.send(.dismissed(dismissal))
        run.send(.shutdownDeadline(shutdown.deadline))
        XCTAssertEqual(run.model, snapshot)
        XCTAssertEqual(run.outputs.count, 2)
    }

    func testMissingOrFailedResourceReleaseProducesOneShutdownFailure() throws {
        for timeout in [false, true] {
            var run = LifecycleRun()
            run.send(.stop)
            let shutdown = try XCTUnwrap(run.shutdown)
            let release = try XCTUnwrap(shutdown.releaseOperation)
            run.send(timeout ? .shutdownDeadline(shutdown.deadline) : .operationFailed(release, "Fixture failure"))
            guard case .shutdownCompleted(.failed) = run.outputs.last else { return XCTFail("Missing failure") }
            XCTAssertEqual(run.outputs.count, 1)
            run.send(.resourcesReleased(release))
            XCTAssertEqual(run.outputs.count, 1)
            XCTAssertTrue(subscriptions(run.model).isEmpty)
        }
    }

    func testSessionCleanupFailureIsNotReplacedBySuccessfulShutdown() throws {
        var run = LifecycleRun()
        run.open()
        let scope = run.scope
        run.send(.stop)
        run.send(.deadline(try XCTUnwrap(run.model.phase.operation)))
        guard case .completed(scope.session, .failed) = run.outputs.first else { return XCTFail("Missing session failure") }
        let release = try XCTUnwrap(run.shutdown?.releaseOperation)
        run.send(.resourcesReleased(release))
        XCTAssertEqual(run.outputs.count, 2)
        XCTAssertEqual(run.outputs.last, .shutdownCompleted(.completed), "The later resource release is independently acknowledged")
        guard case .completed(scope.session, .failed) = run.outputs.first else { return XCTFail("Session failure was lost") }
    }

    func testStopSupersedesRecoveryAndIgnoresLateInput() throws {
        var run = LifecycleRun()
        run.open()
        run.send(.cancel(run.scope, .user))
        run.send(.deadline(try XCTUnwrap(run.model.phase.operation)))
        run.send(.recover)
        let recovery = try XCTUnwrap(run.model.phase.operation)
        run.send(.stop)
        let snapshot = run.model
        let id = ConnectionID(9)
        let frame = ControllerFrame(sequence: 1, timestamp: 1, stick: .zero, buttons: [.menu], observedAt: 1)
        for event in [Event.recovered(recovery), .recover,
                      .connected(ControllerInfo(id: id, name: "Late", supported: true), frame),
                      .controllerFrame(id, nil, frame, true)] {
            run.send(event)
            XCTAssertEqual(run.model, snapshot)
        }
    }

    func testDisconnectAndReconnectUseSeparateHistoriesAndRejectOldWork() throws {
        var run = LifecycleRun()
        let old = ConnectionID(1), new = ConnectionID(2)
        func frame(_ n: UInt64, _ buttons: Set<ControllerButton> = [], right: Vector = .zero) -> ControllerFrame {
            ControllerFrame(sequence: n, timestamp: Double(n), stick: .zero, buttons: buttons,
                            rightStick: right, observedAt: Double(n))
        }
        run.send(.connected(ControllerInfo(id: old, name: "Same device", supported: true, supportsMovement: true), frame(0)))
        run.send(.open(old))
        run.send(TestPresentation.prepared(run.model))
        let firstScope = run.scope
        run.send(.placementObserved(firstScope, Placement(layout: 1, screenID: "screen",
            bounds: Rect(x: 0, y: 0, width: 2000, height: 1000), frame: Rect(x: 400, y: 200, width: 360, height: 360))))
        run.send(.presented(try XCTUnwrap(run.model.phase.operation)))
        run.send(.baseline(old, firstScope, frame(1)))
        run.send(.controllerFrame(old, firstScope, frame(2, right: Vector(x: 1, y: 0)), true))
        let movement = try XCTUnwrap(run.model.movement.activity?.id)
        run.send(.disconnected(old))
        XCTAssertNil(run.model.movement.activity)
        XCTAssertNil(run.model.controllers[old])
        run.dismiss()
        XCTAssertEqual(run.outputs, [.completed(firstScope.session, .cancelled(.controllerLost))])
        run.send(.connected(ControllerInfo(id: new, name: "Same device", supported: true), frame(0, [.menu, .confirm])))
        run.send(.controllerFrame(new, nil, frame(1, [.menu, .confirm]), true))
        XCTAssertEqual(run.model.phase, .idle)
        run.send(.controllerFrame(new, nil, frame(2, [.confirm]), true))
        run.send(.controllerFrame(new, nil, frame(3, [.menu, .confirm]), true))
        run.send(TestPresentation.prepared(run.model))
        let secondScope = run.scope
        XCTAssertNotEqual(firstScope.session, secondScope.session)
        run.send(.presented(try XCTUnwrap(run.model.phase.operation)))
        run.send(.baseline(new, secondScope, frame(4, [.confirm])))
        run.send(.select(secondScope, "green", .keyboard))
        let snapshot = run.model
        run.send(.disconnected(old))
        run.send(.controllerFrame(old, firstScope, frame(100, [.confirm]), true))
        run.send(.movementTick(movement, 100))
        XCTAssertEqual(run.model, snapshot)
        run.send(.controllerFrame(new, secondScope, frame(5, [.confirm]), true))
        XCTAssertTrue(run.model.phase.isActive)
        run.send(.controllerFrame(new, secondScope, frame(6), true))
        run.send(.controllerFrame(new, secondScope, frame(7, [.confirm]), true))
        run.dismiss()
        XCTAssertEqual(run.outputs.last, .completed(secondScope.session, .selected(
            Choice(menuPath: ["root"], itemID: "green", value: "green"))))
        XCTAssertEqual(run.outputs.count, 2)
    }

    func testDisconnectAfterCommittedChoiceDoesNotReplaceIt() {
        var run = LifecycleRun()
        let id = ConnectionID(1)
        run.send(.connected(ControllerInfo(id: id, name: "Fixture", supported: true),
            ControllerFrame(sequence: 0, timestamp: 0, stick: .zero, buttons: [], observedAt: 0)))
        run.send(.open(id))
        run.send(TestPresentation.prepared(run.model))
        run.send(.presented(run.model.phase.operation!))
        let scope = run.scope
        run.send(.activate(scope, "red", .keyboard))
        run.send(.disconnected(id))
        run.dismiss()
        XCTAssertEqual(run.outputs, [.completed(scope.session, .selected(
            Choice(menuPath: ["root"], itemID: "red", value: "red")))])
    }
}
