import XCTest
@testable import RadialCore

private struct MovementRun {
    let owner = ConnectionID(1)
    var model = Model(menu: SampleMenu.definition)
    var effects: [Effect] = []
    var sequence: UInt64 = 0
    var automaticAcknowledgments = true
    var scope: InputScope { model.phase.session!.scope }
    var movementID: MovementID { model.movement.activity!.id }

    init() {
        send(.connected(ControllerInfo(id: owner, name: "Fixture", supported: true,
                                       supportsMovement: true), sample(time: 0)))
        send(.open(owner))
        send(TestPresentation.prepared(model))
        let operation = model.phase.operation!
        send(.placementObserved(scope, Placement(layout: 1, screenID: "screen",
            bounds: Rect(x: -1000, y: -500, width: 5000, height: 4000),
            frame: Rect(x: 400, y: 300, width: 360, height: 360))))
        send(.presented(operation))
        sequence += 1
        send(.baseline(owner, scope, sample(time: 0)))
    }

    func sample(time: Double, right: Vector = .zero, buttons: Set<ControllerButton> = []) -> ControllerFrame {
        ControllerFrame(sequence: sequence, timestamp: time, stick: .zero, buttons: buttons,
                        rightStick: right, observedAt: time)
    }

    mutating func input(_ right: Vector, at time: Double, buttons: Set<ControllerButton> = []) {
        sequence += 1
        send(.controllerFrame(owner, scope, sample(time: time, right: right, buttons: buttons), true))
    }

    mutating func send(_ event: Event) {
        let transition = update(model, event)
        model = transition.model
        effects = transition.effects
        if automaticAcknowledgments {
            for effect in transition.effects {
                if case .move(let scope, let placement, let operation) = effect {
                    let acknowledged = update(model, .moved(scope, operation, placement))
                    model = acknowledged.model
                    XCTAssertTrue(acknowledged.effects.isEmpty)
                }
            }
        }
    }
}

final class MovementTests: XCTestCase {
    func testCrossingDisplayBoundaryPreservesSelectionScopeAndHeldStick() {
        var run = MovementRun()
        let desktop = Desktop(displays: [
            DisplayArea(id: "left", bounds: Rect(x: -1000, y: 0, width: 1000, height: 1000)),
            DisplayArea(id: "right", bounds: Rect(x: 0, y: 0, width: 1000, height: 1000))
        ])
        run.send(.placementObserved(run.scope, Placement(layout: 2, desktop: desktop,
            frame: Rect(x: -400, y: 300, width: 360, height: 360))))
        run.sequence += 1
        run.send(.baseline(run.owner, run.scope, run.sample(time: 0)))
        run.send(.select(run.scope, "blue", .keyboard))
        let scope = run.scope
        run.input(Vector(x: 1, y: 0), at: 1)
        let clock = run.movementID
        run.send(.movementTick(clock, 1.1))
        XCTAssertEqual(run.model.movement.placement!.frame.x, -160, accuracy: 1e-8)
        XCTAssertEqual(run.model.movement.placement!.screenID, "right")
        XCTAssertEqual(run.scope, scope)
        XCTAssertEqual(run.model.phase.session?.selection?.itemID, "blue")
        XCTAssertEqual(run.movementID, clock)
        run.send(.movementTick(clock, 1.2))
        XCTAssertEqual(run.model.movement.placement!.frame.x, 80, accuracy: 1e-8)
        run.input(.zero, at: 1.2)
        XCTAssertNil(run.model.movement.activity)
        let stopped = run.model
        run.send(.movementTick(clock, 1.3))
        XCTAssertEqual(run.model, stopped)
    }

    func testStandardSpeedRisesProgressivelyWithDeflection() {
        // Stick deflection includes the central 10% dead zone. These speeds
        // specify the response independently of its implementation.
        let samples: [(Double, Double)] = [(0, 0), (0.05, 0), (0.1, 0), (0.325, 150),
                                           (0.55, 600), (0.775, 1350), (1, 2400)]
        for (deflection, speed) in samples {
            for direction in [Vector(x: 1, y: 0), Vector(x: -1, y: 0), Vector(x: 0, y: 1),
                              Vector(x: 0, y: -1), Vector(x: 0.6, y: 0.8)] {
                let input = Vector(x: direction.x * deflection, y: direction.y * deflection)
                let velocity = MovementSettings.standard.velocity(for: input)
                XCTAssertEqual(velocity.x, direction.x * speed, accuracy: 1e-8)
                XCTAssertEqual(velocity.y, direction.y * speed, accuracy: 1e-8)
            }
        }
    }

