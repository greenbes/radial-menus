import AppKit
import RadialCore
import RadialRuntime

@MainActor private final class MenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Rejects obsolete work before any window mutation occurs.
public struct OperationOrder: Sendable {
    public private(set) var current: OperationID?
    public init() {}
    public mutating func accept(_ operation: OperationID) -> Bool {
        guard current.map({ operation > $0 }) ?? true else { return false }
        current = operation
        return true
    }
}

@MainActor public final class PanelAdapter: NSObject, WindowDriver, NSWindowDelegate {
    public var receive: EventReceiver?
    public var content: NSView?
    public var onNativeObservation: ((String) -> Void)?
    private var panel: MenuPanel?
    private var order = OperationOrder()
    private var request: (scope: InputScope, operation: OperationID)?
    private var readyScope: InputScope?
    private var acknowledged: OperationID?
    private var previousApplication: NSRunningApplication?
    private var restoration: (operation: OperationID, target: pid_t)?
    private var workspaceObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?
    private var assignedScreenID: String?
    private var layoutRevision: UInt64 = 0
    public private(set) var currentPlacement: Placement?

    public override init() { super.init() }

    public var isVisible: Bool { panel?.isVisible == true }
    public var isKey: Bool { panel?.isKeyWindow == true }
    public var currentOperation: OperationID? { order.current }
    public var frame: NSRect? { panel?.frame }

    public func present(scope: InputScope, operation: OperationID) {
        guard order.accept(operation) else { return }
        let openingSession = request?.scope.session != scope.session
        if openingSession {
            previousApplication = NSWorkspace.shared.frontmostApplication
            assignedScreenID = nil
        }
        restoration = nil
        request = (scope, operation)
        readyScope = nil
        acknowledged = nil
        guard let content else {
            receive?(.operationFailed(operation, "No menu content view")); return
        }
        if panel == nil {
            let window = MenuPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.level = .popUpMenu
            window.hidesOnDeactivate = false
            window.becomesKeyOnlyIfNeeded = false
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = content
            panel = window
            installObservers()
        }
        guard let panel, let placement = placement(center: openingSession ? NSEvent.mouseLocation : nil) else {
            receive?(.operationFailed(operation, "No screen fits the menu")); return
        }
        panel.setFrame(nativeRect(placement.frame), display: true)
        content.frame = NSRect(origin: .zero, size: panel.frame.size)
        assignedScreenID = placement.screenID
        let observed = placement.replacingFrame(valueRect(panel.frame))
        currentPlacement = observed
        receive?(.placementObserved(scope, observed))
        // Opening the menu is an explicit request for keyboard focus. The
        // cooperative activate() API may leave an accessory app in the background.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        content.layoutSubtreeIfNeeded()
        observe("Present requested \(operation.value)")
        acknowledgePresentationIfReady()
    }

    public func inspectPresentation(scope: InputScope, operation: OperationID) {
        guard order.current == operation, request?.scope == scope else { return }
        readyScope = scope
        panel?.contentView?.layoutSubtreeIfNeeded()
        observe("Content ready: visible=\(isVisible), key=\(isKey), application active=\(NSApp.isActive)")
        acknowledgePresentationIfReady()
    }

    private func acknowledgePresentationIfReady() {
        guard let request, order.current == request.operation, readyScope == request.scope,
              acknowledged != request.operation, panel?.isVisible == true, panel?.isKeyWindow == true else { return }
        acknowledged = request.operation
        observe("Presented \(request.operation.value)")
        receive?(.presented(request.operation))
    }

