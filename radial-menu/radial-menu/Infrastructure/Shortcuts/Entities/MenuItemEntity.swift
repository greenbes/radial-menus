//
//  MenuItemEntity.swift
//  radial-menu
//
//  AppEntity representation of a menu item for Shortcuts integration.
//

import AppIntents
import Foundation

/// AppEntity representing a menu item for Shortcuts integration.
///
/// This entity wraps the domain `MenuItem` model and exposes it to the
/// Shortcuts app for parameter picking and entity queries.
struct MenuItemEntity: AppEntity {
    // MARK: - AppEntity Requirements

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource("Menu Item"),
            numericFormat: LocalizedStringResource("\(placeholder: .int) menu items")
        )
    }

    static var defaultQuery = MenuItemEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            subtitle: LocalizedStringResource(stringLiteral: actionDescription),
            image: .init(systemName: systemImageName)
        )
    }

    // MARK: - Properties

    /// Unique identifier (the UUID from MenuItem, stored as String for AppEntity compatibility)
    var id: String

    /// User-visible title
    var title: String

    /// Semantic icon name
    var iconName: String

    /// Human-readable action description
    var actionDescription: String

    /// Position in menu (1-based for user display)
    var position: Int

    /// SF Symbol name for Shortcuts UI
    var systemImageName: String

    // MARK: - Initialization

    /// Creates an entity from a domain MenuItem
    init(from menuItem: MenuItem, at index: Int) {
        self.id = menuItem.id.uuidString
        self.title = menuItem.title
        self.iconName = menuItem.iconName
        self.actionDescription = menuItem.action.description
        self.position = index + 1 // 1-based for users
        self.systemImageName = Self.mapIconToSystemImage(menuItem.iconName)
    }

    /// Bare initializer for AppEntity conformance
    init(
        id: String,
        title: String,
        iconName: String,
        actionDescription: String,
        position: Int
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.actionDescription = actionDescription
        self.position = position
        self.systemImageName = Self.mapIconToSystemImage(iconName)
    }

    // MARK: - Domain Conversion

    /// Converts back to domain MenuItem for execution.
    /// Returns nil if the item no longer exists in configuration.
    func toMenuItem() -> MenuItem? {
        guard let uuid = UUID(uuidString: id) else {
            return nil
        }

        let config = ShortcutsServiceLocator.shared.configManager.currentConfiguration
        return config.items.first { $0.id == uuid }
    }

    // MARK: - Private Helpers

    /// Maps semantic icon names to SF Symbols for Shortcuts UI
    private static func mapIconToSystemImage(_ iconName: String) -> String {
        // Map common semantic icon names to SF Symbols
        let mapping: [String: String] = [
            "terminal": "terminal",
            "safari": "safari",
            "camera": "camera",
            "camera.shutter.button": "camera",
            "calendar": "calendar",
            "folder": "folder",
            "note.text": "note.text",
            "speaker.slash": "speaker.slash",
            "speaker.wave.3": "speaker.wave.3",
            "list.bullet.rectangle": "list.bullet",
            "checkmark.circle": "checkmark.circle",
            "gear": "gear",
            "star": "star",
            "heart": "heart",
            "doc": "doc",
            "envelope": "envelope",
            "message": "message",
            "phone": "phone",
            "magnifyingglass": "magnifyingglass",
            "house": "house",
            "person": "person",
            "photo": "photo",
            "music.note": "music.note",
            "video": "video",
            "map": "map",
            "clock": "clock"
        ]

        return mapping[iconName] ?? "circle"
    }
}