    func testSpeedIncreasesContinuouslyOutsideDeadZoneAndCapsDiagonals() {
        let settings = MovementSettings.standard
        var previous = 0.0
        for step in 101...1000 {
            let speed = settings.velocity(for: Vector(x: Double(step) / 1000, y: 0)).magnitude
            XCTAssertGreaterThan(speed, previous)
            XCTAssertLessThan(speed - previous, 5.34)
            previous = speed
        }
        for input in [Vector(x: 1, y: 1), Vector(x: -1, y: 1), Vector(x: 1, y: -1), Vector(x: -1, y: -1)] {
            XCTAssertEqual(settings.velocity(for: input).magnitude, 2400, accuracy: 1e-8)
        }
        for input in [Vector(x: .nan, y: 0), Vector(x: 0, y: .infinity), Vector(x: 1.01, y: 0)] {
            XCTAssertEqual(settings.velocity(for: input), .zero)
        }
    }

    func testChangingDeflectionChangesSpeedImmediatelyAndReleaseStops() {
        var run = MovementRun()
        run.input(Vector(x: 0.325, y: 0), at: 1)
        run.input(Vector(x: 0.55, y: 0), at: 1.1)
        XCTAssertEqual(run.model.movement.placement!.frame.x, 415, accuracy: 1e-8)
        run.input(Vector(x: 0.775, y: 0), at: 1.2)
        XCTAssertEqual(run.model.movement.placement!.frame.x, 475, accuracy: 1e-8)
        run.input(Vector(x: 1, y: 0), at: 1.3)
        XCTAssertEqual(run.model.movement.placement!.frame.x, 610, accuracy: 1e-8)
        run.input(Vector(x: 0.325, y: 0), at: 1.4)
        XCTAssertEqual(run.model.movement.placement!.frame.x, 850, accuracy: 1e-8)
        let clock = run.movementID
        run.input(.zero, at: 1.5)
        XCTAssertEqual(run.model.movement.placement!.frame.x, 865, accuracy: 1e-8)
        XCTAssertNil(run.model.movement.activity)
        let stopped = run.model
        run.send(.movementTick(clock, 2))
        XCTAssertEqual(run.model, stopped)
    }

    func testMovementStartsInsideFormerDeadZoneAndStopsAtNewBoundary() {
        var run = MovementRun()
        run.input(Vector(x: 0.15, y: 0), at: 1)
        XCTAssertNotNil(run.model.movement.activity)
        run.input(Vector(x: 0.1, y: 0), at: 1.1)
        XCTAssertEqual(run.model.movement.placement!.frame.x, 400 + 20.0 / 27, accuracy: 1e-8)
        XCTAssertNil(run.model.movement.activity)
    }

    func testDeviceTimestampDoesNotControlMovementIntegrationTime() {
        var run = MovementRun()
        run.send(.controllerFrame(run.owner, run.scope,
            ControllerFrame(sequence: 2, timestamp: 1000, stick: .zero, buttons: [],
                            rightStick: Vector(x: 1, y: 0), observedAt: 1), true))
        run.send(.controllerFrame(run.owner, run.scope,
            ControllerFrame(sequence: 3, timestamp: 1000.5, stick: .zero, buttons: [], observedAt: 1.05), true))
        XCTAssertEqual(run.model.movement.placement!.frame.x, 520, accuracy: 1e-8)
        XCTAssertNil(run.model.movement.activity)
    }

    func testFreshBaselineStopsExistingMovementUntilNewNeutralAndDeflection() {
        var run = MovementRun()
        run.input(Vector(x: 1, y: 0), at: 1)
        let old = run.movementID
        run.sequence += 1
        run.send(.baseline(run.owner, run.scope, run.sample(time: 1.05, right: Vector(x: 1, y: 0))))
        XCTAssertNil(run.model.movement.activity)
        run.send(.movementTick(old, 1.1))
        XCTAssertTrue(run.effects.isEmpty)
        run.input(Vector(x: 0, y: 1), at: 1.2)
        XCTAssertNil(run.model.movement.activity)
        run.input(.zero, at: 1.3)
        run.input(Vector(x: 0, y: 1), at: 1.4)
        XCTAssertNotNil(run.model.movement.activity)
    }

    func testOtherControllerAndStaleSessionCannotStartOrContinueMovement() {
        var run = MovementRun()
        let other = ConnectionID(2)
        run.send(.connected(ControllerInfo(id: other, name: "Other", supported: true,
                                           supportsMovement: true), run.sample(time: 0)))
        run.sequence += 1
        run.send(.baseline(other, run.scope, run.sample(time: 0)))
        run.sequence += 1
        run.send(.controllerFrame(other, run.scope, run.sample(time: 1, right: Vector(x: 1, y: 0)), true))
        XCTAssertNil(run.model.movement.activity)
        run.input(Vector(x: 1, y: 0), at: 1)
        let old = run.movementID
        run.send(.cancel(run.scope, .user))
        run.send(.dismissed(run.model.phase.operation!))
        run.send(.open(run.owner))
        run.send(TestPresentation.prepared(run.model))
        run.send(.presented(run.model.phase.operation!))
        let reopened = run.model
        run.send(.movementTick(old, 1.1))
        XCTAssertEqual(run.model, reopened)
        XCTAssertTrue(run.effects.isEmpty)
    }

