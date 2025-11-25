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
    
    // Event callbacks
    var onMouseMove: ((CGPoint) -> Void)?
    var onMouseClick: ((CGPoint) -> Void)?
    var onKeyboardNavigation: ((Bool) -> Void)?
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?

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
        // Log("🖱️ ContainerView: Raw \(event.locationInWindow) -> Local \(localPoint)")
        onMouseMove?(localPoint)
    }
    
    override func mouseDown(with event: NSEvent) {
        guard isMenuActive else {
            super.mouseDown(with: event)
            return
        }
        // Consume event
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isMenuActive else {
            super.mouseUp(with: event)
            return
        }
        let localPoint = convert(event.locationInWindow, from: nil)
        onMouseClick?(localPoint)
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
        LogInput("Unhandled key command: \(selector)")
        // Don't call super - prevents system beep for unhandled keys
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

        // Add SwiftUI content as subview
        let hostingView = NSHostingView(rootView: content)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = view.bounds
        view.addSubview(hostingView)

        return view
    }

    func updateNSView(_ nsView: RadialMenuContainerView, context: Context) {
        // print("♻️ RadialMenuContainer: updateNSView")
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

        // Update SwiftUI content
        if let hostingView = nsView.subviews.first as? NSHostingView<Content> {
            hostingView.rootView = content
        }
    }
}
