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
            store.send(.activate(second, "more", .accessibility))
            try await wait("submenu presentation") {
                self.store.model.phase.isActive && self.store.view.title == "More colors"
            }
            let child = try scope()
            try check(child.session == second.session && child.revision > second.revision,
                      "Submenu retains the session and receives a new input scope")
            try panel.saveRendering(to: report.deletingLastPathComponent().appendingPathComponent("submenu.png"))
            store.send(.activate(child, "violet", .accessibility))
            try await wait("submenu dismissal") { self.store.model.phase == .idle }
            try check(store.outputs.last == .completed(second.session, .selected(
                Choice(menuPath: ["root", "colors"], itemID: "violet", value: "violet"))),
                      "Explicit submenu activation returns its stable item identity")

            store.send(.open(nil))
            try await wait("cancel presentation") { self.store.model.phase.isActive }
            key(code: 53, characters: "\u{1b}")
            try await wait("Escape dismissal") { self.store.model.phase == .idle }
            try check(!panel.isVisible && store.outputs.count == 3, "Escape cancels exactly one interaction")
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
            "limits": ["Scripted native keyboard and application events, not physical controller presses",
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

    private func check(_ condition: Bool, _ description: String) throws {
        guard condition else { throw ProbeFailure(description) }
        checks.append(description)
    }

    private func wait(_ description: String, until condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !condition() {
            guard ContinuousClock.now < deadline else {
                throw ProbeFailure("Timed out waiting for \(description); phase: \(store.model.phase)")
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        // Let the committed render update reach the native hosting view.
        await Task.yield()
    }

    private func scope() throws -> InputScope {
        guard let scope = store.view.scope else { throw ProbeFailure("No current scope") }
        return scope
    }

    private func operation() throws -> OperationID {
        guard let operation = panel.currentOperation else { throw ProbeFailure("No native operation") }
        return operation
    }

    private func key(code: UInt16, characters: String) {
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

private struct ProbeFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
