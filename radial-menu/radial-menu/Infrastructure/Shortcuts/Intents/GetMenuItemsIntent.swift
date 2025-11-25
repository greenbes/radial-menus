//
//  GetMenuItemsIntent.swift
//  radial-menu
//
//  Intent to retrieve all configured menu items from Shortcuts.
//

import AppIntents
import Foundation

/// Intent to retrieve all configured menu items.
///
/// This intent enables discovery of menu items for building
/// Shortcuts workflows. Returns an array of MenuItemEntity objects.
struct GetMenuItemsIntent: AppIntent {
    // MARK: - AppIntent Requirements

    static var title: LocalizedStringResource = "Get Menu Items"

    static var description = IntentDescription(
        "Get a list of all configured radial menu items.",
        categoryName: "Radial Menu"
    )

    /// Run in background without showing the app
    static var openAppWhenRun: Bool = false

    // MARK: - Perform

    func perform() async throws -> some IntentResult & ReturnsValue<[MenuItemEntity]> {
        LogShortcuts("GetMenuItemsIntent: Fetching menu items")

        let config = ShortcutsServiceLocator.shared.configManager.currentConfiguration
        let entities = config.items.enumerated()
            .map { MenuItemEntity(from: $0.element, at: $0.offset) }

        LogShortcuts("GetMenuItemsIntent: Returning \(entities.count) items")

        return .result(value: entities)
    }
}
