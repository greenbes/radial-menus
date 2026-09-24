import XCTest
import RadialCore
@testable import RadialRuntime

@MainActor private final class FakeWindow: WindowDriver {
    var receive: EventReceiver?
    var synchronous = true
    var presented: [OperationID] = []
    var dismissed: [OperationID] = []
    var released: [OperationID] = []
    var inspect: (() -> Void)?
    var inspectDismissal: (() -> Void)?
    var inspectRelease: (() -> Void)?
    func prepare(scope: InputScope, presentation: MenuPresentation, operation: OperationID) {
        let menu = presentation.menu, style = presentation.style
        let center: MenuMeasurements.Center = style.hasEmptyCenter ? .empty : style != .selectedMessage ? .control(Size(width: 36, height: 32)) :
            .messages(wrappingWidth: 300, states: MenuMessage.all(in: menu).map {
                MessageMeasurement(itemID: $0.itemID, size: Size(width: 300, height: 180))
            })
        let measurements = MenuMeasurements(fontSize: 17, wrappingWidth: 96, labels: menu.items.map {
            LabelMeasurement(itemID: $0.id, normal: Size(width: 30, height: 20), selected: Size(width: 30, height: 20))
        }, content: center, style: style, icons: style == .iconLabels ? menu.items.map {
            LabelMeasurement(itemID: $0.id, normal: Size(width: 18, height: 18), selected: Size(width: 20, height: 20))
        } : [])
        if synchronous {
            receive?(.prepared(scope, operation, measurements, ScreenContext(revision: 1, screenID: "screen",
                bounds: Rect(x: 0, y: 0, width: 2000, height: 1000), anchor: Vector(x: 580, y: 380))))
        }
    }
    func present(scope: InputScope, layout: MenuLayout, placement: Placement, operation: OperationID) {
        inspect?(); presented.append(operation)
        if synchronous { receive?(.presented(operation)) }
    }
    func inspectPresentation(scope: InputScope, operation: OperationID) {}
    func dismiss(scope: InputScope, operation: OperationID) {
        inspectDismissal?()
        dismissed.append(operation)
        if synchronous { receive?(.dismissed(operation)) }
    }
    func move(scope: InputScope, placement: Placement, operation: OperationID) {
        if synchronous { receive?(.moved(scope, operation, placement)) }
    }
    func recover(operation: OperationID) { if synchronous { receive?(.recovered(operation)) } }
    func releaseResources(operation: OperationID) {
        inspectRelease?(); released.append(operation)
        if synchronous { receive?(.resourcesReleased(operation)) }
    }
}
@MainActor private final class FakeController: ControllerDriver {
    var receive: EventReceiver?
    var starts = 0
    var stops = 0
    var resets: [ConnectionID] = []
    func start() { starts += 1 }
    func stop() { stops += 1 }
    func baseline(scope: InputScope) {}
    func endInput(scope: InputScope) {}
    func resetInput(connection: ConnectionID) { resets.append(connection) }
}
@MainActor private final class FakeClock: DeadlineScheduler, MovementScheduler {
    var movement: [MovementID: EventReceiver] = [:]
    var stoppedMovement: [MovementID] = []
    func startMovement(id: MovementID, receive: @escaping EventReceiver) { movement[id] = receive }
    func stopMovement(id: MovementID) { stoppedMovement.append(id); movement.removeValue(forKey: id) }
    var scheduled: [OperationID: EventReceiver] = [:]
    var cancelled: [OperationID] = []
    var delays: [OperationID: Double] = [:]
    func schedule(operation: OperationID, after seconds: Double, receive: @escaping EventReceiver) {
        scheduled[operation] = receive
        delays[operation] = seconds
    }
    func cancel(operation: OperationID) { cancelled.append(operation); scheduled.removeValue(forKey: operation) }
}

final class StoreTests: XCTestCase {
    @MainActor func testStyleChoicePassesThroughPreparationAndChangesOnlyTheNextSession() async {
        let window = FakeWindow(), controller = FakeController(), scheduler = FakeClock()
        let store = Store(menu: SampleMenu.definition, window: window, controller: controller,
                          scheduler: scheduler, movementClock: scheduler)
        for style in MenuStyle.allCases {
            store.send(.setMenuStyle(style))
            store.send(.open(nil))
            XCTAssertTrue(store.model.phase.isActive)
            XCTAssertEqual(store.view.layout?.style, style)
            guard let scope = store.view.scope else { return XCTFail("Missing active session") }
            store.send(.setMenuStyle(style == .pie ? .selectedMessage : .pie))
            XCTAssertEqual(store.view.layout?.style, style)
            store.send(.activate(scope, "red", .keyboard))
            XCTAssertEqual(store.outputs.last, .completed(scope.session, .selected(
                Choice(menuPath: ["root"], itemID: "red", value: "red"))))
        }
    }

