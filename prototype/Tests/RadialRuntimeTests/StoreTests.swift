import XCTest
import RadialCore
@testable import RadialRuntime

@MainActor private final class FakeWindow: WindowDriver {
    var receive: EventReceiver?
    var synchronous = true
    var presented: [OperationID] = []
    var dismissed: [OperationID] = []
    var inspect: (() -> Void)?
    func present(scope: InputScope, operation: OperationID) {
        inspect?(); presented.append(operation)
        if synchronous { receive?(.presented(operation)) }
    }
    func inspectPresentation(scope: InputScope, operation: OperationID) {}
    func dismiss(scope: InputScope, operation: OperationID) {
        dismissed.append(operation)
        if synchronous { receive?(.dismissed(operation)) }
    }
    func recover(operation: OperationID) { if synchronous { receive?(.recovered(operation)) } }
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
@MainActor private final class FakeClock: DeadlineScheduler {
    var scheduled: [OperationID: EventReceiver] = [:]
    var cancelled: [OperationID] = []
    func schedule(operation: OperationID, after seconds: Double, receive: @escaping EventReceiver) {
        scheduled[operation] = receive
    }
    func cancel(operation: OperationID) { cancelled.append(operation); scheduled.removeValue(forKey: operation) }
}

final class StoreTests: XCTestCase {
    func testStoppingClosesAnActiveInteractionAndStopsMonitoringOnce() async {
        await MainActor.run {
            let window = FakeWindow(), controller = FakeController(), clock = FakeClock()
            let store = Store(menu: SampleMenu.definition, window: window, controller: controller, scheduler: clock)
            store.send(.open(nil))
            let scope = store.view.scope!
            store.send(.stop)
            store.send(.stop)
            XCTAssertEqual(store.outputs, [.completed(scope.session, .cancelled(.applicationStopping))])
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
            let store = Store(menu: SampleMenu.definition, window: window, controller: controller, scheduler: clock)
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
            let store = Store(menu: SampleMenu.definition, window: window, controller: controller, scheduler: clock)
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
                              scheduler: clock, inputCapacity: 2)
            let connection = ConnectionID(1)
            func frame(_ n: UInt64) -> ControllerFrame {
                ControllerFrame(sequence: n, timestamp: Double(n), stick: .zero, buttons: [.confirm])
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
