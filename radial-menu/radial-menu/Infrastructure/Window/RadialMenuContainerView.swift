//
//  RadialMenuContainerView.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import AppKit
import SwiftUI

/// Custom NSView that implements click-through behavior and event handling for the radial menu
class RadialMenuContainerView: NSView {
    private var menuCenter: CGPoint = .zero
    private var menuRadius: Double = 150.0
    private var centerRadius: Double = 40.0
    private var slices: [RadialGeometry.Slice] = []
    private var isMenuActive: Bool = false

    // Drag state for center area repositioning
    private var isDragging: Bool = false
    private var lastDragLocation: CGPoint = .zero

    // Event callbacks
    var onMouseMove: ((CGPoint) -> Void)?
    var onMouseClick: ((CGPoint) -> Void)?
    var onKeyboardNavigation: ((Bool) -> Void)?
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?
    var onDrag: ((CGFloat, CGFloat) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        LogWindow("RadialMenuContainerView init with frame \(frameRect)")
        setupTrackingArea()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTrackingArea()
    }
    
    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseMoved, .activeAlways, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    override func layout() {
        super.layout()
        // Ensure subviews (the hosting view) fill the container
        subviews.forEach { $0.frame = bounds }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            window?.makeFirstResponder(self)
        }
    }

    /// Update the menu geometry for hit testing
    func updateGeometry(
        center: CGPoint,
        radius: Double,
        centerRadius: Double,
        slices: [RadialGeometry.Slice]
    ) {
        // print("📐 RadialMenuContainerView: Updating geometry. Center: \(center), Radius: \(radius), Slices: \(slices.count)")
        self.menuCenter = center
        self.menuRadius = radius
        self.centerRadius = centerRadius
        self.slices = slices
    }

    /// Set whether the menu is active
    func setMenuActive(_ active: Bool) {
        if self.isMenuActive != active {
            LogWindow("Menu active state changed to \(active)")
            self.isMenuActive = active

            // Re-assert first responder when menu becomes active
            if active {
                window?.makeFirstResponder(self)
            }
        }
    }

    /// Override hitTest to implement click-through behavior
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isMenuActive else {
            // If menu is not active, pass through all clicks
            return nil
        }

        // Convert point to view coordinates
        let localPoint = convert(point, from: superview)

        // Check if click is inside the radial menu
        let isInside = HitDetector.isInsideMenu(
            point: localPoint,
            center: menuCenter,
            radius: menuRadius
        )

        if isInside {
            // Click is inside menu - handle it
            return self
        } else {
            // Click is outside menu - pass through
            return nil
        }
    }
    
    // MARK: - Mouse Events

    override func mouseMoved(with event: NSEvent) {
        guard isMenuActive else { return }
        let localPoint = convert(event.locationInWindow, from: nil)
        onMouseMove?(localPoint)
    }

    override func mouseDown(with event: NSEvent) {
        guard isMenuActive else {
            super.mouseDown(with: event)
            return
        }

        let localPoint = convert(event.locationInWindow, from: nil)

        // Check if mouse down is in center area - start drag
        if isPointInCenterArea(localPoint) {
            isDragging = true
            // Use screen coordinates for drag tracking (window-relative coords shift as window moves)
            lastDragLocation = NSEvent.mouseLocation
            LogInput("Started center drag at \(localPoint)")
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isMenuActive, isDragging else { return }

        // Use screen coordinates to track drag delta
        let currentLocation = NSEvent.mouseLocation
        let dx = currentLocation.x - lastDragLocation.x
        let dy = currentLocation.y - lastDragLocation.y

        lastDragLocation = currentLocation
        onDrag?(dx, dy)
    }

    override func mouseUp(with event: NSEvent) {
        guard isMenuActive else {
            super.mouseUp(with: event)
            return
        }

        let localPoint = convert(event.locationInWindow, from: nil)

        if isDragging {
            // End drag - don't trigger click
            isDragging = false
            LogInput("Ended center drag")
        } else {
            // Normal click
            onMouseClick?(localPoint)
        }
    }

    // MARK: - Hit Testing Helpers

    private func isPointInCenterArea(_ point: CGPoint) -> Bool {
        let dx = point.x - menuCenter.x
        let dy = point.y - menuCenter.y
        let distance = sqrt(dx * dx + dy * dy)
        return distance <= centerRadius
    }
    
    // MARK: - Keyboard Events

    override func keyDown(with event: NSEvent) {
        guard isMenuActive else {
            super.keyDown(with: event)
            return
        }

        LogInput("KeyDown: interpreting via standard key bindings (keyCode: \(event.keyCode))")
        interpretKeyEvents([event])
    }

    // MARK: - NSStandardKeyBindingResponding

    override func moveLeft(_ sender: Any?) {
        LogInput("moveLeft: (standard key binding)")
        onKeyboardNavigation?(false) // Counter-clockwise
    }

    override func moveRight(_ sender: Any?) {
        LogInput("moveRight: (standard key binding)")
        onKeyboardNavigation?(true) // Clockwise
    }

    override func moveUp(_ sender: Any?) {
        LogInput("moveUp: (standard key binding)")
        onKeyboardNavigation?(false) // Counter-clockwise toward top
    }

    override func moveDown(_ sender: Any?) {
        LogInput("moveDown: (standard key binding)")
        onKeyboardNavigation?(true) // Clockwise toward bottom
    }

    override func insertNewline(_ sender: Any?) {
        LogInput("insertNewline: confirming selection")
        onConfirm?()
    }

    override func cancelOperation(_ sender: Any?) {
        LogInput("cancelOperation: closing menu")
        onCancel?()
    }

    override func insertTab(_ sender: Any?) {
        LogInput("insertTab: moving clockwise")
        onKeyboardNavigation?(true)
    }

    override func insertBacktab(_ sender: Any?) {
        LogInput("insertBacktab: moving counter-clockwise")
        onKeyboardNavigation?(false)
    }

    override func doCommand(by selector: Selector) {
        // Try to perform the selector if we respond to it
        if responds(to: selector) {
            perform(selector, with: nil)
        } else {
            LogInput("Unhandled key command: \(selector)")
            // Don't call super - prevents system beep for unhandled keys
        }
    }

    /// Allow the view to become first responder for keyboard events
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    /// Flip coordinate system to match SwiftUI/Screen coordinates (Top-Left origin)
    override var isFlipped: Bool {
        return true
    }
}

