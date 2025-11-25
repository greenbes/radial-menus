//
//  OverlayWindowProtocol.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation
import CoreGraphics
import SwiftUI

/// Protocol for managing the overlay window
protocol OverlayWindowProtocol {
    /// Show the overlay window
    /// - Parameter position: Position to show the window (nil for cursor position)
    func show(at position: CGPoint?)

    /// Hide the overlay window
    func hide()

    /// Update the window's content view
    /// - Parameter view: SwiftUI view to display
    func updateContent<Content: View>(_ view: Content)

    /// Set whether clicks outside the menu should pass through
    /// - Parameter enabled: True to enable click-through
    func setClickThrough(_ enabled: Bool)

    /// Update the window size based on radius
    /// - Parameter radius: The menu radius
    func updateWindowSize(forRadius radius: Double)

    /// Check if window is currently visible
    var isVisible: Bool { get }

    /// Get the current center position of the window
    var centerPosition: CGPoint { get }

    /// Move the window by the specified delta
    /// - Parameters:
    ///   - dx: Horizontal delta in points
    ///   - dy: Vertical delta in points
    func moveWindow(dx: CGFloat, dy: CGFloat)

    /// Set callback for when window focus (key status) changes
    /// - Parameter callback: Called with true when window becomes key, false when it resigns
    func setFocusChangeCallback(_ callback: @escaping (Bool) -> Void)
}
