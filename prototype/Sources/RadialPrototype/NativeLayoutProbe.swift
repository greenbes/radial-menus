import AppKit
import SwiftUI
import RadialCore
import RadialRuntime
import RadialMac
import RadialUI

@MainActor private final class LayoutProbeController: ControllerDriver {
    var receive: EventReceiver?
    func start() {}
    func stop() {}
    func baseline(scope: InputScope) {}
    func endInput(scope: InputScope) {}
    func resetInput(connection: ConnectionID) {}
}

@MainActor enum NativeLayoutProbe {
    static func run(directory: URL) async -> Bool {
        var reports: [[String: Any]] = []
        do {
            for fixture in try LayoutFixture.all() {
                let panel = PanelAdapter(measurer: SwiftUIMenuMeasurer(fontSize: fixture.fontSize)), clock = TaskScheduler()
                let store = Store(menu: fixture.menu, window: panel, controller: LayoutProbeController(),
                                  scheduler: clock, movementClock: clock)
                panel.content = NSHostingView(rootView: MenuContainer(store: store))
                let probe = NativeSmoke(store: store, panel: panel)
                store.send(.open(nil))
                try await probe.wait("layout fixture \(fixture.name)") { store.model.phase.isActive }
                reports.append(try await capture(fixture.name, store: store, panel: panel, directory: directory))
                if fixture.name == "nested" {
                    probe.key(code: 36, characters: "\r")
                    try await probe.wait("nested layout") { store.model.phase.isActive && store.view.title == "Nested fixture" && store.view.canGoBack }
                    reports.append(try await capture("nested-child", store: store, panel: panel, directory: directory))
                }
                let scope = try probe.scope(), item = store.view.items[0]
                let path = store.model.phase.session!.path.map(\.id)
                probe.key(code: 36, characters: "\r")
                try await probe.wait("layout fixture confirmation") { store.model.phase == .idle }
                guard case .value(let value) = item.destination,
                      store.outputs == [.completed(scope.session, .selected(Choice(menuPath: path, itemID: item.id, value: value)))] else {
                    throw ProbeFailure("Keyboard confirmation returned the wrong fixture item")
                }
                store.send(.stop)
                try await probe.wait("layout fixture cleanup") { store.model.lifecycle == .stopped(.completed) }
            }
            let extra = try await additionalChecks(directory: directory)
            let report: [String: Any] = [
                "additionalChecks": extra,
                "fixtures": reports, "os": ProcessInfo.processInfo.operatingSystemVersionString,
                "appearance": NSApp.effectiveAppearance.name.rawValue,
                "measurement": "Native SwiftUI measurements checked against the core layout used by the live view",
                "keyboardConfirmationPassed": true
            ]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("report.json"), options: .atomic)
            return true
        } catch {
            try? Data(String(describing: error).utf8).write(to: directory.appendingPathComponent("error.txt"))
            return false
        }
    }

    private static func additionalChecks(directory: URL) async throws -> [String: Any] {
        guard let fixture = try LayoutFixture.all().first(where: { $0.name == "12-wide" }) else {
            throw ProbeFailure("Missing expanded fixture")
        }
        let panel = PanelAdapter(measurer: SwiftUIMenuMeasurer(fontSize: fixture.fontSize)), clock = TaskScheduler()
        let store = Store(menu: fixture.menu, window: panel, controller: LayoutProbeController(),
                          scheduler: clock, movementClock: clock)
        panel.content = NSHostingView(rootView: MenuContainer(store: store))
        let probe = NativeSmoke(store: store, panel: panel)
        store.send(.open(nil))
        try await probe.wait("expanded pointer fixture") { store.model.phase.isActive }
        guard let layout = store.view.layout, layout.labelRadius > 150 else { throw ProbeFailure("Fixture did not expand") }
        let scope = try probe.scope()
        // Start away from the target so the accepted movement cannot be a baseline.
        try await probe.mouse(at: probe.screenPoint(x: 0, y: layout.labelRadius))
        try await probe.mouse(at: probe.screenPoint(x: 0, y: -layout.labelRadius))
        guard store.view.selectedID == "item-0", store.model.phase.session?.selection?.source == .pointer else {
            throw ProbeFailure("Expanded ring did not select under native pointer")
        }
        try await probe.click(x: 0, y: -layout.labelRadius)
        try await probe.wait("expanded native click") { store.model.phase == .idle }
        guard store.outputs == [.completed(scope.session, .selected(Choice(menuPath: ["root"], itemID: "item-0", value: "value-0")))] else {
            throw ProbeFailure("Expanded native click returned the wrong result")
        }
        store.send(.stop)
        try await probe.wait("expanded pointer cleanup") { store.model.lifecycle == .stopped(.completed) }

        let smallPanel = PanelAdapter(measurer: SwiftUIMenuMeasurer()), smallClock = TaskScheduler()
        let smallStore = Store(menu: fixture.menu, window: smallPanel, controller: LayoutProbeController(),
                               scheduler: smallClock, movementClock: smallClock)
        smallPanel.content = NSHostingView(rootView: MenuContainer(store: smallStore))
        // Controlled observation injection: no physical monitor is reconfigured.
        smallPanel.receive = { [weak smallStore] event in
            if case .prepared(let scope, let operation, let measurements, _) = event {
                smallStore?.send(.prepared(scope, operation, measurements, ScreenContext(revision: 1, screenID: "small-fixture",
                    bounds: Rect(x: 0, y: 0, width: 100, height: 100), anchor: .zero)))
            } else { smallStore?.send(event) }
        }
        var requestedPresentation = false
        smallStore.onTransition = { _, transition in
            if transition.effects.contains(where: { if case .present = $0 { true } else { false } }) { requestedPresentation = true }
        }
        smallStore.send(.open(nil))
        guard !requestedPresentation, !smallPanel.isVisible, smallStore.model.phase == .idle,
              smallStore.outputs.count == 1,
              case .completed(_, .failed(let failure)) = smallStore.outputs.first,
              failure.message == LayoutFailure.doesNotFit.message, failure.cleanupConfirmed, failure.committedChoice == nil else {
            throw ProbeFailure("Unfittable menu did not fail before presentation and clean up")
        }
        smallStore.send(.stop)
        guard smallStore.model.lifecycle == .stopped(.completed), !smallPanel.hasNativeResources else {
            throw ProbeFailure("Unfittable menu retained resources")
        }
        return ["expandedPointerAndClick": true, "expandedLabelRadius": layout.labelRadius,
                "smallScreenFailure": true, "smallScreenObservationInjected": true]
    }

    private static func capture(_ name: String, store: Store, panel: PanelAdapter, directory: URL) async throws -> [String: Any] {
        let items = store.view.items
        guard let layout = store.view.layout else { throw ProbeFailure("Missing measured layout") }
        var labels: [[String: Any]] = []
        for (index, item) in items.enumerated() {
            let measurements = [false, true].map { selected in
                let host = NSHostingController(rootView: MenuItemLabel(item: item, selected: selected, fontSize: layout.fontSize)
                    .fixedSize(horizontal: false, vertical: true))
                return host.sizeThatFits(in: NSSize(width: layout.wrappingWidth, height: 10000))
            }
            let width = measurements.map(\.width).max()!, height = measurements.map(\.height).max()!
            let rectangle = layout.labels[index].bounds
            labels.append(["id": item.id, "label": item.label, "measured": [width, height],
                           "rectangle": [rectangle.x, rectangle.y, rectangle.width, rectangle.height],
                           "normal": [measurements[0].width, measurements[0].height],
                           "selected": [measurements[1].width, measurements[1].height]])
        }
        if let scope = store.view.scope, let first = items.first { store.send(.select(scope, first.id, .keyboard)) }
        try await Task.sleep(for: .milliseconds(30))
        panel.content?.layoutSubtreeIfNeeded()
        try panel.saveRendering(to: directory.appendingPathComponent(name + ".png"))
        let probe = NativeSmoke(store: store, panel: panel)
        var steps = 0
        store.onTransition = { event, _ in if case .step = event { steps += 1 } }
        for index in 1...items.count {
            probe.key(code: 124, characters: "\u{F703}")
            try await probe.wait("fixture keyboard selection") { store.view.selectedID == items[index % items.count].id }
        }
        guard steps == items.count else { throw ProbeFailure("Keyboard did not traverse the complete fixture") }
        store.onTransition = nil
        guard let placement = panel.currentPlacement else { throw ProbeFailure("Missing native placement") }
        let center = NSHostingController(rootView: MenuCenterLabel(canGoBack: store.view.canGoBack,
            fontSize: layout.fontSize).fixedSize()).sizeThatFits(in: NSSize(width: 10000, height: 10000))
        return ["name": name, "count": items.count, "labels": labels,
                "geometry": ["innerRadius": layout.innerRadius, "outerRadius": layout.outerRadius,
                             "diameter": layout.diameter, "labelRadius": layout.labelRadius,
                             "labelWidth": layout.wrappingWidth, "fontSize": layout.fontSize,
                             "centerRadius": layout.centerRadius],
                "centerMeasured": [center.width, center.height],
                "keyboardSteps": steps,
                "backingScale": panel.content?.window?.backingScaleFactor ?? 0,
                "frame": [placement.frame.x, placement.frame.y, placement.frame.width, placement.frame.height],
                "screenBounds": [placement.bounds.x, placement.bounds.y, placement.bounds.width, placement.bounds.height]]
    }
}
