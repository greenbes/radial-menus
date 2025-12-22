//
//  NamedMenuEntity.swift
//  radial-menu
//
//  AppEntity representing a named menu for Shortcuts integration.
//

import AppIntents

/// AppEntity representing a saved named menu.
///
/// Named menus are stored in `~/Library/Application Support/com.radial-menu/menus/`.
/// This entity enables Shortcuts users to select from available menus in a picker UI.
struct NamedMenuEntity: AppEntity {
    // MARK: - AppEntity Requirements

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource("Named Menu"),
            numericFormat: LocalizedStringResource("\(placeholder: .int) menus")
        )
    }

    static var defaultQuery = NamedMenuEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            subtitle: menuDescription.map { LocalizedStringResource(stringLiteral: $0) },
            image: .init(systemName: "circle.grid.cross")
        )
    }

    // MARK: - Properties

    /// Unique identifier (same as name).
    var id: String

    /// The menu name.
    var name: String

    /// Optional description of the menu.
    var menuDescription: String?

    /// Number of items in the menu.
    var itemCount: Int

    // MARK: - Initialization

    /// Creates an entity from a MenuDescriptor.
    init(from descriptor: MenuDescriptor) {
        self.id = descriptor.name
        self.name = descriptor.name
        self.menuDescription = descriptor.description
        self.itemCount = descriptor.itemCount
    }

    /// Memberwise initializer.
    init(id: String, name: String, menuDescription: String?, itemCount: Int) {
        self.id = id
        self.name = name
        self.menuDescription = menuDescription
        self.itemCount = itemCount
    }
}

/// Query for discovering and selecting named menus.
struct NamedMenuEntityQuery: EntityQuery, EntityStringQuery {
    // MARK: - EntityQuery

    /// Find entities by their IDs (used when an intent runs).
    func entities(for identifiers: [String]) async throws -> [NamedMenuEntity] {
        let menus = ShortcutsServiceLocator.shared.menuProvider.availableMenus
        return menus
            .filter { identifiers.contains($0.name) }
            .map { NamedMenuEntity(from: $0) }
    }

    /// Provide all entities for the picker (used in Shortcuts editor).
    func suggestedEntities() async throws -> [NamedMenuEntity] {
        let menus = ShortcutsServiceLocator.shared.menuProvider.availableMenus
        return menus.map { NamedMenuEntity(from: $0) }
    }

    // MARK: - EntityStringQuery

    /// Search entities by name string (used for manual text entry in Shortcuts).
    func entities(matching string: String) async throws -> [NamedMenuEntity] {
        let lowercasedQuery = string.lowercased()
        let menus = ShortcutsServiceLocator.shared.menuProvider.availableMenus
        return menus
            .filter { $0.name.lowercased().contains(lowercasedQuery) }
            .map { NamedMenuEntity(from: $0) }
    }
}
