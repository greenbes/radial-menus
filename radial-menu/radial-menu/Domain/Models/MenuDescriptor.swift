//
//  MenuDescriptor.swift
//  radial-menu
//
//  Lightweight descriptor for listing available menus.
//

import Foundation

/// Lightweight descriptor for listing available menus without loading full definitions.
///
/// Used to display a list of available named menus without needing to load
/// all the menu items and settings.
struct MenuDescriptor: Identifiable, Equatable {
    /// Unique identifier (same as name)
    let id: String

    /// The menu name used for invocation
    let name: String

    /// Optional human-readable description
    let description: String?

    /// Number of items in the menu
    let itemCount: Int

    /// File path for persistent menus (nil for ephemeral menus)
    let filePath: URL?

    // MARK: - Initialization

    init(
        name: String,
        description: String? = nil,
        itemCount: Int,
        filePath: URL? = nil
    ) {
        self.id = name
        self.name = name
        self.description = description
        self.itemCount = itemCount
        self.filePath = filePath
    }

    /// Creates a descriptor from a menu definition
    static func from(_ definition: MenuDefinition, filePath: URL? = nil) -> MenuDescriptor {
        MenuDescriptor(
            name: definition.name,
            description: definition.description,
            itemCount: definition.items.count,
            filePath: filePath
        )
    }
}
