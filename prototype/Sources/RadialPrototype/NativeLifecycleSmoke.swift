import AppKit
import RadialCore

extension NativeSmoke {
    func exerciseControllerReconnection() async throws {
        let old = ConnectionID(UInt64.max - 4), fresh = ConnectionID(UInt64.max - 3)
        func frame(_ sequence: UInt64, buttons: Set<ControllerButton> = [],
                   stick: Vector = .zero, right: Vector = .zero) -> ControllerFrame {
            let time = ProcessInfo.processInfo.systemUptime
            return ControllerFrame(sequence: sequence, timestamp: time, stick: stick,
                                   buttons: buttons, rightStick: right, observedAt: time)
        }
        func info(_ id: ConnectionID) -> ControllerInfo {
            ControllerInfo(id: id, name: "Reconnection fixture", supported: true, supportsMovement: true)
        }
        let before = store.outputs.count
        store.send(.connected(info(old), frame(0)))
        store.send(.open(old))
        try await wait("disconnect fixture presentation") { self.store.model.phase.isActive }
        let previous = try scope()
        store.send(.baseline(old, previous, frame(1)))
        guard let placement = store.model.movement.placement else { throw ProbeFailure("No placement") }
        let initial = panel.frame
        let direction = placement.frame.x > placement.bounds.x ? -1.0 : 1.0
        store.send(.controllerFrame(old, previous, frame(2, right: Vector(x: direction, y: 0)), true))
        try await wait("movement before controller loss") { self.panel.frame != initial }
        guard let movement = store.model.movement.activity?.id,
              let operation = panel.currentOperation else { throw ProbeFailure("Movement was not active") }
        store.send(.disconnected(old))
        try await wait("controller-loss dismissal") { self.store.model.phase == .idle }
        try check(!panel.isVisible && store.model.movement.activity == nil &&
                  Array(store.outputs.dropFirst(before)) == [.completed(previous.session, .cancelled(.controllerLost))],
                  "Controller loss during native movement hides the panel and cancels exactly once")

        store.send(.connected(info(fresh), frame(0, buttons: [.menu, .confirm])))
        store.send(.controllerFrame(fresh, nil, frame(1, buttons: [.menu, .confirm]), true))
        try check(store.model.phase == .idle, "Held buttons on a new connection cannot open the menu")
        store.send(.controllerFrame(fresh, nil, frame(2), true))
        store.send(.controllerFrame(fresh, nil, frame(3, buttons: [.menu]), true))
        try await wait("reconnected presentation") { self.store.model.phase.isActive }
        let current = try scope()
        store.send(.baseline(fresh, current, frame(4, buttons: [.confirm])))
        let currentFrame = panel.frame
        store.send(.controllerFrame(old, previous, frame(3, buttons: [.menu, .confirm]), true))
        store.send(.disconnected(old))
        store.send(.movementTick(movement, ProcessInfo.processInfo.systemUptime))
        panel.move(scope: previous, placement: placement, operation: operation)
        panel.dismiss(scope: previous, operation: operation)
        try check(panel.isVisible && panel.frame == currentFrame && store.model.phase.session?.owner == fresh,
                  "Old controller callbacks, ticks, movement, and dismissal cannot affect the new session")
        store.send(.controllerFrame(fresh, current, frame(5, buttons: [.confirm], stick: Vector(x: 0, y: 1)), true))
        try check(store.model.phase.isActive && store.view.selectedID == "red",
                  "Confirm held across the new baseline cannot commit a choice")
        store.send(.controllerFrame(fresh, current, frame(6, stick: Vector(x: 0, y: 1)), true))
        store.send(.controllerFrame(fresh, current, frame(7, buttons: [.confirm], stick: Vector(x: 0, y: 1)), true))
        try await wait("reconnected confirmation") { self.store.model.phase == .idle }
        try check(Array(store.outputs.dropFirst(before)) == [
            .completed(previous.session, .cancelled(.controllerLost)),
            .completed(current.session, .selected(Choice(menuPath: ["root"], itemID: "red", value: "red")))
        ], "A fresh Confirm press on the reconnected controller produces one new choice")
        store.send(.disconnected(fresh))
    }
}
