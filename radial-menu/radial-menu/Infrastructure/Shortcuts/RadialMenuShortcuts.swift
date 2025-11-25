//
//  RadialMenuShortcuts.swift
//  radial-menu
//
//  AppShortcutsProvider for pre-configured shortcuts with Siri phrases.
//

import AppIntents

/// Provides pre-configured shortcuts that appear in the Shortcuts app.
///
/// These shortcuts appear automatically in Shortcuts app under the
/// "Radial Menu" category with predefined Siri phrases.
struct RadialMenuShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Execute Menu Item shortcut
        AppShortcut(
            intent: ExecuteMenuItemIntent(),
            phrases: [
                "Run \(\.$menuItem) in \(.applicationName)",
                "Execute \(\.$menuItem) with \(.applicationName)",
                "Activate \(\.$menuItem) using \(.applicationName)"
            ],
            shortTitle: "Execute Item",
            systemImageName: "play.circle"
        )

        // Toggle Menu shortcut (default action is toggle)
        AppShortcut(
            intent: ToggleMenuIntent(),
            phrases: [
                "Toggle \(.applicationName) menu",
                "Show or hide \(.applicationName)"
            ],
            shortTitle: "Toggle Menu",
            systemImageName: "arrow.2.squarepath"
        )

        // Get Menu Items shortcut
        AppShortcut(
            intent: GetMenuItemsIntent(),
            phrases: [
                "List \(.applicationName) items",
                "Get \(.applicationName) menu items",
                "What items are in \(.applicationName)"
            ],
            shortTitle: "List Items",
            systemImageName: "list.bullet"
        )
    }
}
