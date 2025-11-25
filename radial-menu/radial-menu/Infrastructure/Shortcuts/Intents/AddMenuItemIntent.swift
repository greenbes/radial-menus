//
//  AddMenuItemIntent.swift
//  radial-menu
//
//  Intent to add a new menu item via Shortcuts.
//

import AppIntents
import Foundation

/// Intent to create a new menu item in the radial menu.
///
/// Allows users to add new items to their menu configuration
/// directly from Shortcuts workflows.
struct AddMenuItemIntent: AppIntent {
    // MARK: - AppIntent Requirements

    static var title: LocalizedStringResource = "Add Menu Item"

    static var description = IntentDescription(
        "Add a new item to the radial menu.",
        categoryName: "Radial Menu"
    )

    static var openAppWhenRun: Bool = false

    // MARK: - Parameters

    @Parameter(
        title: "Title",
        description: "The display name for the menu item"
    )
    var title: String

    @Parameter(
        title: "Icon Name",
        description: "SF Symbol name or custom icon identifier (e.g., 'terminal', 'safari')"
    )
    var iconName: String

    @Parameter(
        title: "Action Type",
        description: "The type of action this item will perform"
    )
    var actionType: ActionTypeAppEnum

    @Parameter(
        title: "Action Value",
        description: "The value for the action: app path, shell command, or key"
    )
    var actionValue: String

    @Parameter(
        title: "Modifiers",
        description: "Keyboard modifiers (only for keyboard shortcuts)"
    )
    var modifiers: [ModifierKeyAppEnum]?

    // MARK: - Perform

    func perform() async throws -> some IntentResult & ReturnsValue<MenuItemEntity> {
        LogShortcuts("AddMenuItemIntent: Creating '\(title)' with action \(actionType.rawValue)")

        // Validate title
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ShortcutsIntentError.invalidParameter(name: "title", reason: "Title cannot be empty")
        }

        // Build the action based on type
        let action: ActionType
        switch actionType {
        case .launchApp:
            // Validate app path
            guard FileManager.default.fileExists(atPath: actionValue) else {
                LogShortcuts("AddMenuItemIntent: App not found at \(actionValue)", level: .error)
                throw ShortcutsIntentError.invalidParameter(
                    name: "actionValue",
                    reason: "Application not found at path: \(actionValue)"
                )
            }
            action = .launchApp(path: actionValue)

        case .runShellCommand:
            guard !actionValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ShortcutsIntentError.invalidParameter(
                    name: "actionValue",
                    reason: "Shell command cannot be empty"
                )
            }
            action = .runShellCommand(command: actionValue)

        case .simulateKeyboardShortcut:
            guard !actionValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ShortcutsIntentError.invalidParameter(
                    name: "actionValue",
                    reason: "Key cannot be empty"
                )
            }
            let domainModifiers = (modifiers ?? []).map { $0.toDomain() }
            action = .simulateKeyboardShortcut(modifiers: domainModifiers, key: actionValue)
        }

        // Create the menu item
        let newItem = MenuItem(
            title: title,
            iconName: iconName,
            action: action
        )

        // Save to configuration
        let configManager = ShortcutsServiceLocator.shared.configManager
        var config = configManager.currentConfiguration
        config.items.append(newItem)

        do {
            try configManager.saveConfiguration(config)
        } catch {
            LogShortcuts("AddMenuItemIntent: Failed to save - \(error)", level: .error)
            throw ShortcutsIntentError.configurationError(reason: error.localizedDescription)
        }

        let entity = MenuItemEntity(from: newItem, at: config.items.count - 1)
        LogShortcuts("AddMenuItemIntent: Success - created '\(title)'")

        return .result(value: entity, dialog: "Added '\(title)' to menu")
    }
}
