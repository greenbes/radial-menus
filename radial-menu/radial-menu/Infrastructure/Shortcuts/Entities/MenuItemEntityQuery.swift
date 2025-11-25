//
//  MenuItemEntityQuery.swift
//  radial-menu
//
//  EntityQuery implementation for discovering and looking up menu items.
//

import AppIntents
import Foundation

/// Query for discovering and looking up menu items in Shortcuts.
///
/// Supports:
/// - Finding entities by their UUIDs (used when intent runs)
/// - Suggesting all entities for the picker (used in Shortcuts editor)
/// - String-based search by title (via EntityStringQuery)
struct MenuItemEntityQuery: EntityQuery, EntityStringQuery {
    // MARK: - EntityQuery

    /// Find entities by their IDs (used when an intent runs)
    func entities(for identifiers: [String]) async throws -> [MenuItemEntity] {
        let config = ShortcutsServiceLocator.shared.configManager.currentConfiguration

        return config.items.enumerated()
            .filter { identifiers.contains($0.element.id.uuidString) }
            .map { MenuItemEntity(from: $0.element, at: $0.offset) }
    }

    /// Provide all entities for the picker (used in Shortcuts editor)
    func suggestedEntities() async throws -> [MenuItemEntity] {
        let config = ShortcutsServiceLocator.shared.configManager.currentConfiguration

        return config.items.enumerated()
            .map { MenuItemEntity(from: $0.element, at: $0.offset) }
    }

    // MARK: - EntityStringQuery

    /// Search entities by title string (used for manual text entry in Shortcuts)
    func entities(matching string: String) async throws -> [MenuItemEntity] {
        let config = ShortcutsServiceLocator.shared.configManager.currentConfiguration
        let lowercasedQuery = string.lowercased()

        return config.items.enumerated()
            .filter { $0.element.title.lowercased().contains(lowercasedQuery) }
            .map { MenuItemEntity(from: $0.element, at: $0.offset) }
    }
}
