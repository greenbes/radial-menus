import AppKit
import SwiftUI
import RadialCore
import RadialRuntime
import RadialMac

@MainActor private final class ChoiceProbeController: ControllerDriver {
    var receive: EventReceiver?
    func start() {}
    func stop() {}
    func baseline(scope: InputScope) {}
    func endInput(scope: InputScope) {}
    func resetInput(connection: ConnectionID) {}
}

@MainActor enum NativeChoiceProbe {
    static func run(directory: URL) async -> Bool {
        let panel = PanelAdapter(measurer: SwiftUIMenuMeasurer()), clock = TaskScheduler()
        let store = Store(menu: ChoiceDemo.definition, menuStyle: .iconLabelsCards, window: panel,
                          controller: ChoiceProbeController(), scheduler: clock, movementClock: clock)
        panel.content = NSHostingView(rootView: MenuContainer(store: store))
        let probe = NativeSmoke(store: store, panel: panel)
        var checks: [String] = []
        do {
            try await NativeStylePickerProbe.run(store: store, probe: probe, directory: directory)
            checks.append("All eight styles selectable in native dropdown")
            store.send(.open(nil))
            try await probe.wait("choice menu presentation") { store.model.phase.isActive }
            let scope = try probe.scope()
            let original = try require(store.view.layout, "Missing layout")
            let list = try require(original.choicePanel, "Missing list layout")
            for item in store.view.items {
                store.send(.select(scope, item.id, .keyboard))
                try await Task.sleep(for: .milliseconds(50))
                guard store.view.layout == original else { throw ProbeFailure("Selection changed layout") }
                try verifyGeometry(store: store, panel: panel)
            }
            checks.append("Six native labels and every card/list state fit stable measured bounds")
            store.send(.select(scope, "tmux", .keyboard))
            try await Task.sleep(for: .milliseconds(70))
            try panel.saveRendering(to: directory.appendingPathComponent("tmux-menu.png"))
            probe.key(code: 36, characters: "\r")
            try await probe.wait("enter list") { store.view.browsingChoices }
            probe.key(code: 125, characters: "\u{F701}")
            try await probe.wait("native list down arrow") { store.view.selectedChoice?.id == "session-1" }
            checks.append("Return enters list and Down moves a row without changing category")
            // The real pointer traverses the unused space between label and list.
            try await probe.mouse(at: probe.screenPoint(x: list.bounds.x - 8, y: original.ringCenter.y))
            try await probe.mouse(at: probe.screenPoint(x: list.bounds.x + 20, y: original.ringCenter.y))
            guard store.view.selectedID == "tmux" else { throw ProbeFailure("Pointer crossing cleared the category") }
            try NativeAccessibility.press(NativeAccessibility.button("research", in: panel.content))
            try await probe.wait("native row selection") { store.view.selectedChoice?.id == "session-2" }
            checks.append("Pointer can cross to list; native row button selects research")
            for index in 3...15 {
                probe.key(code: 125, characters: "\u{F701}")
                try await probe.wait("list row \(index)") { store.view.selectedChoice?.id == "session-\(index)" }
            }
            try await Task.sleep(for: .milliseconds(150))
            let last = try NativeAccessibility.button("weekend-project", in: panel.content)
            let lastFrame = try require(last.frame, "Missing final row frame")
            let listFrame = try nativeFrame(list.bounds, panel: panel)
            guard lastFrame.minY >= listFrame.minY + list.footerHeight - 1,
                  lastFrame.maxY <= listFrame.maxY - list.headerHeight + 1 else {
                throw ProbeFailure("Selected last row did not scroll into view: \(lastFrame), list \(listFrame)")
            }
            try verifyGeometry(store: store, panel: panel)
            try panel.saveRendering(to: directory.appendingPathComponent("last-session.png"))
            checks.append("Keyboard reaches all 16 rows; final row scrolls inside the native viewport")
            if let scrollView = panel.content.flatMap(findScrollView) {
                let before = scrollView.contentView.bounds.origin
                let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: 240, wheel2: 0, wheel3: 0)
                guard let event, let native = NSEvent(cgEvent: event) else { throw ProbeFailure("Cannot create local wheel event") }
                scrollView.scrollWheel(with: native)
                try await probe.wait("native wheel scrolling") { scrollView.contentView.bounds.origin != before }
                checks.append("Native scroll view handles a vertical wheel event")
            } else { throw ProbeFailure("No native scrolling view") }
            try NativeAccessibility.press(NativeAccessibility.button("Back to menu", in: panel.content))
            try await probe.wait("Back from list") { !store.view.browsingChoices && store.model.phase.isActive }
            probe.key(code: 36, characters: "\r")
            try await probe.wait("reenter list") { store.view.browsingChoices }
            try NativeAccessibility.press(NativeAccessibility.button("Choose", in: panel.content))
            try await probe.wait("choice dismissal") { store.model.phase == .idle }
            guard store.outputs == [.completed(scope.session, .selected(Choice(menuPath: ["choice-demo"], itemID: "tmux", value: "weekend-project")))] else {
                throw ProbeFailure("Wrong chosen row: \(store.outputs)")
            }
            checks.append("Back returns to menu; Choose returns the selected row after dismissal")
            store.send(.open(nil))
            try await probe.wait("reopen for category scrolling") { store.model.phase.isActive }
            let categoryScope = try probe.scope()
            store.send(.select(categoryScope, "commands", .keyboard))
            try await Task.sleep(for: .milliseconds(70))
            let commandsScroll = try require(panel.content.flatMap(findScrollView), "Missing commands scroll view")
            let previousOrigin = commandsScroll.contentView.bounds.origin
            let wheel = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: -1000, wheel2: 0, wheel3: 0)
            guard let wheel, let nativeWheel = NSEvent(cgEvent: wheel) else { throw ProbeFailure("Cannot create category wheel event") }
            commandsScroll.scrollWheel(with: nativeWheel)
            try await probe.wait("scroll commands without selecting another row") {
                commandsScroll.contentView.bounds.origin != previousOrigin
            }
            guard store.view.selectedChoice?.id == "row-0" else { throw ProbeFailure("Wheel changed row selection") }
            store.send(.select(categoryScope, "tabs", .keyboard))
            try await Task.sleep(for: .milliseconds(150))
            let firstTab = try NativeAccessibility.button("Architecture notes", in: panel.content)
            let firstTabFrame = try require(firstTab.frame, "Missing first tab frame")
            let switchedList = try nativeFrame(list.bounds, panel: panel)
            guard firstTabFrame.minY >= switchedList.minY + list.footerHeight - 1,
                  firstTabFrame.maxY <= switchedList.maxY - list.headerHeight + 1 else {
                throw ProbeFailure("Switching category with the same row ID left the selected row offscreen")
            }
            checks.append("Switching categories resets scrolling even when their selected row IDs match")
            probe.key(code: 53, characters: "\u{1b}")
            try await probe.wait("cancel category scroll check") { store.model.phase == .idle }
            // Choice content is independent of style. Exercise the same data in every renderer.
            for style in RadialCore.MenuStyle.allCases where style != .iconLabelsCards {
                store.send(.setMenuStyle(style)); store.send(.open(nil))
                try await probe.wait("list content in \(style)") { store.model.phase.isActive }
                let otherScope = try probe.scope()
                store.send(.activate(otherScope, "tmux", .keyboard))
                try await Task.sleep(for: .milliseconds(40))
                guard store.view.choices?.items.count == 16, store.view.layout?.choicePanel != nil else {
                    throw ProbeFailure("Style change lost list content")
                }
                probe.key(code: 53, characters: "\u{1b}")
                try await probe.wait("cancel alternate style") { store.model.phase == .idle }
            }
            checks.append("The same choice content remains usable in all existing styles; Escape cancels")
            store.send(.stop)
            try await probe.wait("choice probe cleanup") { store.model.lifecycle == .stopped(.completed) }
            guard !panel.isVisible, !panel.hasNativeResources else { throw ProbeFailure("Native resources remain") }
            try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks,
                "limits": "App-local input and native rendering; physical controller and VoiceOver are separate checks."], options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("report.json"))
            return true
        } catch {
            try? Data(String(describing: error).utf8).write(to: directory.appendingPathComponent("error.txt"))
            try? panel.saveRendering(to: directory.appendingPathComponent("failure.png"))
            store.send(.stop)
            return false
        }
    }

    private static func require<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw ProbeFailure(message) }; return value
    }

    private static func nativeFrame(_ bounds: RadialCore.Rect, panel: PanelAdapter) throws -> NSRect {
        let frame = try require(panel.frame, "Missing panel frame")
        return NSRect(x: frame.midX + bounds.x, y: frame.midY - bounds.y - bounds.height, width: bounds.width, height: bounds.height)
    }

    private static func verifyGeometry(store: Store, panel: PanelAdapter) throws {
        let layout = try require(store.view.layout, "Missing layout"), content = try require(panel.content, "Missing content")
        let list = try require(layout.choicePanel, "Missing list")
        guard abs(list.bounds.y + list.bounds.height / 2 - layout.ringCenter.y) < 1e-6,
              list.bounds.x > layout.labels.map({ $0.bounds.x + $0.bounds.width }).max()!,
              layout.centerBounds.y > layout.labels.map({ $0.bounds.y + $0.bounds.height }).max()! else {
            throw ProbeFailure("List/card positions do not match requested layout")
        }
        content.layoutSubtreeIfNeeded()
        let nodes = NativeAccessibility.elements(in: content)
        var targets = layout.labels.map { ($0.itemID, $0.bounds) }
        targets += [("selected-message-card", layout.centerBounds), ("menu-choice-list", list.bounds)]
        for (id, bounds) in targets {
            let title = store.view.items.first { $0.id == id }?.title
            let element = try require(nodes.first { title == nil ? $0.identifier == id : $0.role == .button && $0.label == title }, "Missing native element \(id)")
            let actual = try require(element.frame, "Missing frame \(id)"), expected = try nativeFrame(bounds, panel: panel)
            guard abs(actual.minX - expected.minX) < 1, abs(actual.minY - expected.minY) < 1,
                  abs(actual.width - expected.width) < 1, abs(actual.height - expected.height) < 1 else {
                throw ProbeFailure("Native \(id) frame differs: \(actual), expected \(expected)")
            }
        }
    }

    private static func findScrollView(_ view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.compactMap(findScrollView).first
    }
}
