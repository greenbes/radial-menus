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

        // Show Menu shortcut (waits for selection)
        AppShortcut(
            intent: ShowMenuIntent(),
            phrases: [
                "Show \(.applicationName)",
                "Open \(.applicationName) menu",
                "Pick from \(.applicationName)"
            ],
            shortTitle: "Show Menu",
            systemImageName: "circle.grid.cross"
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

        // Show Named Menu shortcut
        AppShortcut(
            intent: ShowNamedMenuIntent(),
            phrases: [
                "Show \(\.$menu) menu in \(.applicationName)",
                "Open \(\.$menu) with \(.applicationName)"
            ],
            shortTitle: "Show Named Menu",
            systemImageName: "list.bullet.circle"
        )

        // Show Custom Menu shortcut
        AppShortcut(
            intent: ShowMenuWithItemsIntent(),
            phrases: [
                "Show custom menu in \(.applicationName)",
                "Display dynamic menu with \(.applicationName)"
            ],
            shortTitle: "Show Custom Menu",
            systemImageName: "square.grid.3x3"
        )

        // Get Named Menus shortcut
        AppShortcut(
            intent: GetNamedMenusIntent(),
            phrases: [
                "List saved menus in \(.applicationName)",
                "Get named menus from \(.applicationName)",
                "What menus are in \(.applicationName)"
            ],
            shortTitle: "List Menus",
            systemImageName: "folder"
        )
    }
}
