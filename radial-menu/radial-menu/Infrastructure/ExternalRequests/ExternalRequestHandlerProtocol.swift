//
//  ExternalRequestHandlerProtocol.swift
//  radial-menu
//
//  Protocol for handling external requests from URL scheme, App Intents, and AppleScript.
//

import Foundation
import CoreGraphics

/// Protocol for handling external requests from URL scheme, App Intents, and AppleScript.
///
/// This provides a unified interface for all external request sources, avoiding code duplication
/// and ensuring consistent behavior across URL schemes, Shortcuts, and AppleScript.
protocol ExternalRequestHandlerProtocol {
    /// Show menu with specified source and wait for selection.
    ///
    /// - Parameters:
    ///   - source: The menu source (default, named, file, or JSON)
    ///   - position: Optional position for the menu
    ///   - returnOnly: If true, returns selection without executing action
    /// - Returns: The selection result, or nil if menu couldn't be shown
    @MainActor
    func showMenu(
        source: MenuSource,
        position: MenuPosition?,
        returnOnly: Bool
    ) async throws -> MenuSelectionResult?

    /// Execute a specific menu item's action.
    ///
    /// - Parameter item: The menu item to execute
    func executeItem(_ item: MenuItem) async throws

    /// Get all available named menus.
    ///
    /// - Returns: Array of menu descriptors for all discovered named menus
    func getNamedMenus() -> [MenuDescriptor]

    /// Get items from the current default configuration.
    ///
    /// - Returns: Array of menu items from the default configuration
    func getMenuItems() -> [MenuItem]
}

/// Specifies where the menu should appear.
enum MenuPosition: Equatable {
    /// At the current cursor location (default behavior)
    case cursor

    /// Centered on the main screen
    case center

    /// At a fixed screen coordinate
    case fixed(x: Double, y: Double)

    /// Convert to CGPoint for the overlay window.
    /// Returns nil for cursor (uses default behavior) and center (handled by config).
    func toCGPoint() -> CGPoint? {
        switch self {
        case .cursor, .center:
            return nil
        case .fixed(let x, let y):
            return CGPoint(x: x, y: y)
        }
    }
}

/// Errors that can occur during external request handling.
enum ExternalRequestError: LocalizedError {
    case viewModelNotAvailable
    case menuSourceInvalid(reason: String)
    case actionFailed(reason: String)
    case invalidParameter(name: String, reason: String)
    case menuNotFound(name: String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .viewModelNotAvailable:
            return "Radial Menu UI is not available"
        case .menuSourceInvalid(let reason):
            return "Invalid menu source: \(reason)"
        case .actionFailed(let reason):
            return "Action failed: \(reason)"
        case .invalidParameter(let name, let reason):
            return "Invalid parameter '\(name)': \(reason)"
        case .menuNotFound(let name):
            return "Menu not found: \(name)"
        case .timeout:
            return "Operation timed out"
        }
    }
}