    func testValidatedResponseUsesPointsPerSecondAndLimitsDiagonalSpeed() throws {
        let settings = try MovementSettings(speed: 600, deadZone: 0.2, maximumStep: 0.1)
        XCTAssertEqual(settings.velocity(for: .zero), .zero)
        XCTAssertEqual(settings.velocity(for: Vector(x: 0.2, y: 0)), .zero)
        XCTAssertEqual(settings.velocity(for: Vector(x: 1, y: 0)), Vector(x: 600, y: 0))
        XCTAssertEqual(settings.velocity(for: Vector(x: 0.6, y: 0)).x, 150, accuracy: 1e-10)
        XCTAssertEqual(settings.velocity(for: Vector(x: 1, y: 1)).magnitude, 600, accuracy: 1e-10)
        XCTAssertThrowsError(try MovementSettings(speed: .nan, deadZone: 0.2, maximumStep: 0.1))
        XCTAssertThrowsError(try MovementSettings(speed: 600, deadZone: 1, maximumStep: 0.1))
        XCTAssertThrowsError(try MovementSettings(speed: 600, deadZone: 0.2, maximumStep: 0))
        XCTAssertThrowsError(try MovementSettings(speed: .greatestFiniteMagnitude, deadZone: 0.2, maximumStep: 2))
    }

    func testEqualDurationHasEqualDisplacementAtDifferentAndIrregularTickRates() {
        let traces = [30, 60, 120].map { rate in (1...rate).map { Double($0) / Double(rate) } }
            + [[0.03, 0.1, 0.16, 0.25, 0.33, 0.4, 0.5, 0.57, 0.66, 0.75, 0.83, 0.91, 1.0]]
        for trace in traces {
            var run = MovementRun()
            run.input(Vector(x: 1, y: 0), at: 10)
            let id = run.movementID
            for elapsed in trace { run.send(.movementTick(id, 10 + elapsed)) }
            XCTAssertEqual(run.model.movement.placement!.frame.x, 2800, accuracy: 1e-8)
            XCTAssertEqual(run.model.movement.placement!.frame.y, 300)
        }
    }

    func testVelocityChangeAndReleaseIntegrateOnlyTheTimeEachVelocityWasHeld() {
        var run = MovementRun()
        run.input(Vector(x: 1, y: 0), at: 1)
        run.input(Vector(x: 0, y: 1), at: 1.05)
        run.input(.zero, at: 1.1)
        XCTAssertEqual(run.model.movement.placement!.frame.x, 520, accuracy: 1e-8)
        XCTAssertEqual(run.model.movement.placement!.frame.y, 420, accuracy: 1e-8)
        XCTAssertNil(run.model.movement.activity)
        XCTAssertFalse(subscriptions(run.model).contains { if case .movement = $0 { true } else { false } })
    }

    func testLongGapIsCappedAndInvalidOrOldTicksDoNotChangeTheBaseline() {
        var run = MovementRun()
        run.input(Vector(x: 1, y: 0), at: 10)
        let id = run.movementID
        for time in [Double.nan, .infinity, 9, 10] {
            let before = run.model
            run.send(.movementTick(id, time))
            XCTAssertEqual(run.model, before)
        }
        run.send(.movementTick(id, 30))
        XCTAssertEqual(run.model.movement.placement!.frame.x, 640, accuracy: 1e-8)
        run.send(.movementTick(id, 30.05))
        XCTAssertEqual(run.model.movement.placement!.frame.x, 760, accuracy: 1e-8)
    }

    func testWholeMenuClampsAtAllEdgesIncludingNegativeDesktopCoordinates() {
        for direction in [Vector(x: -1, y: 0), Vector(x: 1, y: 0), Vector(x: 0, y: -1), Vector(x: 0, y: 1)] {
            var run = MovementRun()
            run.send(.placementObserved(run.scope, Placement(layout: 2, screenID: "left",
                bounds: Rect(x: -800, y: -600, width: 400, height: 400),
                frame: Rect(x: -780, y: -580, width: 360, height: 360))))
            run.sequence += 1
            run.send(.baseline(run.owner, run.scope, run.sample(time: 1)))
            run.input(direction, at: 2)
            run.send(.movementTick(run.movementID, 2.1))
            let frame = run.model.movement.placement!.frame
            XCTAssertEqual(frame.x, direction.x < 0 ? -800 : direction.x > 0 ? -760 : -780)
            XCTAssertEqual(frame.y, direction.y < 0 ? -600 : direction.y > 0 ? -560 : -580)
        }
    }

