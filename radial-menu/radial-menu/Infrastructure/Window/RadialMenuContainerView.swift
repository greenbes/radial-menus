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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        print("🏗️ RadialMenuContainerView: init with frame \(frameRect)")
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
            print("🔄 RadialMenuContainerView: Menu active state changed to \(active)")
            self.isMenuActive = active
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

    /// Allow the view to become first responder for keyboard events
    override var acceptsFirstResponder: Bool {
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

    func makeNSView(context: Context) -> RadialMenuContainerView {
        print("🔨 RadialMenuContainer: makeNSView")
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

        // Update SwiftUI content
        if let hostingView = nsView.subviews.first as? NSHostingView<Content> {
            hostingView.rootView = content
        }
    }
}
