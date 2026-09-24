import AppKit
import RadialCore
import RadialRuntime
import RadialMac

/// Runs scripted inputs through a real NSPanel and SwiftUI view on a logged-in Mac.
/// Physical controller operation and VoiceOver behavior remain separate checks.
@MainActor final class NativeSmoke {
    let store: Store
    let panel: PanelAdapter
    private var checks: [String] = []

    init(store: Store, panel: PanelAdapter) { self.store = store; self.panel = panel }

    func run(report: URL) async -> Bool {
        var errorMessage: String?
        let previousApplication = NSWorkspace.shared.frontmostApplication?.processIdentifier
        do {
            store.send(.open(nil))
            try await wait("root presentation") { self.store.model.phase.isActive }
            try check(panel.isVisible && panel.isKey, "Root panel is visible and key after content acknowledgment")
            let root = try scope()
            try panel.saveRendering(to: report.deletingLastPathComponent().appendingPathComponent("root-menu.png"))

            // App-local NSEvents exercise the SwiftUI keyboard path, without global event injection.
            key(code: 124, characters: "\u{F703}")
            try await wait("keyboard selection") { self.store.view.selectedID == "red" }
            try check(store.view.selectedID == "red", "Native right-arrow event selects the first item")
            try panel.saveRendering(to: report.deletingLastPathComponent().appendingPathComponent("selected-menu.png"))
            key(code: 36, characters: "\r")
            try await wait("keyboard dismissal") { self.store.model.phase == .idle }
            try check(store.outputs.last == .completed(root.session, .selected(
                Choice(menuPath: ["root"], itemID: "red", value: "red"))), "Return produces the selected result after dismissal")
            try check(!panel.isVisible, "Completed interaction leaves no visible panel")
            let firstDismissal = try operation()
            if let previousApplication, previousApplication != ProcessInfo.processInfo.processIdentifier {
                try check(NSWorkspace.shared.frontmostApplication?.processIdentifier == previousApplication,
                          "Previously active application regains focus")
            }

            store.send(.open(nil))
            try await wait("second presentation") { self.store.model.phase.isActive }
            let second = try scope()
            panel.dismiss(scope: root, operation: firstDismissal)
            try check(panel.isVisible && store.model.phase.isActive, "Obsolete native dismissal cannot hide a newer session")
            let obsoleteMove = try await exerciseMovement(scope: second)
            store.send(.activate(second, "more", .accessibility))
            try await wait("submenu presentation") {
                self.store.model.phase.isActive && self.store.view.title == "More colors"
            }
            let child = try scope()
            try check(child.session == second.session && child.revision > second.revision,
                      "Submenu retains the session and receives a new input scope")
            let childFrame = panel.frame
            panel.move(scope: second, placement: obsoleteMove.placement, operation: obsoleteMove.operation)
            try check(panel.frame == childFrame, "A move from the parent menu cannot move the submenu")
            try panel.saveRendering(to: report.deletingLastPathComponent().appendingPathComponent("submenu.png"))
            store.send(.activate(child, "violet", .accessibility))
            try await wait("submenu dismissal") { self.store.model.phase == .idle }
            try check(store.outputs.last == .completed(second.session, .selected(
                Choice(menuPath: ["root", "colors"], itemID: "violet", value: "violet"))),
                      "Explicit submenu activation returns its stable item identity")
            store.send(.disconnected(ConnectionID(UInt64.max - 1)))

            store.send(.open(nil))
            try await wait("cancel presentation") { self.store.model.phase.isActive }
            key(code: 53, characters: "\u{1b}")
            try await wait("Escape dismissal") { self.store.model.phase == .idle }
            try check(!panel.isVisible && store.outputs.count == 3, "Escape cancels exactly one interaction")
            try await exercisePointerAndMixedInput()
            try await exerciseControllerReconnection()
        } catch {
            errorMessage = String(describing: error)
        }
        let result: [String: Any] = [
            "passed": errorMessage == nil,
            "checks": checks,
            "error": errorMessage as Any? ?? NSNull(),
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "controllers": store.model.controllers.values.map {
                ["name": $0.info.name, "supported": $0.info.supported, "controls": $0.info.detail] as [String: Any]
            },
            "trace": store.trace,
            "outputs": store.outputs.map { String(describing: $0) },
            "limits": ["App-local scripted mouse and keyboard events and controller value fixtures; not physical input",
                       "VoiceOver, display changes, and device disconnection require separate observation"]
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: report, options: .atomic)
        } catch {
            FileHandle.standardError.write(Data("Cannot write smoke report: \(error)\n".utf8))
            return false
        }
        return errorMessage == nil
    }

    func check(_ condition: Bool, _ description: String) throws {
        guard condition else { throw ProbeFailure(description) }
        checks.append(description)
    }

    func wait(_ description: String, timeout: Double = 5, until condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
        while !condition() {
            guard ContinuousClock.now < deadline else {
                throw ProbeFailure("Timed out waiting for \(description); phase: \(store.model.phase)")
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        // Let the committed render update reach the native hosting view.
        await Task.yield()
    }

    func exerciseMovement(scope: InputScope) async throws -> (placement: Placement, operation: OperationID) {
        guard let initial = panel.currentPlacement else { throw ProbeFailure("Missing initial placement") }
        let connection = ConnectionID(UInt64.max - 1)
        func frame(_ sequence: UInt64, right: Vector = .zero) -> ControllerFrame {
            let now = ProcessInfo.processInfo.systemUptime
            return ControllerFrame(sequence: sequence, timestamp: now, stick: .zero, buttons: [],
                                   rightStick: right, observedAt: now)
        }
        store.send(.connected(ControllerInfo(id: connection, name: "Scripted movement fixture",
                                             supported: true, supportsMovement: true), frame(0)))
        store.send(.baseline(connection, scope, frame(1)))
        guard let leftEdge = initial.desktop.move(initial.frame, by: Vector(x: -initial.bounds.width, y: 0)),
              let rightEdge = initial.desktop.move(initial.frame, by: Vector(x: initial.bounds.width, y: 0)) else {
            throw ProbeFailure("No valid desktop movement interval")
        }
        let left = initial.frame.x - leftEdge.x
        let right = rightEdge.x - initial.frame.x
        let direction = (left >= 25 && left < right) || right < 25 ? -1.0 : 1.0
        let distance = direction < 0 ? left : right
        try check(distance >= 25, "Desktop has room for a visible movement test")
        store.send(.controllerFrame(connection, scope, frame(2, right: Vector(x: direction, y: 0)), true))
        guard let movement = store.model.movement.activity?.id else {
            throw ProbeFailure("Scripted right-stick input did not start movement")
        }
        try await wait("real movement clock") {
            abs((self.panel.frame.map { Double($0.minX) } ?? initial.frame.x) - initial.frame.x) >= 20
        }
        try check(panel.frame.map { Double($0.minY) } == initial.frame.y,
                  "Right-stick input moves the native panel horizontally using real ticks")
        let targetX = direction < 0 ? leftEdge.x : rightEdge.x
        try await wait("desktop edge", timeout: distance / store.model.movementSettings.speed + 3) {
            abs((self.panel.frame.map { Double($0.minX) } ?? initial.frame.x) - targetX) < 0.01
        }
        guard let nativeFrame = panel.frame else { throw ProbeFailure("No native frame at screen edge") }
        try check(initial.desktop.contains(Rect(x: nativeFrame.minX, y: nativeFrame.minY,
                      width: nativeFrame.width, height: nativeFrame.height)),
                  "The complete native panel stops at the desktop edge")
        let oldOperation = try operation()
        store.send(.controllerFrame(connection, scope, frame(3), true))
        let stopped = panel.frame
        try await Task.sleep(for: .milliseconds(80))
        store.send(.movementTick(movement, ProcessInfo.processInfo.systemUptime))
        panel.move(scope: scope, placement: initial, operation: oldOperation)
        try check(panel.frame == stopped && store.model.movement.activity == nil,
                  "Neutral stops the clock and obsolete ticks and native moves have no effect")
        return (initial, oldOperation)
    }

    func scope() throws -> InputScope {
        guard let scope = store.view.scope else { throw ProbeFailure("No current scope") }
        return scope
    }

    private func operation() throws -> OperationID {
        guard let operation = panel.currentOperation else { throw ProbeFailure("No native operation") }
        return operation
    }

    func key(code: UInt16, characters: String) {
        guard let window = NSApp.keyWindow else { return }
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            if let event = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, characters: characters, charactersIgnoringModifiers: characters,
                isARepeat: false, keyCode: code) {
                NSApp.sendEvent(event)
            }
        }
    }
}

struct ProbeFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
