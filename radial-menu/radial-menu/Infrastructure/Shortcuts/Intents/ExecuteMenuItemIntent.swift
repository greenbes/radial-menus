//
//  ExecuteMenuItemIntent.swift
//  radial-menu
//
//  Intent to execute a menu item's action from Shortcuts.
//

import AppIntents
import Foundation

/// Intent to execute a specific menu item's action.
///
/// This is the most useful intent - it allows users to trigger
/// any configured radial menu action directly from Shortcuts.
struct ExecuteMenuItemIntent: AppIntent {
    // MARK: - AppIntent Requirements

    static var title: LocalizedStringResource = "Execute Menu Item"

    static var description = IntentDescription(
        "Executes the action for a specific radial menu item.",
        categoryName: "Radial Menu"
    )

    /// Run in background without showing the app
    static var openAppWhenRun: Bool = false

    // MARK: - Parameters

    @Parameter(
        title: "Menu Item",
        description: "The menu item whose action will be executed"
    )
    var menuItem: MenuItemEntity

    // MARK: - Perform

    func perform() async throws -> some IntentResult {
        LogShortcuts("ExecuteMenuItemIntent: Starting for '\(menuItem.title)'")

        // Find the domain MenuItem
        guard let domainItem = menuItem.toMenuItem() else {
            LogShortcuts("ExecuteMenuItemIntent: Item not found - \(menuItem.id)", level: .error)
            throw ShortcutsIntentError.menuItemNotFound(identifier: menuItem.title)
        }

        // Execute the action
        let executor = ShortcutsServiceLocator.shared.actionExecutor
        let result = executor.execute(domainItem.action)

        switch result {
        case .success:
            LogShortcuts("ExecuteMenuItemIntent: Success - '\(menuItem.title)'")
            return .result(dialog: "Executed '\(menuItem.title)'")

        case .failure(let error):
            LogShortcuts("ExecuteMenuItemIntent: Failed - \(error.localizedDescription)", level: .error)
            throw ShortcutsIntentError.actionFailed(reason: error.localizedDescription)
        }
    }
}

// MARK: - Intent Errors

/// Errors that can occur during Shortcuts intent execution
enum ShortcutsIntentError: Error, CustomLocalizedStringResourceConvertible {
    case menuItemNotFound(identifier: String)
    case menuNotAvailable
    case actionFailed(reason: String)
    case configurationError(reason: String)
    case invalidParameter(name: String, reason: String)
    case permissionDenied(action: String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .menuItemNotFound(let identifier):
            return "Menu item '\(identifier)' not found"
        case .menuNotAvailable:
            return "Radial Menu is not available. Please launch the app first."
        case .actionFailed(let reason):
            return "Action failed: \(reason)"
        case .configurationError(let reason):
            return "Configuration error: \(reason)"
        case .invalidParameter(let name, let reason):
            return "Invalid parameter '\(name)': \(reason)"
        case .permissionDenied(let action):
            return "Permission denied for '\(action)'. Check System Settings > Privacy & Security."
        }
    }
}
