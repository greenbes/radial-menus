//
//  OverlayWindowController.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import AppKit
import SwiftUI

/// Custom NSPanel that can become key (receive keyboard input) even when borderless
class RadialMenuWindow: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

/// Manages the transparent overlay window for the radial menu
class OverlayWindowController: OverlayWindowProtocol {
    private var window: RadialMenuWindow?
    private var hostingView: NSHostingView<AnyView>?
    private var windowSize: CGSize

    init(windowSize: CGSize = CGSize(width: 400, height: 400)) {
        self.windowSize = windowSize
    }

    /// Update the window size based on radius
    func updateWindowSize(forRadius radius: Double) {
        // Window needs to be large enough to contain the full radius + some padding
        // Formula: diameter + 2 * (margin for labels and padding)
        let size = radius * 2.2  // 2.1x used in RadialMenuView, adding a bit more for safety
        let newSize = CGSize(width: size, height: size)

        guard newSize != windowSize else { return }

        windowSize = newSize

        // If window exists, update its size
        if let window = window, window.isVisible {
            let currentCenter = CGPoint(
                x: window.frame.origin.x + window.frame.width / 2,
                y: window.frame.origin.y + window.frame.height / 2
            )

            let newOrigin = CGPoint(
                x: currentCenter.x - newSize.width / 2,
                y: currentCenter.y - newSize.height / 2
            )

            window.setFrame(
                NSRect(origin: newOrigin, size: newSize),
                display: true,
                animate: false
            )

            // Update hosting view frame
            hostingView?.frame = NSRect(origin: .zero, size: newSize)
        }
    }

    func show(at position: CGPoint?) {
        LogWindow("show() called, position: \(String(describing: position))")

        if window == nil {
            LogWindow("Window is nil, creating")
            createWindow()
        }

        guard let window = window else {
            LogError("Failed to create window", category: .window)
            return
        }

        // Position the window
        // Note: Cocoa coords are bottom-left origin. Mouse location is usually bottom-left relative to screen.
        let targetPosition = position ?? NSEvent.mouseLocation
        let windowOrigin = CGPoint(
            x: targetPosition.x - windowSize.width / 2,
            y: targetPosition.y - windowSize.height / 2
        )

        LogWindow("Positioning window at \(windowOrigin), mouse: \(NSEvent.mouseLocation)")

        window.setFrameOrigin(windowOrigin)

        // Force activation to ensure SwiftUI renders and we capture keyboard events
        NSApp.activate(ignoringOtherApps: true)

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        LogWindow("Window frame: \(window.frame), visible: \(window.isVisible)")
    }

    func hide() {
        LogWindow("Hiding window")
        window?.orderOut(nil)
        // Optionally deactivate app to return focus to previous app? 
        // For now, let's just hide the window. The user will likely click elsewhere or the previous app will remain active if we didn't fully steal focus context.
        // Actually, since we called NSApp.activate, we are now the active app. 
        // We might want to use `NSApp.hide(nil)` or similar if we want to return focus, 
        // but typically clicking on another window handles that.
        // For a strictly keyboard workflow, `NSApp.hide(nil)` might be smoother.
        NSApp.hide(nil)
    }

    func updateContent<Content: View>(_ view: Content) {
        let anyView = AnyView(view)

        if let hostingView = hostingView {
            hostingView.rootView = anyView
        } else {
            let newHostingView = NSHostingView(rootView: anyView)
            newHostingView.identifier = NSUserInterfaceItemIdentifier("ContentHostingView")
            newHostingView.frame = NSRect(origin: .zero, size: windowSize)
            newHostingView.autoresizingMask = [.width, .height]
            
            hostingView = newHostingView
        }
        
        // Ensure window exists so it gets this content
        if window == nil {
            createWindow()
        } else {
            window?.contentView = hostingView
        }
        
        hostingView?.needsLayout = true
        hostingView?.layoutSubtreeIfNeeded()
    }

    func setClickThrough(_ enabled: Bool) {
        window?.ignoresMouseEvents = enabled
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    var centerPosition: CGPoint {
        guard let window = window else { return .zero }
        let frame = window.frame
        return CGPoint(
            x: frame.origin.x + frame.width / 2,
            y: frame.origin.y + frame.height / 2
        )
    }

    func moveWindow(dx: CGFloat, dy: CGFloat) {
        guard let window = window, window.isVisible else { return }

        let currentOrigin = window.frame.origin
        let newOrigin = CGPoint(
            x: currentOrigin.x + dx,
            y: currentOrigin.y + dy
        )
        window.setFrameOrigin(newOrigin)
    }

    // MARK: - Private Methods

    private func createWindow() {
        LogWindow("Creating RadialMenuWindow with size \(windowSize)")
        let panel = RadialMenuWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless], // Removed .nonactivatingPanel to allow key status
            backing: .buffered,
            defer: false
        )

        // Configure transparency
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false

        // Configure floating behavior - .popUpMenu is higher than .floating
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Don't show in window switcher
        panel.hidesOnDeactivate = false

        // Use existing hosting view if available, otherwise create empty one
        if let existingHostingView = hostingView {
            LogWindow("Using existing hosting view")
            panel.contentView = existingHostingView
        } else {
            LogWindow("Creating new empty hosting view")
            let emptyView = NSHostingView(rootView: AnyView(EmptyView()))
            emptyView.frame = NSRect(origin: .zero, size: windowSize)
            emptyView.autoresizingMask = [.width, .height]
            panel.contentView = emptyView
            hostingView = emptyView
        }

        window = panel
        LogWindow("Window created successfully")
    }
}
