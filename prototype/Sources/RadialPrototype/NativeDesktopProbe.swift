import AppKit
import SwiftUI
import RadialCore
import RadialRuntime
import RadialMac

@MainActor private final class DesktopProbeController: ControllerDriver {
    var receive: EventReceiver?
    func start() {}
    func stop() {}
    func baseline(scope: InputScope) {}
    func endInput(scope: InputScope) {}
    func resetInput(connection: ConnectionID) {}
}

/// Explicit times make each displacement independently checkable. Window
/// creation, presentation, movement, focus, and acknowledgments remain native.
@MainActor private final class DesktopProbeClock: MovementScheduler {
    func startMovement(id: MovementID, receive: @escaping EventReceiver) {}
    func stopMovement(id: MovementID) {}
}

@MainActor enum NativeDesktopProbe {
    static func run(directory: URL, preview: Bool) async -> Bool {
        let panel = PanelAdapter(measurer: SwiftUIMenuMeasurer()), clock = TaskScheduler()
        let store = Store(menu: SubmenuDemo.definition, menuStyle: .recenteredFloatingLabels,
            window: panel, controller: DesktopProbeController(), scheduler: clock, movementClock: DesktopProbeClock())
        panel.content = NSHostingView(rootView: MenuContainer(store: store))
        let probe = NativeSmoke(store: store, panel: panel)
        let connection = ConnectionID(1)
        var sequence: UInt64 = 0, time = 0.0
        var samples: [[String: Any]] = [], checks: [String] = []
        var failure: String?
        func frame(right: Vector = .zero) -> ControllerFrame {
            sequence += 1
            return ControllerFrame(sequence: sequence, timestamp: time, stick: .zero,
                buttons: [], rightStick: right, observedAt: time)
        }
        func current() throws -> Rect {
            guard let native = panel.frame else { throw ProbeFailure("No native desktop frame") }
            return Rect(x: native.minX, y: native.minY, width: native.width, height: native.height)
        }
        func move(to target: Vector) async throws {
            let scope = try probe.scope(), selected = store.view.selectedID
            // Move vertically into the shared corridor before traversing it.
            for horizontal in [false, true] {
                let start = try current()
                let distance = horizontal ? target.x - start.x : target.y - start.y
                guard abs(distance) > 0.001 else { continue }
                let sign = distance > 0 ? 1.0 : -1.0
                store.send(.controllerFrame(connection, scope,
                    frame(right: Vector(x: horizontal ? sign : 0, y: horizontal ? 0 : sign)), true))
                guard let id = store.model.movement.activity?.id else { throw ProbeFailure("Movement did not arm") }
                var remaining = abs(distance)
                while remaining > 0.001 {
                    let before = try current(), step = min(remaining, 120)
                    time += step / 2400
                    store.send(.movementTick(id, time))
                    // Let AppKit deliver window and focus notifications between
                    // steps instead of testing only synchronous setFrame calls.
                    try await Task.sleep(for: .milliseconds(20))
                    let after = try current()
                    guard abs(after.x - before.x - (horizontal ? sign * step : 0)) < 0.01,
                          abs(after.y - before.y - (horizontal ? 0 : sign * step)) < 0.01,
                          store.model.phase.isActive, store.view.scope == scope,
                          store.view.selectedID == selected, panel.isKey, panel.isVisible, store.outputs.isEmpty else {
                        throw ProbeFailure("Native crossing mismatch: before=\(before), after=\(after), step=\(sign * step), horizontal=\(horizontal), phase=\(store.model.phase.name), scope=\(String(describing: store.view.scope)), expectedScope=\(scope), selected=\(String(describing: store.view.selectedID)), expectedSelected=\(String(describing: selected)), key=\(panel.isKey), outputs=\(store.outputs), trace=\(store.trace.suffix(8))")
                    }
                    samples.append(["frame": [after.x, after.y, after.width, after.height],
                                    "menu": store.view.title, "screen": store.model.movement.placement!.screenID])
                    remaining -= step
                }
                store.send(.controllerFrame(connection, scope, frame(), true))
                let stopped = try current()
                store.send(.movementTick(id, time + 1))
                guard store.model.movement.activity == nil, try current() == stopped else {
                    throw ProbeFailure("Release failed to stop movement across displays")
                }
            }
        }
        do {
            let screens = NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
            guard let pair = zip(screens, screens.dropFirst()).first(where: {
                abs($0.frame.maxX - $1.frame.minX) < 0.01 &&
                min($0.visibleFrame.maxY, $1.visibleFrame.maxY) - max($0.visibleFrame.minY, $1.visibleFrame.minY) > 600
            }) else { throw ProbeFailure("This native probe requires horizontally adjacent displays with at least 600 points of shared height") }
            store.send(.connected(ControllerInfo(id: connection, name: "Desktop crossing fixture",
                supported: true, supportsMovement: true), frame()))
            store.send(.open(connection))
            try await probe.wait("desktop probe root") { store.model.phase.isActive }
            for item in ["commands", "windows", "research-layout"] {
                let scope = try probe.scope()
                store.send(.activate(scope, item, .keyboard))
                try await probe.wait("desktop probe submenu") { store.model.phase.isActive && store.view.scope != scope }
            }
            store.send(.baseline(connection, try probe.scope(), frame()))
            store.send(.select(try probe.scope(), "references-left", .keyboard))
            let original = try current(), seam = pair.0.frame.maxX
            let low = max(pair.0.visibleFrame.minY, pair.1.visibleFrame.minY)
            let high = min(pair.0.visibleFrame.maxY, pair.1.visibleFrame.maxY)
            guard original.height <= high - low,
                  original.width + 80 <= pair.0.visibleFrame.width,
                  original.width + 80 <= pair.1.visibleFrame.width else {
                throw ProbeFailure("The submenu must fit completely on both displays for this native probe")
            }
            let y = floor((low + high - original.height) / 2)
            let left = seam - original.width - 40, right = seam + 40
            try await move(to: Vector(x: left, y: y))
            try await move(to: Vector(x: seam - original.width / 2, y: y))
            let straddling = try current()
            guard straddling.x < seam, straddling.x + straddling.width > seam else {
                throw ProbeFailure("The native frame did not straddle the seam")
            }
            try panel.saveRendering(to: directory.appendingPathComponent("straddling-content.png"))
            checks.append("Four-level menu straddles the shared edge with selection and scope preserved")
            if preview {
                try Data("Ready for visual inspection. Create continue.txt to resume.\n".utf8)
                    .write(to: directory.appendingPathComponent("preview-ready.txt"))
                let deadline = ContinuousClock.now.advanced(by: .seconds(180))
                while !FileManager.default.fileExists(atPath: directory.appendingPathComponent("continue.txt").path) {
                    guard store.model.phase.isActive, panel.isVisible, panel.isKey else {
                        throw ProbeFailure("Preview menu lost focus or was dismissed before visual inspection completed")
                    }
                    guard ContinuousClock.now < deadline else { throw ProbeFailure("Desktop preview timed out") }
                    try await Task.sleep(for: .milliseconds(100))
                }
            }
            try await move(to: Vector(x: right, y: y))
            try await move(to: Vector(x: left, y: y))
            checks.append("Right-stick values move the real panel fully onto each display and back; neutral stops it")
            let beforeBack = try current(), oldScope = try probe.scope()
            store.send(.back(oldScope))
            try await probe.wait("Back after crossing") { store.model.phase.isActive && store.view.scope != oldScope }
            let afterBack = try current()
            guard store.model.phase.session?.menu.id == "window-layouts",
                  abs((beforeBack.x + beforeBack.width / 2) - (afterBack.x + afterBack.width / 2)) <= 1 else {
                throw ProbeFailure("Back after crossing changed the desktop anchor or menu path")
            }
            checks.append("Back preserves the menu's desktop center after crossing")
            store.send(.select(try probe.scope(), "focus-writing", .keyboard))
            store.send(.confirm(try probe.scope()))
            try await probe.wait("desktop probe choice") { store.model.phase == .idle }
            guard store.outputs.count == 1, case .completed(_, .selected(let choice)) = store.outputs[0],
                  choice.itemID == "focus-writing" else { throw ProbeFailure("Choice after crossing was not emitted once") }
            checks.append("Confirmation after crossing emits exactly one choice")
        } catch { failure = String(describing: error) }
        store.send(.stop)
        do { try await probe.wait("desktop probe cleanup") { store.model.lifecycle == .stopped(.completed) } }
        catch { failure = failure ?? String(describing: error) }
        if panel.hasNativeResources { failure = failure ?? "Desktop probe leaked native resources" }
        let report: [String: Any] = ["passed": failure == nil, "error": failure as Any? ?? NSNull(),
            "checks": checks, "samples": samples, "separateSpaces": NSScreen.screensHaveSeparateSpaces,
            "limits": ["Scripted controller values and times; real native panel positions. Content bitmap does not prove compositor visibility."]]
        do { try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("report.json")) }
        catch { return false }
        return failure == nil
    }
}
