import AppKit
import RadialCore
import RadialRuntime
import RadialMac

@MainActor enum NativeItemButtonProbe {
    /// Check native item bounds against the core's pointer targets. Full-title
    /// styles derive names from their text; Selected message names short labels
    /// with the complete item title for accessibility.
    static func check(store: Store, panel: PanelAdapter, navigationFrame: NSRect?) throws -> NSRect? {
        guard let content = panel.content, let layout = store.view.layout, let panelFrame = panel.frame else {
            throw ProbeFailure("Missing full-label content")
        }
        content.layoutSubtreeIfNeeded()
        func expectedText(_ item: Item) -> String {
            if layout.style == .cards && !item.detail.isEmpty { return item.title + ", " + item.detail }
            if layout.style.usesFloatingLabels { return TitleLines.wrap(item.title).joined(separator: "\n") }
            return item.title
        }
        let titles = Set(store.view.items.map(expectedText))
        let buttons = NativeAccessibility.elements(in: content).filter {
            $0.role == .button && $0.label.map(titles.contains) == true
        }
        guard buttons.count == store.view.items.count else {
            throw ProbeFailure("Missing native item text. Expected: \(titles); observed: \(NativeAccessibility.elements(in: content).compactMap(\.label))")
        }
        if layout.style.usesFloatingLabels {
            for button in buttons {
                for line in (button.label ?? "").components(separatedBy: "\n") {
                    var count = 0
                    line.enumerateSubstrings(in: line.startIndex..<line.endIndex, options: .byComposedCharacterSequences) { _, _, _, _ in count += 1 }
                    guard count <= 20 || line.split(whereSeparator: \.isWhitespace).count == 1 else {
                        throw ProbeFailure("Rendered line exceeds 20 characters: \(line)")
                    }
                }
            }
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
                throw ProbeFailure("Native full-title frame differs from pointer target: \(item.title); expected \(expected); observed \(buttons.map { "\($0.label ?? "?"): \(String(describing: $0.frame))" })")
            }
        }
        if layout.style.hasEmptyCenter || (layout.style == .selectedMessage && !store.view.canGoBack) {
            let controls = NativeAccessibility.elements(in: content).filter {
                $0.role == .button && ["Back to parent menu", "Cancel menu"].contains($0.label ?? "")
            }
            guard controls.isEmpty else { throw ProbeFailure("Unexpected central navigation button") }
            return nil
        }
        let control = try NativeAccessibility.button(store.view.canGoBack ? "Back to parent menu" : "Cancel menu", in: content)
        guard let frame = control.frame else { throw ProbeFailure("Missing full-label navigation control") }
        if layout.style == .selectedMessage {
            guard let r = layout.messageBackBounds,
                  abs(frame.minX - panelFrame.midX - r.x) < 1,
                  abs(frame.minY - (panelFrame.midY - r.y - r.height)) < 1,
                  abs(frame.width - r.width) < 1, abs(frame.height - r.height) < 1 else {
                throw ProbeFailure("Native Back button differs from its bounds below the message: expected local \(String(describing: layout.messageBackBounds)), actual \(frame), panel \(panelFrame)")
            }
        }
        if let navigationFrame, navigationFrame != frame { throw ProbeFailure("Selection moved the central control") }
        return frame
    }
}
