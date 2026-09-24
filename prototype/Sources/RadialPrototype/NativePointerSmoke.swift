import AppKit
import RadialCore

extension NativeSmoke {
    func exercisePointerAndMixedInput() async throws {
        let initialResults = store.outputs.count
        store.send(.open(nil))
        try await wait("mixed-input presentation") { self.store.model.phase.isActive }
        let root = try scope()
        let stationary = NSEvent.mouseLocation
        key(code: 124, characters: "\u{F703}")
        try await wait("keyboard before movement") { self.store.view.selectedID == "red" }
        let before = panel.frame
        _ = try await exerciseMovement(scope: root)
        try await mouse(at: stationary)
        try check(panel.frame != before && store.view.selectedID == "red",
                  "Native window movement under a stationary pointer preserves keyboard selection")

        let blue = try screenPoint(itemID: "blue")
        try await mouse(at: blue)
        try check(store.view.selectedID == "blue" && store.model.phase.session?.selection?.source == .pointer,
                  "Native mouse movement selects the item under the pointer")
        key(code: 124, characters: "\u{F703}")
        try await wait("keyboard after hover") { self.store.view.selectedID == "green" }
        try await mouse(at: blue)
        try await mouse(at: NSPoint(x: blue.x + 0.5, y: blue.y))
        try check(store.view.selectedID == "green", "Stationary pointer and subthreshold motion preserve a keyboard choice")
        try await mouse(at: NSPoint(x: blue.x + 2, y: blue.y))
        try check(store.view.selectedID == "blue", "Accumulated deliberate pointer motion takes selection back")

        let connection = ConnectionID(UInt64.max - 1)
        func frame(_ sequence: UInt64, stick: Vector, buttons: Set<ControllerButton> = []) -> ControllerFrame {
            let now = ProcessInfo.processInfo.systemUptime
            return ControllerFrame(sequence: sequence, timestamp: now, stick: stick, buttons: buttons, observedAt: now)
        }
        store.send(.controllerFrame(connection, root, frame(4, stick: Vector(x: 0, y: 1)), true))
        try check(store.view.selectedID == "red", "A deliberate stick change takes selection from the pointer")
        try await mouse(at: blue)
        store.send(.controllerFrame(connection, root, frame(5, stick: Vector(x: 0, y: 1)), true))
        store.send(.controllerFrame(connection, root, frame(6, stick: .zero), true))
        try check(store.view.selectedID == "blue", "Stationary stick and neutral release preserve pointer selection")

        try await click(itemID: "more")
        try await wait("clicked submenu") { self.store.model.phase.isActive && self.store.view.title == "More colors" }
        let child = try scope()
        try check(child.session == root.session && child.revision > root.revision && store.view.selectedID == nil,
                  "Native click enters its named submenu despite a different hover selection")
        store.send(.baseline(connection, child, frame(7, stick: Vector(x: 0, y: 1))))
        try await mouse(at: screenPoint(itemID: "violet"))
        try check(store.view.selectedID == "violet", "Native hover selects a submenu item after its new baseline")
        store.send(.controllerFrame(connection, child, frame(8, stick: Vector(x: 0, y: 1), buttons: [.confirm]), true))
        try await wait("mixed-input completion") { self.store.model.phase == .idle }
        try check(store.outputs.count == initialResults + 1 && store.outputs.last == .completed(root.session, .selected(
            Choice(menuPath: ["root", "colors"], itemID: "violet", value: "violet"))),
                  "Pointer selection and controller confirmation emit exactly one correct submenu result")
        store.send(.disconnected(connection))

        store.send(.open(nil))
        try await wait("Escape submenu setup") { self.store.model.phase.isActive }
        let escapeSession = try scope().session
        try await click(itemID: "more")
        try await wait("Escape submenu presentation") { self.store.model.phase.isActive && self.store.view.title == "More colors" }
        key(code: 53, characters: "\u{1b}")
        try await wait("Escape from submenu") { self.store.model.phase == .idle }
        try check(!panel.isVisible && store.outputs.count == initialResults + 2 &&
                  store.outputs.last == .completed(escapeSession, .cancelled(.user)),
                  "Native Escape from a submenu cancels the whole interaction exactly once")

        store.send(.open(nil))
        try await wait("click result setup") { self.store.model.phase.isActive }
        let clickSession = try scope().session
        try await mouse(at: screenPoint(itemID: "blue"))
        try check(store.view.selectedID == "blue", "Hover establishes a different selection before the click test")
        try await click(itemID: "green")
        try await wait("named click completion") { self.store.model.phase == .idle }
        try check(store.outputs.count == initialResults + 3 && store.outputs.last == .completed(clickSession, .selected(
            Choice(menuPath: ["root"], itemID: "green", value: "green"))),
                  "Native click activates Green even when Blue was selected")
    }

    func itemPoint(_ id: String) throws -> Vector {
        guard let bounds = store.view.layout?.labels.first(where: { $0.itemID == id })?.bounds else {
            throw ProbeFailure("No label bounds for \(id)")
        }
        return Vector(x: bounds.x + bounds.width / 2, y: bounds.y + bounds.height / 2)
    }

    func screenPoint(itemID: String) throws -> NSPoint {
        let point = try itemPoint(itemID)
        return try screenPoint(x: point.x, y: point.y)
    }

    func click(itemID: String) async throws {
        let point = try itemPoint(itemID)
        try await click(x: point.x, y: point.y)
    }

    func screenPoint(x: Double, y: Double) throws -> NSPoint {
        guard let frame = panel.frame else { throw ProbeFailure("No menu frame") }
        return NSPoint(x: frame.midX + x, y: frame.midY - y)
    }

    func mouse(at screen: NSPoint) async throws {
        let previous = store.model.pointer.latest?.sequence ?? 0
        try postMouse(.mouseMoved, at: screen)
        try await wait("native pointer observation") { (self.store.model.pointer.latest?.sequence ?? 0) > previous }
        let observed = store.model.pointer.latest?.screenPosition
        guard let observed, observed.distance(to: Vector(x: screen.x, y: screen.y)) < 1e-6 else {
            throw ProbeFailure("Native pointer location mismatch: expected \(screen), observed \(String(describing: observed))")
        }
    }

    func click(x: Double, y: Double) async throws {
        let screen = try screenPoint(x: x, y: y)
        try postMouse(.leftMouseDown, at: screen)
        try postMouse(.leftMouseUp, at: screen)
    }

    private func postMouse(_ type: NSEvent.EventType, at screen: NSPoint) throws {
        guard let window = panel.content?.window,
              let event = NSEvent.mouseEvent(with: type, location: window.convertPoint(fromScreen: screen),
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 0) else {
            throw ProbeFailure("Cannot construct app-local mouse event")
        }
        guard let actual = event.cgEvent?.unflippedLocation,
              hypot(actual.x - screen.x, actual.y - screen.y) < 1e-6 else {
            throw ProbeFailure("App-local mouse coordinate mismatch: requested \(screen), event \(String(describing: event.cgEvent?.unflippedLocation))")
        }
        NSApp.postEvent(event, atStart: false)
    }
}
