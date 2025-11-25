//
//  RemoveMenuItemIntent.swift
//  radial-menu
//
//  Intent to remove a menu item via Shortcuts.
//

import AppIntents
import Foundation

/// Intent to remove a menu item from the radial menu.
///
/// Allows users to delete items from their menu configuration
/// directly from Shortcuts workflows.
struct RemoveMenuItemIntent: AppIntent {
    // MARK: - AppIntent Requirements

    static var title: LocalizedStringResource = "Remove Menu Item"

    static var description = IntentDescription(
        "Remove an item from the radial menu.",
        categoryName: "Radial Menu"
    )

    static var openAppWhenRun: Bool = false

    // MARK: - Parameters

    @Parameter(
        title: "Menu Item",
        description: "The menu item to remove"
    )
    var menuItem: MenuItemEntity

    // MARK: - Perform

    func perform() async throws -> some IntentResult {
        LogShortcuts("RemoveMenuItemIntent: Removing '\(menuItem.title)'")

        guard let uuid = UUID(uuidString: menuItem.id) else {
            throw ShortcutsIntentError.menuItemNotFound(identifier: menuItem.title)
        }

        let configManager = ShortcutsServiceLocator.shared.configManager
        var config = configManager.currentConfiguration

        // Check if item exists
        guard config.items.contains(where: { $0.id == uuid }) else {
            LogShortcuts("RemoveMenuItemIntent: Item not found - \(menuItem.id)", level: .error)
            throw ShortcutsIntentError.menuItemNotFound(identifier: menuItem.title)
        }

        // Remove the item
        config.items.removeAll { $0.id == uuid }

        do {
            try configManager.saveConfiguration(config)
        } catch {
            LogShortcuts("RemoveMenuItemIntent: Failed to save - \(error)", level: .error)
            throw ShortcutsIntentError.configurationError(reason: error.localizedDescription)
        }

        LogShortcuts("RemoveMenuItemIntent: Success - removed '\(menuItem.title)'")
        return .result(dialog: "Removed '\(menuItem.title)' from menu")
    }
}
