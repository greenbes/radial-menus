import AppKit
import RadialCore
import RadialRuntime

/// Copies native mouse observations into values; selection policy stays in the core.
@MainActor final class PointerAdapter: NSObject {
    private weak var view: NSView?
    private var scope: InputScope?
    private var layout: UInt64 = 0
    private var sequence: UInt64 = 0
    private var monitor: Any?
    private var area: NSTrackingArea?
    private var receive: EventReceiver?

    func start(view: NSView, scope: InputScope, layout: UInt64, receive: @escaping EventReceiver) {
        stop()
        self.view = view; self.scope = scope; self.layout = layout; self.receive = receive
        // Presentation and screen changes establish a baseline, never a selection.
        emit(screen: NSEvent.mouseLocation, timestamp: ProcessInfo.processInfo.systemUptime, baseline: true)
        let area = NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect, .enabledDuringMouseDrag],
            owner: self, userInfo: nil)
        view.addTrackingArea(area)
        self.area = area
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged,
                                                             .rightMouseDragged, .otherMouseDragged]) { [weak self] event in
            // CGEvent keeps its desktop location even if the window has moved
            // since this event was queued. Converting locationInWindow here would
            // incorrectly attribute the intervening window movement to the mouse.
            if let point = event.cgEvent?.unflippedLocation {
                self?.emit(screen: point, timestamp: event.timestamp)
            }
            return event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let area { view?.removeTrackingArea(area) }
        monitor = nil; area = nil; view = nil; scope = nil; receive = nil
    }

    // Entering can be caused solely by window motion. Only a mouse-movement
    // event can take selection; otherwise an old position from outside this app
    // could make a stationary pointer appear to have moved when the menu arrives.
    @objc func mouseEntered(with event: NSEvent) {}
    @objc func mouseExited(with event: NSEvent) { observeTrackingChange(event) }

    private func observeTrackingChange(_ event: NSEvent) {
        guard event.trackingArea === area else { return }
        // AppKit can generate enter/exit events after window motion. Observe the
        // actual screen position; the core decides whether the pointer moved.
        emit(screen: NSEvent.mouseLocation, timestamp: ProcessInfo.processInfo.systemUptime)
    }

    private func emit(screen: NSPoint, timestamp: Double, baseline: Bool = false) {
        guard let scope, let view, let window = view.window,
              baseline || (window.isVisible && window.isKeyWindow), sequence < UInt64.max else { return }
        let local = view.convert(window.convertPoint(fromScreen: screen), from: nil)
        sequence += 1
        let sample = PointerSample(sequence: sequence, timestamp: timestamp, layout: layout,
            screenPosition: Vector(x: screen.x, y: screen.y),
            menuPosition: Vector(x: local.x - view.bounds.midX,
                                 y: view.isFlipped ? local.y - view.bounds.midY : view.bounds.midY - local.y))
        receive?(baseline ? .pointerBaseline(scope, sample) : .pointerMoved(scope, sample))
    }
}