    public func dismiss(scope: InputScope, operation: OperationID) {
        guard order.accept(operation) else { return }
        let ownedFocus = panel?.isKeyWindow == true &&
            NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier
        request = nil
        readyScope = nil
        panel?.orderOut(nil)
        guard panel?.isVisible != true else {
            receive?(.operationFailed(operation, "Panel remains visible")); return
        }
        if ownedFocus, let previousApplication, !previousApplication.isTerminated,
           previousApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            restoration = (operation, previousApplication.processIdentifier)
            observe("Restoring focus to \(previousApplication.localizedName ?? "application") (\(previousApplication.processIdentifier))")
            NSApp.yieldActivation(to: previousApplication)
            if previousApplication.activate(from: .current, options: []) {
                finishRestorationIfObserved()
                return
            }
            observe("Previous application declined activation")
        }
        completeDismissal(operation)
    }

    private func finishRestorationIfObserved(front observedPID: pid_t? = nil) {
        guard let restoration, order.current == restoration.operation,
              let front = observedPID ?? NSWorkspace.shared.frontmostApplication?.processIdentifier else { return }
        observe("Observed foreground application \(front) during restoration")
        if front == restoration.target || front != ProcessInfo.processInfo.processIdentifier {
            completeDismissal(restoration.operation)
        }
    }

    private func completeDismissal(_ operation: OperationID) {
        guard order.current == operation, panel?.isVisible != true else { return }
        restoration = nil
        previousApplication = nil
        observe("Dismissed \(operation.value)")
        receive?(.dismissed(operation))
    }

    public func recover(operation: OperationID) {
        guard order.accept(operation) else { return }
        request = nil; readyScope = nil; restoration = nil; previousApplication = nil
        panel?.orderOut(nil)
        panel?.close()
        guard panel?.isVisible != true else {
            receive?(.operationFailed(operation, "Could not destroy the previous panel")); return
        }
        panel = nil
        currentPlacement = nil
        assignedScreenID = nil
        removeObservers()
        receive?(.recovered(operation))
    }

    public func move(scope: InputScope, placement: Placement, operation: OperationID) {
        guard request?.scope == scope, acknowledged == request?.operation,
              let current = currentPlacement, current.layout == placement.layout,
              current.screenID == placement.screenID, current.bounds == placement.bounds,
              let panel, order.accept(operation) else { return }
        guard panel.isVisible, panel.isKeyWindow, placement.isValid,
              placement.frame.width == current.frame.width, placement.frame.height == current.frame.height else {
            receive?(.operationFailed(operation, "Window is not available for movement")); return
        }
        guard let screen = NSScreen.screens.first(where: { screenID($0) == assignedScreenID }),
              valueRect(screen.visibleFrame) == placement.bounds else {
            screenChanged(); return
        }
        panel.setFrame(nativeRect(placement.frame), display: true)
        let observed = placement.replacingFrame(valueRect(panel.frame))
        currentPlacement = observed
        observe("Moved session \(scope.session.value) revision \(scope.revision), operation \(operation.value): \(observed.frame)")
        receive?(.moved(scope, operation, observed))
    }

    public func windowDidBecomeKey(_ notification: Notification) {
        observe("Panel became key")
        acknowledgePresentationIfReady()
    }
    public func windowDidResignKey(_ notification: Notification) {
        guard let request, acknowledged == request.operation else { return }
        receive?(.focusLost(request.scope))
    }

    public func saveRendering(to url: URL) throws {
        guard let view = panel?.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw CocoaError(.fileWriteUnknown)
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
    }

    private func installObservers() {
        guard workspaceObserver == nil else { return }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            // The notification carries the new application. NSWorkspace's cached
            // frontmostApplication may still describe the previous run-loop turn.
            let activatedPID = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            MainActor.assumeIsolated { self?.finishRestorationIfObserved(front: activatedPID) }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.screenChanged() } }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let request = self.request, self.order.current == request.operation else { return }
                self.observe("Application became active")
                self.panel?.makeKeyAndOrderFront(nil)
                self.acknowledgePresentationIfReady()
            }
        }
    }

    private func removeObservers() {
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
        workspaceObserver = nil; screenObserver = nil; activationObserver = nil
    }

    private func screenChanged() {
        guard let request, let panel, panel.isVisible else { return }
        if let position = placement(center: nil) {
            panel.setFrame(nativeRect(position.frame), display: true)
            assignedScreenID = position.screenID
            let observed = position.replacingFrame(valueRect(panel.frame))
            currentPlacement = observed
            receive?(.placementObserved(request.scope, observed))
        }
        else { receive?(.layoutUnavailable(request.scope)) }
    }

    private func placement(center: NSPoint?) -> Placement? {
        let anchor = center ?? panel.map { NSPoint(x: $0.frame.midX, y: $0.frame.midY) } ?? NSEvent.mouseLocation
        let assigned = NSScreen.screens.first { screenID($0) == assignedScreenID }
        guard let screen = assigned ?? NSScreen.screens.first(where: { $0.frame.contains(anchor) }) ?? NSScreen.main,
              let id = screenID(screen), layoutRevision < UInt64.max else { return nil }
        let bounds = screen.visibleFrame
        guard let frame = Geometry.place(center: Vector(x: anchor.x, y: anchor.y), diameter: Geometry.diameter,
            in: Rect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height)) else { return nil }
        layoutRevision += 1
        return Placement(layout: layoutRevision, screenID: id, bounds: valueRect(bounds), frame: frame)
    }

    private func screenID(_ screen: NSScreen) -> String? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue
    }

    private func valueRect(_ frame: NSRect) -> Rect {
        Rect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
    }

    private func nativeRect(_ frame: Rect) -> NSRect {
        NSRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height)
    }

    private func observe(_ message: String) { onNativeObservation?(message) }
}
