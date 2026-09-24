import AppKit
import SwiftUI
import RadialCore
import RadialRuntime
import RadialMac
import RadialUI

@MainActor private final class ContextProbeController: ControllerDriver {
    var receive: EventReceiver?
    func start() {}
    func stop() {}
    func baseline(scope: InputScope) {}
    func endInput(scope: InputScope) {}
    func resetInput(connection: ConnectionID) {}
}

@MainActor private struct ContextProbeView: View {
    let store: Store
    let reduceMotion: Bool
    var body: some View { MenuView(model: store.view, reduceMotion: reduceMotion) { store.send($0) } }
}

/// Real hosting views, native events, accessibility frames, and rendered pixels.
/// Synthetic controller input is covered by the ordinary native smoke probe.
@MainActor enum NativeContextProbe {
    static func run(directory: URL) async -> Bool {
        var scenes: [[String: Any]] = []
        var checks: [String] = []
        do {
            for (appearance, reduceMotion) in [(NSAppearance.Name.aqua, false), (.darkAqua, false), (.aqua, true)] {
                let scenario = appearance.rawValue + (reduceMotion ? "-reduced-motion" : "")
                NSApp.appearance = NSAppearance(named: appearance)
                let panel = PanelAdapter(measurer: SwiftUIMenuMeasurer()), clock = TaskScheduler()
                let store = Store(menu: SubmenuDemo.definition, menuStyle: .recenteredFloatingLabels,
                                  window: panel, controller: ContextProbeController(), scheduler: clock, movementClock: clock)
                panel.content = NSHostingView(rootView: ContextProbeView(store: store, reduceMotion: reduceMotion))
                let probe = NativeSmoke(store: store, panel: panel)
                var began: Double?
                var durations: [Double] = []
                store.onTransition = { event, _ in
                    switch event {
                    case .prepared: began = ProcessInfo.processInfo.systemUptime
                    case .presented:
                        if let began { durations.append(ProcessInfo.processInfo.systemUptime - began) }
                    default: break
                    }
                }
                func awaitMenu(_ id: String) async throws {
                    try await probe.wait(id) { store.model.phase.isActive && store.model.phase.session?.menu.id == id }
                    try await Task.sleep(for: .milliseconds(40))
                }
                func press(_ id: String) async throws {
                    guard let item = store.view.items.first(where: { $0.id == id }) else { throw ProbeFailure("Missing item \(id)") }
                    try NativeAccessibility.press(NativeAccessibility.button(TitleLines.wrap(item.title).joined(separator: "\n"), in: panel.content))
                }
                func back(to id: String) async throws {
                    probe.key(code: 51, characters: "\u{7F}")
                    try await awaitMenu(id)
                }
                func capture(_ id: String) async throws {
                    scenes.append(try await inspect(id, appearance: scenario, store: store, panel: panel,
                                                    probe: probe, directory: directory))
                }
                store.send(.open(nil))
                try await awaitMenu("workspace")
                try await capture("root")
                try await press("commands")
                try await awaitMenu("saved-commands")
                try await capture("commands")
                try await press("windows")
                try await awaitMenu("window-layouts")
                try await capture("windows")
                try await press("research-layout")
                try await awaitMenu("research-layouts")
                try await capture("research")
                let scaling = try checkDepthScaling(scenes: scenes.filter { $0["appearance"] as? String == scenario })
                checks.append("\(scenario): \(scaling) recurring context labels shrink at every deeper level")
                let obsolete = try probe.scope()
                try await back(to: "window-layouts")
                try await back(to: "saved-commands")
                guard store.view.context.count == 4 else { throw ProbeFailure("Ancestor return did not replace the path") }
                guard let previous = scenes.first(where: { $0["appearance"] as? String == scenario && $0["name"] as? String == "commands" }) else {
                    throw ProbeFailure("Missing parent measurements before descent")
                }
                try checkRestoredSizes(scene: previous, panel: panel)
                checks.append("\(scenario): returning restores the earlier native label sizes")
                store.send(.activate(obsolete, "notes-beside", .pointer))
                guard store.model.phase.isActive, store.outputs.isEmpty else { throw ProbeFailure("Stale input escaped navigation") }
                checks.append("\(appearance.rawValue): native Back steps and obsolete input rejection")
                try await press("tab-groups")
                try await awaitMenu("tab-groups")
                try await capture("tabs")
                try await back(to: "saved-commands")
                try await back(to: "workspace")
                try await press("documents")
                try await awaitMenu("documents")
                try await capture("documents")
                checks.append("\(scenario): sibling branches require Back to their containing menu")
                try await press("project-notes")
                try await probe.wait("leaf confirmation") { store.model.phase == .idle }
                guard case .completed(_, .selected(let choice)) = store.outputs.last,
                      choice.menuPath == ["workspace", "documents"], choice.itemID == "project-notes" else { throw ProbeFailure("Wrong leaf result") }
                checks.append("\(scenario): active leaf activation chooses it once")
                store.send(.open(nil))
                try await awaitMenu("workspace")
                try await press("commands")
                try await awaitMenu("saved-commands")
                probe.key(code: 53, characters: "\u{1B}")
                try await probe.wait("Escape cancellation") { store.model.phase == .idle }
                guard store.outputs.count == 2, case .completed(_, .cancelled(.user)) = store.outputs.last else {
                    throw ProbeFailure("Escape did not cancel the complete interaction once")
                }
                if !reduceMotion {
                    guard !durations.isEmpty, durations.allSatisfy({ $0 >= 0.25 }) else {
                        throw ProbeFailure("Input enabled before the entrance animation completed: \(durations)")
                    }
                }
                checks.append("\(scenario): measured presentation durations \(durations)")
                try await NativeStylePickerProbe.run(store: store, probe: probe, directory: directory)
                checks.append("\(appearance.rawValue): every menu style is selectable through the native dropdown")
                store.send(.stop)
                try await probe.wait("context cleanup") { store.model.lifecycle == .stopped(.completed) }
                guard !panel.hasNativeResources else { throw ProbeFailure("Context test leaked window resources") }
            }
            try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks, "scenes": scenes,
                "os": ProcessInfo.processInfo.operatingSystemVersionString,
                "limits": ["Native scripted mouse, keyboard, accessibility actions; no physical gamepad or VoiceOver session"]],
                options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("report.json"))
            return true
        } catch {
            try? JSONSerialization.data(withJSONObject: ["passed": false, "checks": checks, "scenes": scenes,
                "error": String(describing: error)], options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("report.json"))
            try? Data(String(describing: error).utf8).write(to: directory.appendingPathComponent("error.txt"))
            return false
        }
    }

    private static func inspect(_ name: String, appearance: String, store: Store, panel: PanelAdapter,
                                probe: NativeSmoke, directory: URL) async throws -> [String: Any] {
        guard let layout = store.view.layout, let frame = panel.frame, let content = panel.content else { throw ProbeFailure("No context scene") }
        let original = store.model.phase.session!.scope
        var states: [[String: Any]] = []
        for id in [nil] + store.view.items.map({ Optional($0.id) }) {
            store.send(.select(original, id, .keyboard))
            try await Task.sleep(for: .milliseconds(30))
            content.layoutSubtreeIfNeeded()
            _ = try NativeItemButtonProbe.check(store: store, panel: panel, navigationFrame: nil)
            guard store.view.layout == layout, panel.frame == frame else { throw ProbeFailure("Selection changed geometry") }
            let pixels = try NativeFloatingLabelProbe.capture(store: store, panel: panel)
            guard pixels["centerAlpha"] as? Double == 0,
                  (pixels["gapAlpha"] as? [Double])?.allSatisfy({ $0 == 0 }) == true else { throw ProbeFailure("Center or layout circle is visible") }
            for label in pixels["labels"] as? [[String: Any]] ?? [] {
                guard let fill = label["fill"] as? [Double], fill[3] > 0.98 else { throw ProbeFailure("Transparent active item") }
                if label["id"] as? String == id {
                    guard let outline = label["outline"] as? [Double], outline.allSatisfy({ $0 > 0.98 }) else {
                        throw ProbeFailure("Selected item is missing its white outline")
                    }
                }
            }
            states.append(pixels)
        }
        var contextRecords: [[String: Any]] = []
        for entry in store.view.context {
            guard let label = layout.context.first(where: { $0.target == entry.target }) else { throw ProbeFailure("Unplaced context") }
            let history = try historyLabel(TitleLines.wrap(entry.title).joined(separator: "\n"), in: content)
            let r = label.bounds
            let expected = NSRect(x: frame.midX + r.x, y: frame.midY - r.y - r.height, width: r.width, height: r.height)
            guard let observed = history.frame, abs(expected.minX - observed.minX) < 1, abs(expected.minY - observed.minY) < 1,
                  abs(expected.width - observed.width) < 1, abs(expected.height - observed.height) < 1 else {
                throw ProbeFailure("Context text frame differs from measured geometry: \(entry.title), \(expected), \(String(describing: history.frame))")
            }
            let host = NSHostingController(rootView: MenuContextLabel(entry: entry, fontSize: entry.fontSize(relativeTo: layout.fontSize)))
            let measured = host.sizeThatFits(in: NSSize(width: 10000, height: 10000))
            guard measured.width <= r.width, measured.height <= r.height else { throw ProbeFailure("Context text exceeds its bounds") }
            contextRecords.append(["target": String(describing: entry.target), "text": history.text ?? "", "ancestor": entry.isAncestor,
                                   "distance": entry.distance, "scale": entry.scale, "fontSize": entry.fontSize(relativeTo: layout.fontSize),
                                   "bounds": [r.x, r.y, r.width, r.height], "measured": [measured.width, measured.height],
                                   "renderedSize": [Double(observed.width), Double(observed.height)]])
        }
        let boxes = layout.labels.map(\.bounds) + layout.context.map(\.bounds)
        for (index, box) in boxes.enumerated() {
            guard box.x >= -layout.size.width / 2, box.y >= -layout.size.height / 2,
                  box.x + box.width <= layout.size.width / 2, box.y + box.height <= layout.size.height / 2 else {
                throw ProbeFailure("Label extends outside the native window")
            }
            for other in boxes.dropFirst(index + 1) {
                guard box.x + box.width <= other.x || other.x + other.width <= box.x ||
                      box.y + box.height <= other.y || other.y + other.height <= box.y else { throw ProbeFailure("Overlapping labels") }
            }
        }
        // Every history record is inert under real pointer movement and clicks.
        for label in layout.context {
            let x = label.bounds.x + label.bounds.width / 2
            let y = label.bounds.y + label.bounds.height / 2
            try await probe.mouse(at: probe.screenPoint(x: x, y: y))
            try await probe.click(x: x, y: y)
            try await probe.mouse(at: probe.screenPoint(x: x + 1, y: y))
            guard store.model.phase.isActive, store.model.phase.session?.scope == original,
                  store.outputs.isEmpty else { throw ProbeFailure("History label accepted pointer activation") }
        }
        guard NativeAccessibility.elements(in: content).filter({ $0.role == .button }).count == store.view.items.count else {
            throw ProbeFailure("History labels expose extra accessibility buttons")
        }
        let arcs = try checkArcs(layout: layout, entries: store.view.context)
        try panel.saveRendering(to: directory.appendingPathComponent("\(appearance)-\(name).png"))
        return ["name": name, "appearance": appearance, "size": [layout.size.width, layout.size.height],
                "path": store.model.phase.session!.path.map(\.id), "context": contextRecords, "states": states,
                "arcs": arcs, "inertHistoryClicks": layout.context.count]
    }

    private static func historyLabel(_ title: String, in content: NSView?) throws -> NativeAccessibility.Element {
        let nodes = content.map { NativeAccessibility.elements(in: $0) } ?? []
        guard let element = nodes.first(where: { $0.role == .staticText && $0.text == title }) else {
            throw ProbeFailure("Missing static history label: \(title). Observed: \(nodes.map { [$0.role?.rawValue, $0.label, $0.text] })")
        }
        return element
    }

    private static func checkArcs(layout: MenuLayout, entries: [ContextEntry]) throws -> [[String: Any]] {
        var previousRadius = 0.0, previousLength = Double.infinity
        var previousOuter = layout.labels.map { label in
            let r = label.bounds
            return hypot(max(abs(r.x), abs(r.x + r.width)), max(abs(r.y), abs(r.y + r.height)))
        }.max()!
        var records: [[String: Any]] = []
        for arc in layout.contextArcs {
            guard arc.radius > previousRadius, arc.length < previousLength,
                  arc.labels.map(\.target) == entries.filter({ $0.distance == arc.distance }).map(\.target) else {
                throw ProbeFailure("History levels do not form separate, progressively shorter outer arcs")
            }
            for label in arc.labels {
                let r = label.bounds
                let x = r.x + r.width / 2, y = r.y + r.height / 2
                let qx = min(max(0, r.x), r.x + r.width), qy = min(max(0, r.y), r.y + r.height)
                guard abs(hypot(x, y) - arc.radius) < 0.01, x < 0, hypot(qx, qy) > previousOuter else {
                    throw ProbeFailure("History levels interleave or have different centers")
                }
            }
            previousOuter = arc.labels.map { label in
                let r = label.bounds
                return hypot(max(abs(r.x), abs(r.x + r.width)), max(abs(r.y), abs(r.y + r.height)))
            }.max()!
            records.append(["distance": arc.distance, "radius": arc.radius, "length": arc.length,
                            "startAngle": arc.startAngle, "endAngle": arc.endAngle, "count": arc.labels.count])
            previousRadius = arc.radius; previousLength = arc.length
        }
        return records
    }

    private static func checkDepthScaling(scenes: [[String: Any]]) throws -> Int {
        var checked = 0
        for (before, after) in [("commands", "windows"), ("windows", "research")] {
            guard let old = scenes.first(where: { $0["name"] as? String == before })?["context"] as? [[String: Any]],
                  let new = scenes.first(where: { $0["name"] as? String == after })?["context"] as? [[String: Any]],
                  !old.isEmpty else { throw ProbeFailure("Missing hierarchy size observations") }
            for earlier in old {
                guard let target = earlier["target"] as? String,
                      let later = new.first(where: { $0["target"] as? String == target }),
                      let a = earlier["renderedSize"] as? [Double], let b = later["renderedSize"] as? [Double],
                      a.count == 2, b.count == 2 else { throw ProbeFailure("Missing recurring context label measurements") }
                for dimension in 0...1 {
                    // Fonts and decoration scale by 20%; native line metrics
                    // and rounding make the measured rectangle non-proportional.
                    // Require a visible decrease of at least 10% in both axes,
                    // so a fixed minimum height or repeated font size fails.
                    guard b[dimension] > 0, b[dimension] <= a[dimension] * 0.9 else {
                        throw ProbeFailure("Context label failed to shrink visibly by level: \(target), \(a) → \(b)")
                    }
                }
                checked += 1
            }
        }
        return checked
    }

    private static func checkRestoredSizes(scene: [String: Any], panel: PanelAdapter) throws {
        guard let labels = scene["context"] as? [[String: Any]], !labels.isEmpty else { throw ProbeFailure("Missing ancestor sizes") }
        for label in labels {
            guard let title = label["text"] as? String, let size = label["renderedSize"] as? [Double], size.count == 2,
                  let frame = try historyLabel(title, in: panel.content).frame,
                  abs(frame.width - size[0]) < 1, abs(frame.height - size[1]) < 1 else {
                throw ProbeFailure("Returning to an ancestor did not restore its label sizes")
            }
        }
    }
}
