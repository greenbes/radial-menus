//
//  MenuSelectionResult.swift
//  radial-menu
//
//  Result of a menu selection operation for external requests.
//

import Foundation

/// Result of a menu selection operation.
///
/// Used by external interfaces (URL scheme, App Intents, AppleScript) to return
/// structured information about what the user selected.
struct MenuSelectionResult: Codable, Equatable {
    /// The selected item, if any.
    let selectedItem: MenuItemResult?

    /// Whether the menu was dismissed without a selection.
    let wasDismissed: Bool

    /// Creates a result for a successful selection.
    static func selected(_ item: MenuItemResult) -> MenuSelectionResult {
        MenuSelectionResult(selectedItem: item, wasDismissed: false)
    }

    /// Creates a result for a dismissed menu.
    static func dismissed() -> MenuSelectionResult {
        MenuSelectionResult(selectedItem: nil, wasDismissed: true)
    }

    /// Information about a selected menu item.
    struct MenuItemResult: Codable, Equatable {
        /// The unique identifier of the menu item (UUID string).
        let id: String

        /// The display title of the menu item.
        let title: String

        /// The icon name for the menu item.
        let iconName: String

        /// The type of action (e.g., "launchApp", "runShellCommand").
        let actionType: String

        /// The 0-based position in the menu.
        let position: Int

        /// Creates a result from a domain MenuItem.
        ///
        /// - Parameters:
        ///   - item: The domain menu item
        ///   - position: The 0-based position in the menu
        init(from item: MenuItem, position: Int) {
            self.id = item.id.uuidString
            self.title = item.title
            self.iconName = item.iconName
            self.actionType = item.action.typeDescription
            self.position = position
        }

        /// Memberwise initializer for testing and direct construction.
        init(id: String, title: String, iconName: String, actionType: String, position: Int) {
            self.id = id
            self.title = title
            self.iconName = iconName
            self.actionType = actionType
            self.position = position
        }
    }
}

/// Extension to convert MenuSelectionResult to JSON for external use.
extension MenuSelectionResult {
    /// Encodes the result as a JSON string.
    func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Encodes the result as a compact JSON string (no pretty printing).
    func toCompactJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