    func testShutdownStopsSourcesBeforeCleanupAndPublishesResultsInOrder() async {
        await MainActor.run {
            let window = FakeWindow(), controller = FakeController(), clock = FakeClock()
            let store = Store(menu: SampleMenu.definition, window: window, controller: controller,
                              scheduler: clock, movementClock: clock)
            store.send(.open(nil))
            let scope = store.view.scope!
            window.synchronous = false
            window.inspectDismissal = {
                XCTAssertEqual(controller.stops, 1)
                XCTAssertTrue(clock.movement.isEmpty)
                XCTAssertFalse(store.model.running)
                XCTAssertTrue(store.outputs.isEmpty)
            }
            window.inspectRelease = {
                XCTAssertEqual(controller.stops, 1)
                XCTAssertEqual(store.model.phase, .idle)
                XCTAssertFalse(store.model.running)
            }
            store.send(.stop)
            guard case .stopping(let shutdown) = store.model.lifecycle else { return XCTFail("Not stopping") }
            let dismissal = store.model.phase.operation!
            XCTAssertEqual(clock.delays[shutdown.deadline], 4)
            XCTAssertEqual(clock.delays[dismissal], 3)
            XCTAssertEqual(Set(clock.scheduled.keys), [shutdown.deadline, dismissal])
            XCTAssertTrue(window.released.isEmpty)
            window.receive?(.dismissed(dismissal))
            XCTAssertEqual(store.outputs, [.completed(scope.session, .cancelled(.applicationStopping))])
            XCTAssertEqual(window.released.count, 1)
            XCTAssertEqual(Set(clock.scheduled.keys), [shutdown.deadline])
            window.receive?(.resourcesReleased(window.released[0]))
            XCTAssertEqual(store.outputs.last, .shutdownCompleted(.completed))
            XCTAssertTrue(clock.scheduled.isEmpty)
            XCTAssertTrue(clock.movement.isEmpty)
            XCTAssertEqual(store.model.lifecycle, .stopped(.completed))
        }
    }

    func testMissingReleaseUsesOriginalOverallDeadlineAndLateCallbacksCannotSucceed() async {
        await MainActor.run {
            let window = FakeWindow(), controller = FakeController(), clock = FakeClock()
            window.synchronous = false
            let store = Store(menu: SampleMenu.definition, window: window, controller: controller,
                              scheduler: clock, movementClock: clock)
            store.send(.start)
            store.send(.stop)
            guard case .stopping(let shutdown) = store.model.lifecycle else { return XCTFail("Not stopping") }
            let fire = clock.scheduled[shutdown.deadline]!
            let originalRelease = window.released[0]
            store.send(.stop)
            XCTAssertEqual(clock.delays.count, 1)
            XCTAssertEqual(window.released, [originalRelease])
            fire(.deadline(shutdown.deadline))
            XCTAssertEqual(store.outputs, [.shutdownCompleted(.failed("Application shutdown timed out"))])
            XCTAssertEqual(window.released.count, 2)
            XCTAssertGreaterThan(window.released[1], originalRelease)
            XCTAssertTrue(clock.scheduled.isEmpty)
            let stopped = store.model
            window.receive?(.resourcesReleased(originalRelease))
            window.receive?(.resourcesReleased(window.released[1]))
            fire(.deadline(shutdown.deadline))
            XCTAssertEqual(store.model, stopped)
            XCTAssertEqual(store.outputs.count, 1)
            XCTAssertEqual(controller.starts, 1)
            XCTAssertEqual(controller.stops, 1)
        }
    }

    func testMovementClockStopsAndQueuedTickCannotMoveAfterNeutralOrShutdown() async {
        await MainActor.run {
            let window = FakeWindow(), controller = FakeController(), clock = FakeClock()
            let store = Store(menu: SampleMenu.definition, window: window, controller: controller,
                              scheduler: clock, movementClock: clock)
            let id = ConnectionID(1)
            func frame(_ n: UInt64, _ time: Double, _ right: Vector) -> ControllerFrame {
                ControllerFrame(sequence: n, timestamp: time, stick: .zero, buttons: [],
                                rightStick: right, observedAt: time)
            }
            store.send(.connected(ControllerInfo(id: id, name: "Fixture", supported: true,
                                                 supportsMovement: true), frame(0, 0, .zero)))
            store.send(.open(id))
            let scope = store.view.scope!
            store.send(.placementObserved(scope, Placement(layout: 1, screenID: "screen",
                bounds: Rect(x: 0, y: 0, width: 2000, height: 1000),
                frame: Rect(x: 400, y: 200, width: 360, height: 360))))
            store.send(.baseline(id, scope, frame(1, 0, .zero)))
            store.send(.controllerFrame(id, scope, frame(2, 1, Vector(x: 1, y: 0)), true))
            let movement = store.model.movement.activity!.id
            let deliver = clock.movement[movement]!
            XCTAssertEqual(clock.movement.count, 1)
            deliver(.movementTick(movement, 1.05))
            XCTAssertEqual(store.model.movement.placement!.frame.x, 520, accuracy: 1e-8)
            store.send(.controllerFrame(id, scope, frame(3, 1.1, .zero), true))
            XCTAssertTrue(clock.movement.isEmpty)
            XCTAssertTrue(clock.scheduled.isEmpty)
            let stopped = store.model
            deliver(.movementTick(movement, 1.2))
            XCTAssertEqual(store.model, stopped)
            store.send(.controllerFrame(id, scope, frame(4, 2, Vector(x: 1, y: 0)), true))
            XCTAssertEqual(clock.movement.count, 1)
            store.send(.stop)
            XCTAssertTrue(clock.movement.isEmpty)
            XCTAssertEqual(clock.stoppedMovement.count, 2)
            XCTAssertTrue(clock.scheduled.isEmpty)
        }
    }