    func testNeutralInvalidatesOldClockEvenAfterMovementRestarts() {
        var run = MovementRun()
        run.input(Vector(x: 1, y: 0), at: 1)
        let old = run.movementID
        run.input(.zero, at: 1.05)
        run.input(Vector(x: 0, y: 1), at: 1.1)
        XCTAssertNotEqual(old, run.movementID)
        let before = run.model
        run.send(.movementTick(old, 1.15))
        XCTAssertEqual(run.model, before)
        XCTAssertTrue(run.effects.isEmpty)
    }

    func testNavigationCancelsClockAndHeldRightStickRequiresNeutralAgain() {
        var run = MovementRun()
        run.input(Vector(x: 1, y: 0), at: 1)
        let old = run.movementID
        run.send(.activate(run.scope, "more", .keyboard))
        XCTAssertNil(run.model.movement.activity)
        run.send(TestPresentation.prepared(run.model))
        run.send(.presented(run.model.phase.operation!))
        run.sequence += 1
        run.send(.baseline(run.owner, run.scope, run.sample(time: 2, right: Vector(x: 1, y: 0))))
        run.input(Vector(x: 0, y: 1), at: 2.1)
        XCTAssertNil(run.model.movement.activity)
        run.send(.movementTick(old, 2.2))
        XCTAssertTrue(run.effects.isEmpty)
        run.input(.zero, at: 2.3)
        run.input(Vector(x: 1, y: 0), at: 2.4)
        XCTAssertNotNil(run.model.movement.activity)
    }

    func testCancellationFocusLossDisconnectAndStopRemoveMovement() {
        for kind in 0..<5 {
            var run = MovementRun()
            run.input(Vector(x: 1, y: 0), at: 1)
            let id = run.movementID
            let event: Event = switch kind {
            case 0: .cancel(run.scope, .user)
            case 1: .focusLost(run.scope)
            case 2: .disconnected(run.owner)
            case 3: .inputLost(run.owner)
            default: .stop
            }
            run.send(event)
            XCTAssertNil(run.model.movement.activity)
            let before = run.model
            run.send(.movementTick(id, 1.1))
            XCTAssertEqual(run.model, before)
        }
    }

    func testMissingAcknowledgmentBoundsRequestsAndTimesOutIntoCleanup() {
        var run = MovementRun()
        run.automaticAcknowledgments = false
        run.input(Vector(x: 1, y: 0), at: 1)
        let id = run.movementID
        run.send(.movementTick(id, 1.05))
        let pending = run.model.movement.pending!
        run.send(.movementTick(id, 1.1))
        XCTAssertTrue(run.effects.isEmpty, "Only one window move may be outstanding")
        XCTAssertEqual(run.model.movement.pending, pending)
        run.send(.deadline(pending.operation))
        XCTAssertEqual(run.model.phase.name, "Dismissing")
        XCTAssertNil(run.model.movement.activity)
    }

    func testActualPlacementAcknowledgmentPreservesMovementAccumulatedWhileWaiting() {
        var run = MovementRun()
        run.automaticAcknowledgments = false
        run.input(Vector(x: 1, y: 0), at: 1)
        run.send(.movementTick(run.movementID, 1.05))
        let pending = run.model.movement.pending!
        run.send(.movementTick(run.movementID, 1.1))
        let observed = Placement(layout: 1, screenID: "screen",
            bounds: run.model.movement.placement!.bounds,
            frame: Rect(x: 519, y: 300, width: 360, height: 360))
        run.send(.moved(run.scope, pending.operation, observed))
        XCTAssertEqual(run.model.movement.placement!.frame.x, 519)
        XCTAssertEqual(run.model.movement.pending!.target.x, 639, accuracy: 1e-8)
        XCTAssertEqual(run.effects.count, 1)
    }

    func testScreenChangeStopsMovementPreservesSelectionAndRejectsOldAcknowledgment() {
        var run = MovementRun()
        run.send(.select(run.scope, "blue", .keyboard))
        run.automaticAcknowledgments = false
        run.input(Vector(x: 1, y: 0), at: 1)
        run.send(.movementTick(run.movementID, 1.05))
        let old = run.model.movement.pending!
        let original = run.model.movement.placement!
        run.send(.placementObserved(run.scope, Placement(layout: 2, screenID: "replacement",
            bounds: Rect(x: 0, y: 0, width: 800, height: 800),
            frame: Rect(x: 100, y: 100, width: 360, height: 360))))
        XCTAssertEqual(render(run.model).selectedID, "blue")
        XCTAssertNil(run.model.movement.activity)
        let changed = run.model
        run.send(.moved(run.scope, old.operation, original))
        XCTAssertEqual(run.model, changed)
    }
}