/// SwiftUI wrapper for RadialMenuContainerView
struct RadialMenuContainer<Content: View>: NSViewRepresentable {
    let content: Content
    let menuCenter: CGPoint
    let menuRadius: Double
    let centerRadius: Double
    let slices: [RadialGeometry.Slice]
    let isActive: Bool
    let onMouseMove: (CGPoint) -> Void
    let onMouseClick: (CGPoint) -> Void
    let onKeyboardNavigation: (Bool) -> Void
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onDrag: ((CGFloat, CGFloat) -> Void)?

    func makeNSView(context: Context) -> RadialMenuContainerView {
        LogWindow("RadialMenuContainer makeNSView")
        let view = RadialMenuContainerView()
        view.updateGeometry(
            center: menuCenter,
            radius: menuRadius,
            centerRadius: centerRadius,
            slices: slices
        )
        view.setMenuActive(isActive)
        view.onMouseMove = onMouseMove
        view.onMouseClick = onMouseClick
        view.onKeyboardNavigation = onKeyboardNavigation
        view.onConfirm = onConfirm
        view.onCancel = onCancel
        view.onDrag = onDrag

        // Add SwiftUI content as subview
        let hostingView = NSHostingView(rootView: content)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = view.bounds
        view.addSubview(hostingView)

        return view
    }

    func updateNSView(_ nsView: RadialMenuContainerView, context: Context) {
        nsView.updateGeometry(
            center: menuCenter,
            radius: menuRadius,
            centerRadius: centerRadius,
            slices: slices
        )
        nsView.setMenuActive(isActive)
        nsView.onMouseMove = onMouseMove
        nsView.onMouseClick = onMouseClick
        nsView.onKeyboardNavigation = onKeyboardNavigation
        nsView.onConfirm = onConfirm
        nsView.onCancel = onCancel
        nsView.onDrag = onDrag

        // Update SwiftUI content
        if let hostingView = nsView.subviews.first as? NSHostingView<Content> {
            hostingView.rootView = content
        }
    }
}
