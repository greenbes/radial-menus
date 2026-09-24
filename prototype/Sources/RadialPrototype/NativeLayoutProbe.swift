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
    static func run(directory: URL, style: RadialCore.MenuStyle = .pie) async -> Bool {
        var reports: [[String: Any]] = []
        var preparation: [String: Any] = [:]
        do {
            try await checkNavigationControls(style: style, directory: directory)
            if style.hasEmptyCenter { try await checkAccessibleIconLabels(style: style) }
            if style == .cards { try await checkCardDescriptionClick() }
            for fixture in try LayoutFixture.all(style: style) {
                let panel = PanelAdapter(measurer: SwiftUIMenuMeasurer(fontSize: fixture.fontSize)), clock = TaskScheduler()
                let store = Store(menu: fixture.menu, menuStyle: style, window: panel, controller: LayoutProbeController(),
                                  scheduler: clock, movementClock: clock)
                panel.content = NSHostingView(rootView: MenuContainer(store: store))
                let probe = NativeSmoke(store: store, panel: panel)
                store.onTransition = { event, _ in
                    if case .prepared(_, _, let measurements, let screen) = event {
                        let layout = try? MenuLayout.make(menu: fixture.menu, measurements: measurements)
                        preparation = ["fixture": fixture.name, "measurements": String(describing: measurements),
                                       "layout": String(describing: layout), "screen": String(describing: screen)]
                    }
                }
                store.send(.open(nil))
                if !store.outputs.isEmpty { throw ProbeFailure("Opening failed: \(store.outputs)") }
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
            let extra = try await additionalChecks(directory: directory, style: style)
            let report: [String: Any] = [
                "additionalChecks": extra, "style": style.rawValue,
                "fixtures": reports, "os": ProcessInfo.processInfo.operatingSystemVersionString,
                "appearance": NSApp.effectiveAppearance.name.rawValue,
                "measurement": "Native SwiftUI measurements checked against the core layout used by the live view",
                "keyboardConfirmationPassed": true
            ]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("report.json"), options: .atomic)
            return true
        } catch {
            try? JSONSerialization.data(withJSONObject: preparation, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("failed-preparation.json"))
            try? Data(String(describing: error).utf8).write(to: directory.appendingPathComponent("error.txt"))
            return false
        }
    }

    private static func additionalChecks(directory: URL, style: RadialCore.MenuStyle) async throws -> [String: Any] {
        guard let fixture = try LayoutFixture.all().first(where: { $0.name == "12-wide" }) else {
            throw ProbeFailure("Missing expanded fixture")
        }
        let panel = PanelAdapter(measurer: SwiftUIMenuMeasurer(fontSize: fixture.fontSize)), clock = TaskScheduler()
        let store = Store(menu: fixture.menu, menuStyle: style, window: panel, controller: LayoutProbeController(),
                          scheduler: clock, movementClock: clock)
        panel.content = NSHostingView(rootView: MenuContainer(store: store))
        let probe = NativeSmoke(store: store, panel: panel)
        store.send(.open(nil))
        try await probe.wait("expanded pointer fixture") { store.model.phase.isActive }
        guard let layout = store.view.layout, layout.labelRadius > 150 else { throw ProbeFailure("Fixture did not expand") }
        let scope = try probe.scope()
        let first = layout.labels[0].bounds
        let target = Vector(x: first.x + first.width / 2, y: first.y + first.height / 2)
        // Start away from the target so the accepted movement cannot be a baseline.
        try await probe.mouse(at: probe.screenPoint(x: 0, y: layout.labelRadius))
        try await probe.mouse(at: probe.screenPoint(x: target.x, y: target.y))
        guard store.view.selectedID == "item-0", store.model.phase.session?.selection?.source == .pointer else {
            throw ProbeFailure("Expanded ring did not select under native pointer")
        }
        if style == .selectedMessage {
            try await probe.mouse(at: probe.screenPoint(x: 0, y: 0))
            guard store.view.selectedID == nil else { throw ProbeFailure("Pointer on message did not clear pointer selection") }
            store.send(.select(scope, "item-0", .keyboard))
            let beforeClick = store.model.phase
            try await probe.click(x: 0, y: -layout.centerBounds.height / 2 + layout.fontSize * 2)
            // A following mouse event acts as an ordered barrier for the click events.
            try await probe.mouse(at: probe.screenPoint(x: 1, y: 0))
            guard store.model.phase == beforeClick, store.outputs.isEmpty else {
                throw ProbeFailure("Clicking message text activated or cancelled the menu")
            }
        }
        if let guide = layout.directionGuide {
            let marker = guide.connections[0].marker
            store.send(.select(scope, "item-0", .keyboard))
            try await probe.click(x: marker.x, y: marker.y)
            try await probe.mouse(at: probe.screenPoint(x: marker.x + 1, y: marker.y))
            guard store.model.phase.isActive, store.outputs.isEmpty, store.view.selectedID == "item-0" else {
                throw ProbeFailure("The decorative direction marker activated or cancelled an item")
            }
        }
        if let ring = layout.iconRing {
            for point in [Vector.zero, ring.icons[0].center] {
                store.send(.select(scope, "item-0", .keyboard))
                try await probe.click(x: point.x, y: point.y)
                try await probe.mouse(at: probe.screenPoint(x: point.x + 1, y: point.y))
                guard store.model.phase.isActive, store.outputs.isEmpty, store.view.selectedID == "item-0" else {
                    throw ProbeFailure("An icon or empty center acted as a button")
                }
            }
        }
        if style == .floatingLabels {
            for point in [Vector.zero, Vector(x: first.x + 0.25, y: first.y + 0.25)] {
                store.send(.select(scope, "item-0", .keyboard))
                try await probe.click(x: point.x, y: point.y)
                try await probe.mouse(at: probe.screenPoint(x: point.x + 1, y: point.y))
                guard store.model.phase.isActive, store.outputs.isEmpty else {
                    throw ProbeFailure("Empty center or rounded corner activated an item")
                }
            }
        }
        // In Floating labels this point is inside the embedded icon.
        let clickX = style == .floatingLabels ? first.x + layout.fontSize * 1.5 : target.x
        try await probe.click(x: clickX, y: target.y)
        try await probe.wait("expanded native click") { store.model.phase == .idle }
        guard store.outputs == [.completed(scope.session, .selected(Choice(menuPath: ["root"], itemID: "item-0", value: "value-0")))] else {
            throw ProbeFailure("Expanded native click returned the wrong result")
        }
        store.send(.stop)
        try await probe.wait("expanded pointer cleanup") { store.model.lifecycle == .stopped(.completed) }

        try checkUnfittable(menu: fixture.menu, style: style, bounds: Rect(x: 0, y: 0, width: 100, height: 100))
        if style == .floatingLabels {
            let word = String(repeating: "界", count: 160)
            let oversized = try RadialCore.Menu(id: "root", title: "Long word", items: [
                Item(id: "word", label: "Word", title: word, value: "word")])
            guard TitleLines.wrap(word) == [word] else { throw ProbeFailure("Long word was split") }
            try checkUnfittable(menu: oversized, style: style, bounds: Rect(x: 0, y: 0, width: 1200, height: 1000))
        }
        return ["nativeBackAndCancel": true, "styleSwitching": true, "nativeStylePicker": true, "expandedPointerAndClick": true, "expandedLabelRadius": layout.labelRadius,
                "smallScreenFailure": true, "smallScreenObservationInjected": true,
                "messageTextIsNotAButton": style == .selectedMessage,
                "nativeCardDescriptionClick": style == .cards,
                "directionGuideIsNotAButton": style.usesDirectionGuide,
                "iconsAndCenterAreNotButtons": style == .iconLabels,
                "nativeIconAccessibilityActions": style.hasEmptyCenter,
                "nativeFloatingHitRegions": style == .floatingLabels, "oversizedWordFailure": style == .floatingLabels]
    }

    private static func checkUnfittable(menu: RadialCore.Menu, style: RadialCore.MenuStyle, bounds: Rect) throws {
        let smallPanel = PanelAdapter(measurer: SwiftUIMenuMeasurer()), smallClock = TaskScheduler()
        let smallStore = Store(menu: menu, menuStyle: style, window: smallPanel, controller: LayoutProbeController(),
                               scheduler: smallClock, movementClock: smallClock)
        smallPanel.content = NSHostingView(rootView: MenuContainer(store: smallStore))
        // Controlled observation injection: no physical monitor is reconfigured.
        smallPanel.receive = { [weak smallStore] event in
            if case .prepared(let scope, let operation, let measurements, _) = event {
                smallStore?.send(.prepared(scope, operation, measurements, ScreenContext(revision: 1, screenID: "small-fixture",
                    bounds: bounds, anchor: .zero)))
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
    }

    private static func checkAccessibleIconLabels(style: RadialCore.MenuStyle) async throws {
        let panel = PanelAdapter(measurer: SwiftUIMenuMeasurer()), clock = TaskScheduler()
        let store = Store(menu: SampleMenu.definition, menuStyle: style, window: panel,
                          controller: LayoutProbeController(), scheduler: clock, movementClock: clock)
        panel.content = NSHostingView(rootView: MenuContainer(store: store))
        let probe = NativeSmoke(store: store, panel: panel)
        store.send(.open(nil))
        try await probe.wait("accessible root") { store.model.phase.isActive }
        let scope = try probe.scope()
        try NativeAccessibility.press(NativeAccessibility.button("More colors", in: panel.content))
        try await probe.wait("accessible submenu") { store.model.phase.isActive && store.view.canGoBack }
        try NativeAccessibility.perform("Back to parent menu", on: NativeAccessibility.button("Amber", in: panel.content))
        try await probe.wait("accessible Back") { store.model.phase.isActive && !store.view.canGoBack }
        try NativeAccessibility.perform("Cancel menu", on: NativeAccessibility.button("Red", in: panel.content))
        try await probe.wait("accessible Cancel") { store.model.phase == .idle }
        guard store.outputs == [.completed(scope.session, .cancelled(.user))] else {
            throw ProbeFailure("Accessible Back/Cancel produced the wrong result")
        }
        store.send(.open(nil))
        try await probe.wait("accessible confirmation root") { store.model.phase.isActive }
        let second = try probe.scope()
        store.send(.select(second, "blue", .keyboard))
        try NativeAccessibility.press(NativeAccessibility.button("Red", in: panel.content))
        try await probe.wait("accessible confirmation") { store.model.phase == .idle }
        guard store.outputs.last == .completed(second.session, .selected(
            Choice(menuPath: ["root"], itemID: "red", value: "red"))) else {
            throw ProbeFailure("Accessible activation chose the wrong item")
        }
        store.send(.stop)
        try await probe.wait("accessible fixture cleanup") { store.model.lifecycle == .stopped(.completed) }
    }

    private static func checkCardDescriptionClick() async throws {
        let panel = PanelAdapter(measurer: SwiftUIMenuMeasurer()), clock = TaskScheduler()
        let store = Store(menu: DemoMenu.definition, menuStyle: .cards, window: panel, controller: LayoutProbeController(),
                          scheduler: clock, movementClock: clock)
        panel.content = NSHostingView(rootView: MenuContainer(store: store))
        let probe = NativeSmoke(store: store, panel: panel)
        store.send(.open(nil))
        try await probe.wait("card description click fixture") { store.model.phase.isActive }
        let scope = try probe.scope()
        try await probe.mouse(at: probe.screenPoint(x: 0, y: 0))
        store.send(.select(scope, "research", .keyboard))
        guard let bounds = store.view.layout?.labels.first(where: { $0.itemID == "documents" })?.bounds else {
            throw ProbeFailure("Missing description target")
        }
        // The lower part of this card contains the visible description.
        try await probe.click(x: bounds.x + bounds.width / 4, y: bounds.y + bounds.height * 0.75)
        try await probe.wait("description activation") { store.model.phase == .idle }
        guard store.outputs == [.completed(scope.session, .selected(
            Choice(menuPath: ["workspace"], itemID: "documents", value: "documents")))] else {
            throw ProbeFailure("Clicking a description did not activate its card")
        }
        store.send(.stop)
        try await probe.wait("description fixture cleanup") { store.model.lifecycle == .stopped(.completed) }
    }

    private static func checkNavigationControls(style: RadialCore.MenuStyle, directory: URL) async throws {
        let panel = PanelAdapter(measurer: SwiftUIMenuMeasurer()), clock = TaskScheduler()
        let store = Store(menu: SampleMenu.definition, menuStyle: style, window: panel, controller: LayoutProbeController(),
                          scheduler: clock, movementClock: clock)
        panel.content = NSHostingView(rootView: MenuContainer(store: store))
        let probe = NativeSmoke(store: store, panel: panel)
        try await NativeStylePickerProbe.run(store: store, probe: probe, directory: directory)
        store.send(.open(nil))
        try await probe.wait("navigation controls root") { store.model.phase.isActive }
        let scope = try probe.scope(), nextStyle: RadialCore.MenuStyle = style == .pie ? .selectedMessage : .pie
        store.send(.setMenuStyle(nextStyle))
        store.send(.activate(scope, "more", .keyboard))
        try await probe.wait("navigation controls child") { store.model.phase.isActive && store.view.canGoBack }
        guard store.view.layout?.style == style else { throw ProbeFailure("Style changed during navigation") }
        for label in ["Back to parent menu", "Cancel menu"] {
            try await Task.sleep(for: .milliseconds(30))
            if style.hasEmptyCenter {
                _ = try NativeItemButtonProbe.check(store: store, panel: panel, navigationFrame: nil)
                probe.key(code: label == "Back to parent menu" ? 51 : 53,
                          characters: label == "Back to parent menu" ? "\u{7F}" : "\u{1B}")
            } else {
                let button = try NativeAccessibility.button(label, in: panel.content)
                guard let frame = button.frame else { throw ProbeFailure("Missing native control frame") }
                guard let menuFrame = panel.frame, frame.width > 0, frame.height > 0 else { throw ProbeFailure("Missing navigation control frame") }
                try await probe.click(x: frame.midX - menuFrame.midX, y: menuFrame.midY - frame.midY)
            }
            if label == "Back to parent menu" {
                try await probe.wait("native Back button") { store.model.phase.isActive && !store.view.canGoBack }
                guard store.view.layout?.style == style else { throw ProbeFailure("Back changed style") }
            } else {
                try await probe.wait("native Cancel button") { store.model.phase == .idle }
            }
        }
        guard store.outputs == [.completed(scope.session, .cancelled(.user))] else { throw ProbeFailure("Navigation controls returned the wrong outcome") }
        store.send(.open(nil))
        try await probe.wait("changed style") { store.model.phase.isActive }
        guard store.view.layout?.style == nextStyle else { throw ProbeFailure("Style preference did not apply on reopening") }
        store.send(.stop)
        try await probe.wait("style probe cleanup") { store.model.lifecycle == .stopped(.completed) }
    }

    private static func capture(_ name: String, store: Store, panel: PanelAdapter, directory: URL) async throws -> [String: Any] {
        let items = store.view.items
        guard let layout = store.view.layout else { throw ProbeFailure("Missing measured layout") }
        try panel.saveRendering(to: directory.appendingPathComponent(name + "-neutral.png"))
        var labels: [[String: Any]] = []
        for (index, item) in items.enumerated() {
            let measurements = [false, true].map { selected in
                let host = NSHostingController(rootView: MenuItemLabel(item: item, selected: selected, fontSize: layout.fontSize, style: layout.style)
                    .fixedSize(horizontal: layout.style == .floatingLabels, vertical: true))
                return host.sizeThatFits(in: NSSize(width: layout.wrappingWidth, height: 10000))
            }
            let width = measurements.map(\.width).max()!, height = measurements.map(\.height).max()!
            let rectangle = layout.labels[index].bounds
            labels.append(["id": item.id, "label": item.label, "title": item.title, "detail": item.detail, "measured": [width, height],
                           "rectangle": [rectangle.x, rectangle.y, rectangle.width, rectangle.height],
                           "normal": [measurements[0].width, measurements[0].height],
                           "selected": [measurements[1].width, measurements[1].height],
                           "cornerRadius": layout.labels[index].cornerRadius,
                           "lines": TitleLines.wrap(item.title)])
        }
        var messages: [[String: Any]] = []
        var navigationFrame: NSRect?
        var iconStates: [[String: Any]] = []
        var floatingStates: [[String: Any]] = []
        if layout.style.showsFullTitles {
            try await Task.sleep(for: .milliseconds(30))
            navigationFrame = try NativeItemButtonProbe.check(store: store, panel: panel, navigationFrame: nil)
        }
        if layout.style == .selectedMessage {
            for id in [nil] + items.map({ Optional($0.id) }) {
                guard let scope = store.view.scope else { throw ProbeFailure("Missing message scope") }
                store.send(.select(scope, id, .keyboard))
                try await Task.sleep(for: .milliseconds(30))
                panel.content?.layoutSubtreeIfNeeded()
                let button = try NativeAccessibility.button(store.view.canGoBack ? "Back to parent menu" : "Cancel menu", in: panel.content)
                guard let frame = button.frame else { throw ProbeFailure("Missing native control frame") }
                if let navigationFrame, frame != navigationFrame {
                    throw ProbeFailure("Selection moved the navigation button")
                }
                navigationFrame = frame
                let message = store.view.message
                let texts = (panel.content.map { NativeAccessibility.elements(in: $0) } ?? []).filter { $0.role == .staticText }
                    .compactMap(\.text)
                guard texts.contains(message.title), message.detail.isEmpty || texts.contains(message.detail) else {
                    throw ProbeFailure("Native message text differs from selection: \(texts)")
                }
                guard message.itemID == id else { throw ProbeFailure("Displayed message has the wrong identity") }
                let host = NSHostingController(rootView: MenuMessageCard(message: message,
                    canGoBack: store.view.canGoBack, fontSize: layout.fontSize))
                let size = host.sizeThatFits(in: NSSize(width: layout.centerBounds.width, height: 10000))
                messages.append(["id": id as Any? ?? NSNull(), "measured": [size.width, size.height],
                                 "title": message.title, "detail": message.detail])
                if name == "rich" || name == "large-type-rich" {
                    try await Task.sleep(for: .milliseconds(30))
                    panel.content?.layoutSubtreeIfNeeded()
                    try panel.saveRendering(to: directory.appendingPathComponent(name + "-" + (id ?? "neutral") + ".png"))
                }
            }
        }
        if layout.style == .floatingLabels {
            floatingStates.append(try NativeFloatingLabelProbe.capture(store: store, panel: panel))
        }
        if layout.style == .iconLabels {
            iconStates.append(try NativeIconRingProbe.capture(store: store, panel: panel))
        }
        if let scope = store.view.scope, let first = items.first { store.send(.select(scope, first.id, .keyboard)) }
        try await Task.sleep(for: .milliseconds(30))
        panel.content?.layoutSubtreeIfNeeded()
        try panel.saveRendering(to: directory.appendingPathComponent(name + ".png"))
        let probe = NativeSmoke(store: store, panel: panel)
        let originalFrame = panel.frame
        var steps = 0
        store.onTransition = { event, _ in if case .step = event { steps += 1 } }
        for index in 1...items.count {
            probe.key(code: 124, characters: "\u{F703}")
            let expected = items[index % items.count]
            try await probe.wait("fixture keyboard selection") { store.view.selectedID == expected.id }
            guard store.view.message.title == expected.title, store.view.message.detail == expected.detail,
                  store.view.layout == layout, panel.frame == originalFrame else {
                throw ProbeFailure("Selection changed layout or displayed the wrong message")
            }
            if layout.style.showsFullTitles {
                try await Task.sleep(for: .milliseconds(30))
                navigationFrame = try NativeItemButtonProbe.check(store: store, panel: panel, navigationFrame: navigationFrame)
                if layout.style == .floatingLabels {
                    floatingStates.append(try NativeFloatingLabelProbe.capture(store: store, panel: panel))
                }
                if layout.style == .iconLabels {
                    iconStates.append(try NativeIconRingProbe.capture(store: store, panel: panel))
                }
            }
        }
        guard steps == items.count else { throw ProbeFailure("Keyboard did not traverse the complete fixture") }
        store.onTransition = nil
        guard let placement = panel.currentPlacement else { throw ProbeFailure("Missing native placement") }
        let center = NSHostingController(rootView: MenuCenterLabel(canGoBack: store.view.canGoBack,
            fontSize: layout.fontSize).fixedSize()).sizeThatFits(in: NSSize(width: 10000, height: 10000))
        let guide: [String: Any] = layout.directionGuide.map { guide in
            ["radius": guide.radius, "markerRadius": guide.markerRadius,
             "connections": guide.connections.map {
                 ["id": $0.itemID, "marker": [$0.marker.x, $0.marker.y], "labelEdge": [$0.labelEdge.x, $0.labelEdge.y]] as [String: Any]
             }]
        } ?? [:]
        return ["name": name, "style": layout.style.rawValue, "directionGuide": guide,
                "iconStates": iconStates, "floatingStates": floatingStates,
                "messages": messages, "stableSelectionLayout": true,
                "nativeMessageTextVerified": layout.style == .selectedMessage,
                "stableNavigationControl": layout.style != .pie && !layout.style.hasEmptyCenter,
                "nativeFullTitleTextVerified": layout.style.showsFullTitles,
                "nativeCardTextVerified": layout.style == .cards,
                "nativeLabelFramesVerified": layout.style.showsFullTitles,
                "centerBounds": [layout.centerBounds.x, layout.centerBounds.y, layout.centerBounds.width, layout.centerBounds.height], "count": items.count, "labels": labels,
                "geometry": ["innerRadius": layout.innerRadius, "outerRadius": layout.outerRadius,
                             "diameter": layout.diameter, "windowSize": [layout.size.width, layout.size.height], "labelRadius": layout.labelRadius,
                             "labelWidth": layout.wrappingWidth, "fontSize": layout.fontSize,
                             "centerRadius": layout.centerRadius],
                "centerMeasured": layout.style.hasEmptyCenter ? [0, 0] : layout.style != .selectedMessage ? [center.width, center.height] : [layout.centerBounds.width, layout.centerBounds.height],
                "keyboardSteps": steps,
                "backingScale": panel.content?.window?.backingScaleFactor ?? 0,
                "frame": [placement.frame.x, placement.frame.y, placement.frame.width, placement.frame.height],
                "screenBounds": [placement.bounds.x, placement.bounds.y, placement.bounds.width, placement.bounds.height]]
    }
}
