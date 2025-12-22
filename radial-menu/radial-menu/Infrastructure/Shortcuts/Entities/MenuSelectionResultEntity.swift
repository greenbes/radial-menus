//
//  MenuSelectionResultEntity.swift
//  radial-menu
//
//  AppEntity representing the result of a menu selection for Shortcuts.
//

import AppIntents

/// Entity representing the result of a menu selection.
///
/// Returned by ShowMenuIntent and ShowNamedMenuIntent to provide structured
/// information about what the user selected (or if they dismissed the menu).
struct MenuSelectionResultEntity: AppEntity {
    // MARK: - AppEntity Requirements

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: LocalizedStringResource("Menu Selection"))
    }

    static var defaultQuery = MenuSelectionResultEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        if let title = selectedTitle {
            return DisplayRepresentation(
                title: LocalizedStringResource(stringLiteral: "Selected: \(title)"),
                subtitle: actionType.map { LocalizedStringResource(stringLiteral: $0) }
            )
        } else {
            return DisplayRepresentation(
                title: LocalizedStringResource(stringLiteral: "Dismissed"),
                subtitle: LocalizedStringResource(stringLiteral: "No selection made")
            )
        }
    }

    // MARK: - Properties

    /// Unique identifier for this result.
    var id: String

    /// Whether the user dismissed the menu without selecting.
    var wasDismissed: Bool

    /// The selected item's ID (UUID string), if any.
    var selectedID: String?

    /// The selected item's title, if any.
    var selectedTitle: String?

    /// The selected item's icon name, if any.
    var selectedIconName: String?

    /// The selected item's action type description, if any.
    var actionType: String?

    /// The 1-based position in the menu (nil if dismissed).
    var position: Int?

    // MARK: - Initialization

    /// Creates a result entity from a MenuSelectionResult.
    init(from result: MenuSelectionResult?) {
        self.id = UUID().uuidString
        self.wasDismissed = result?.wasDismissed ?? true
        self.selectedID = result?.selectedItem?.id
        self.selectedTitle = result?.selectedItem?.title
        self.selectedIconName = result?.selectedItem?.iconName
        self.actionType = result?.selectedItem?.actionType
        // Convert 0-based to 1-based position for user-friendliness
        self.position = result?.selectedItem.map { $0.position + 1 }
    }

    /// Creates a dismissed result.
    static func dismissed() -> MenuSelectionResultEntity {
        MenuSelectionResultEntity(from: nil)
    }
}

/// Query for MenuSelectionResultEntity (results are not persisted).
struct MenuSelectionResultEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [MenuSelectionResultEntity] {
        // Results are transient and not persisted
        []
    }

    func suggestedEntities() async throws -> [MenuSelectionResultEntity] {
        // No suggestions for results
        []
    }
}