    func testStoppingClosesAnActiveInteractionAndStopsMonitoringOnce() async {
        await MainActor.run {
            let window = FakeWindow(), controller = FakeController(), clock = FakeClock()
            let store = Store(menu: SampleMenu.definition, window: window, controller: controller, scheduler: clock, movementClock: clock)
            store.send(.open(nil))
            let scope = store.view.scope!
            store.send(.stop)
            store.send(.stop)
            XCTAssertEqual(store.outputs, [.completed(scope.session, .cancelled(.applicationStopping)),
                                           .shutdownCompleted(.completed)])
            XCTAssertEqual(controller.stops, 1)
            XCTAssertTrue(clock.scheduled.isEmpty)
            XCTAssertFalse(store.model.canOpen)
            store.send(.open(nil))
            XCTAssertEqual(store.outputs.last, .rejected(.stopped))
        }
    }

    func testSynchronousEffectsSeeCommittedModelAndReentrantOpenIsQueued() async {
        await MainActor.run {
            let window = FakeWindow(), controller = FakeController(), clock = FakeClock()
            let store = Store(menu: SampleMenu.definition, window: window, controller: controller, scheduler: clock, movementClock: clock)
            window.inspect = { XCTAssertEqual(store.model.phase.name, "Presenting") }
            store.onOutput = { output in
                if case .completed = output { store.send(.open(nil)) }
            }
            store.send(.open(nil))
            let scope = store.view.scope!
            store.send(.activate(scope, "red", .accessibility))
            XCTAssertEqual(store.outputs.count, 1)
            XCTAssertEqual(store.view.scope?.session, SessionID(2))
            XCTAssertTrue(store.model.phase.isActive)
            XCTAssertEqual(window.dismissed.count, 1)
            XCTAssertTrue(clock.scheduled.isEmpty)
            XCTAssertEqual(controller.starts, 1)
        }
    }

    func testDeadlineFailureCannotBecomeLateSuccess() async {
        await MainActor.run {
            let window = FakeWindow(), controller = FakeController(), clock = FakeClock()
            window.synchronous = false
            let store = Store(menu: SampleMenu.definition, window: window, controller: controller, scheduler: clock, movementClock: clock)
            store.send(.open(nil))
            let operation = store.model.phase.operation!
            let fire = clock.scheduled[operation]!
            fire(.deadline(operation))
            window.receive?(.presented(operation))
            XCTAssertEqual(store.model.phase.name, "Dismissing")
            let cleanup = store.model.phase.operation!
            clock.scheduled[cleanup]?(.deadline(cleanup))
            XCTAssertEqual(store.model.phase.name, "Unavailable")
            window.receive?(.dismissed(cleanup))
            XCTAssertEqual(store.outputs.count, 1)
        }
    }

    func testOverflowPreservesInputLossAndCancelsInsteadOfConfirming() async {
        await MainActor.run {
            let window = FakeWindow(), controller = FakeController(), clock = FakeClock()
            let store = Store(menu: SampleMenu.definition, window: window, controller: controller,
                              scheduler: clock, movementClock: clock, inputCapacity: 2)
            let connection = ConnectionID(1)
            func frame(_ n: UInt64) -> ControllerFrame {
                ControllerFrame(sequence: n, timestamp: Double(n), stick: .zero, buttons: [.confirm], observedAt: Double(n))
            }
            store.send(.connected(ControllerInfo(id: connection, name: "Test", supported: true), frame(0)))
            store.send(.open(connection))
            let scope = store.view.scope!
            store.send(.select(scope, "red", .keyboard))
            store.send((1...20).map { .controllerFrame(connection, scope, frame(UInt64($0)), true) })
            XCTAssertEqual(store.outputs, [.completed(scope.session, .cancelled(.inputLost))])
            XCTAssertEqual(controller.resets, [connection])
        }
    }
}
