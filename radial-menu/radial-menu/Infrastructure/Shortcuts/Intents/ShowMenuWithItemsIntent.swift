//
//  ShowMenuWithItemsIntent.swift
//  radial-menu
//
//  Intent to show a menu with custom items passed from Shortcuts.
//

import AppIntents
import Foundation

/// Intent to show a menu with custom items and return the selection.
///
/// This intent accepts a JSON string defining the menu items, allowing
/// Shortcuts to create dynamic menus on the fly.
///
/// JSON format:
/// ```json
/// {
///   "name": "My Menu",
///   "items": [
///     {"title": "Option 1", "iconName": "1.circle", "action": {"runShellCommand": {"command": "echo 1"}}},
///     {"title": "Option 2", "iconName": "2.circle", "action": {"launchApp": {"path": "/Applications/Safari.app"}}}
///   ]
/// }
/// ```
struct ShowMenuWithItemsIntent: AppIntent {
    // MARK: - AppIntent Requirements

    static var title: LocalizedStringResource = "Show Custom Menu"

    static var description = IntentDescription(
        "Show a radial menu with custom items defined in JSON and return the selection.",
        categoryName: "Radial Menu"
    )

    /// Launch app if not running (needed for UI).
    static var openAppWhenRun: Bool = true

    // MARK: - Parameters

    @Parameter(
        title: "Menu Items JSON",
        description: "JSON string defining the menu (use MenuDefinition format)",
        inputOptions: .init(multiline: true)
    )
    var menuItemsJSON: String

    @Parameter(
        title: "Center Title",
        description: "Optional title to display in the center of the menu"
    )
    var centerTitle: String?

    @Parameter(
        title: "Return Only",
        description: "If true, returns the selection without executing the action",
        default: true
    )
    var returnOnly: Bool

    // MARK: - Perform

    func perform() async throws -> some IntentResult & ReturnsValue<MenuSelectionResultEntity> {
        LogShortcuts("ShowMenuWithItemsIntent: Parsing \(menuItemsJSON.count) chars of JSON")

        // Validate JSON is parseable
        guard let data = menuItemsJSON.data(using: .utf8) else {
            throw ShortcutsIntentError.invalidParameter(
                name: "menuItemsJSON",
                reason: "Could not convert to data"
            )
        }

        // Try to decode to verify format
        do {
            _ = try JSONDecoder().decode(MenuDefinition.self, from: data)
        } catch {
            throw ShortcutsIntentError.invalidParameter(
                name: "menuItemsJSON",
                reason: "Invalid JSON format: \(error.localizedDescription)"
            )
        }

        // Wait for app to be ready
        try? await Task.sleep(nanoseconds: 500_000_000)

        let result: MenuSelectionResult?

        do {
            let handler = ShortcutsServiceLocator.shared.externalRequestHandler
            result = try await handler.showMenu(
                source: .json(menuItemsJSON),
                position: nil,
                returnOnly: returnOnly
            )
        } catch {
            LogShortcuts("ShowMenuWithItemsIntent: Error - \(error.localizedDescription)", level: .error)
            throw error
        }

        let entity = MenuSelectionResultEntity(from: result)
        LogShortcuts("ShowMenuWithItemsIntent: Returning result, dismissed=\(entity.wasDismissed)")
        return .result(value: entity)
    }
}
