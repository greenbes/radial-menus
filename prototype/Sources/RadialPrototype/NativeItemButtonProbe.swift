import AppKit
import RadialCore
import RadialRuntime
import RadialMac

@MainActor enum NativeItemButtonProbe {
    /// These buttons have no explicit accessibility name override, so SwiftUI
    /// derives their name from the rendered title and (for cards) description.
    static func check(store: Store, panel: PanelAdapter, navigationFrame: NSRect?) throws -> NSRect {
        guard let content = panel.content, let layout = store.view.layout, let panelFrame = panel.frame else {
            throw ProbeFailure("Missing full-label content")
        }
        content.layoutSubtreeIfNeeded()
        func expectedText(_ item: Item) -> String {
            if layout.style == .cards && !item.detail.isEmpty { return item.title + ", " + item.detail }
            return item.title
        }
        let titles = Set(store.view.items.map(expectedText))
        let buttons = NativeAccessibility.elements(in: content).filter {
            $0.role == .button && $0.label.map(titles.contains) == true
        }
        guard buttons.count == store.view.items.count else {
            throw ProbeFailure("Missing native item text. Expected: \(titles); observed: \(NativeAccessibility.elements(in: content).compactMap(\.label))")
        }
        for (item, label) in zip(store.view.items, layout.labels) {
            let r = label.bounds
            let expected = NSRect(x: panelFrame.midX + r.x, y: panelFrame.midY - r.y - r.height,
                                  width: r.width, height: r.height)
            // Repeated titles are valid. Match name and position, rather than
            // assuming the accessible name is a unique item identifier.
            guard buttons.contains(where: { button in
                guard button.label == expectedText(item), let frame = button.frame else { return false }
                return abs(frame.minX - expected.minX) < 1 && abs(frame.minY - expected.minY) < 1 &&
                       abs(frame.width - expected.width) < 1 && abs(frame.height - expected.height) < 1
            }) else {
                throw ProbeFailure("Native full-title frame differs from pointer target: \(item.title); \(expected)")
            }
        }
        let control = try NativeAccessibility.button(store.view.canGoBack ? "Back to parent menu" : "Cancel menu", in: content)
        guard let frame = control.frame else { throw ProbeFailure("Missing full-label navigation control") }
        if let navigationFrame, navigationFrame != frame { throw ProbeFailure("Selection moved the central control") }
        return frame
    }
}
