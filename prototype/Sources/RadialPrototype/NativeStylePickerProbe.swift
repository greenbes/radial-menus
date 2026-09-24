import AppKit
import RadialCore
import RadialRuntime

@MainActor enum NativeStylePickerProbe {
    static func run(store: Store, probe: NativeSmoke, directory: URL) async throws {
        let original = store.model.menuStyle
        let window = makeDiagnosticsWindow(store: store, log: try EventLog(url: nil))
        defer { window.close() }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        try await probe.wait("diagnostics window") { window.isKeyWindow }
        for style in RadialCore.MenuStyle.allCases.filter({ $0 != original }) + [original] {
            try await Task.sleep(for: .milliseconds(30))
            guard let content = window.contentView else { throw ProbeFailure("Missing diagnostics content") }
            let nodes = NativeAccessibility.elements(in: content)
            guard let choice = nodes.first(where: { $0.role == .popUpButton }),
                  let frame = choice.frame, frame.width > 0, frame.height > 0 else {
                throw ProbeFailure("Missing native style dropdown; \(nodes.map { [$0.role?.rawValue, $0.label] })")
            }
            let point = window.convertPoint(fromScreen: NSPoint(x: frame.midX, y: frame.midY))
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                guard let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 0, clickCount: 1, pressure: 0) else { throw ProbeFailure("Cannot create style picker click") }
                NSApp.postEvent(event, atStart: false)
            }
            try await probe.wait("native style dropdown") {
                NativeAccessibility.elements(in: content).contains {
                    $0.role == .menuItem && $0.label == style.title && ($0.frame?.height ?? 0) > 0
                }
            }
            guard let item = NativeAccessibility.elements(in: content).first(where: {
                $0.role == .menuItem && $0.label == style.title
            }), let itemFrame = item.frame else { throw ProbeFailure("Missing open dropdown item") }
            let screenPoint = NSPoint(x: itemFrame.midX, y: itemFrame.midY)
            guard let menuWindow = NSApp.windows.filter({ $0.isVisible && $0.frame.contains(screenPoint) })
                .max(by: { $0.level.rawValue < $1.level.rawValue }) else {
                throw ProbeFailure("No native window contains dropdown item")
            }
            let itemPoint = menuWindow.convertPoint(fromScreen: screenPoint)
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                guard let event = NSEvent.mouseEvent(with: type, location: itemPoint, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: menuWindow.windowNumber,
                    context: nil, eventNumber: 0, clickCount: 1, pressure: 0) else { throw ProbeFailure("Cannot create dropdown item click") }
                NSApp.postEvent(event, atStart: false)
            }
            try await probe.wait("native style picker choice \(style.rawValue), currently \(store.model.menuStyle.rawValue)") { store.model.menuStyle == style }
            try await probe.wait("native dropdown dismissal") { !menuWindow.isVisible && window.isKeyWindow }
        }
        guard let content = window.contentView,
              let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) else {
            throw ProbeFailure("Cannot capture diagnostics")
        }
        content.cacheDisplay(in: content.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ProbeFailure("Cannot encode diagnostics") }
        try png.write(to: directory.appendingPathComponent("style-picker.png"))
    }
}
