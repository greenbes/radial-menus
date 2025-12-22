//
//  NSApplicationScripting.swift
//  radial-menu
//
//  Extends NSApplication with AppleScript-accessible properties.
//

import Cocoa

/// Extension providing AppleScript-accessible properties on NSApplication.
///
/// These properties are referenced in RadialMenu.sdef and allow AppleScript
/// to query the application's state and access menu items and named menus.
extension NSApplication {

    // MARK: - AppleScript Properties

    /// Whether the radial menu is currently visible.
    ///
    /// Accessed via AppleScript as:
    /// ```applescript
    /// tell application "Radial Menu"
    ///     menu visible
    /// end tell
    /// ```
    @objc var isMenuVisible: Bool {
        ShortcutsServiceLocator.shared.viewModel?.isOpen ?? false
    }

    /// All menu items in the current configuration.
    ///
    /// Accessed via AppleScript as:
    /// ```applescript
    /// tell application "Radial Menu"
    ///     every menu item
    ///     menu item "Terminal"
    /// end tell
    /// ```
    @objc var scriptableMenuItems: [ScriptableMenuItem] {
        let items = ShortcutsServiceLocator.shared.configManager.currentConfiguration.items
        return items.enumerated().map { index, item in
            ScriptableMenuItem(menuItem: item, index: index)
        }
    }

    /// All saved named menus.
    ///
    /// Accessed via AppleScript as:
    /// ```applescript
    /// tell application "Radial Menu"
    ///     every named menu
    ///     named menu "development"
    /// end tell
    /// ```
    @objc var scriptableNamedMenus: [ScriptableNamedMenu] {
        let menus = ShortcutsServiceLocator.shared.menuProvider.availableMenus
        return menus.map { ScriptableNamedMenu(descriptor: $0) }
    }

    // MARK: - KVC Support for Element Access

    /// Returns the count of scriptable menu items.
    @objc func countOfScriptableMenuItems() -> Int {
        ShortcutsServiceLocator.shared.configManager.currentConfiguration.items.count
    }

    /// Returns a scriptable menu item at the given index.
    @objc func objectInScriptableMenuItemsAtIndex(_ index: Int) -> ScriptableMenuItem? {
        let items = ShortcutsServiceLocator.shared.configManager.currentConfiguration.items
        guard index >= 0 && index < items.count else { return nil }
        return ScriptableMenuItem(menuItem: items[index], index: index)
    }

    /// Returns the count of scriptable named menus.
    @objc func countOfScriptableNamedMenus() -> Int {
        ShortcutsServiceLocator.shared.menuProvider.availableMenus.count
    }

    /// Returns a scriptable named menu at the given index.
    @objc func objectInScriptableNamedMenusAtIndex(_ index: Int) -> ScriptableNamedMenu? {
        let menus = ShortcutsServiceLocator.shared.menuProvider.availableMenus
        guard index >= 0 && index < menus.count else { return nil }
        return ScriptableNamedMenu(descriptor: menus[index])
    }

    /// Returns a scriptable menu item by name (title).
    @objc func valueInScriptableMenuItemsWithName(_ name: String) -> ScriptableMenuItem? {
        let items = ShortcutsServiceLocator.shared.configManager.currentConfiguration.items
        if let index = items.firstIndex(where: { $0.title == name }) {
            return ScriptableMenuItem(menuItem: items[index], index: index)
        }
        return nil
    }

    /// Returns a scriptable menu item by unique ID.
    @objc func valueInScriptableMenuItemsWithUniqueID(_ id: String) -> ScriptableMenuItem? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        let items = ShortcutsServiceLocator.shared.configManager.currentConfiguration.items
        if let index = items.firstIndex(where: { $0.id == uuid }) {
            return ScriptableMenuItem(menuItem: items[index], index: index)
        }
        return nil
    }

    /// Returns a scriptable named menu by name.
    @objc func valueInScriptableNamedMenusWithName(_ name: String) -> ScriptableNamedMenu? {
        let menus = ShortcutsServiceLocator.shared.menuProvider.availableMenus
        if let descriptor = menus.first(where: { $0.name == name }) {
            return ScriptableNamedMenu(descriptor: descriptor)
        }
        return nil
    }
}
