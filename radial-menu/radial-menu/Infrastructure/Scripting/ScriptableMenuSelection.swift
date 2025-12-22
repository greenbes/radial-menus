//
//  ScriptableMenuSelection.swift
//  radial-menu
//
//  AppleScript-accessible menu selection result class.
//

import Cocoa

/// AppleScript-accessible representation of a menu selection result.
///
/// This class wraps a MenuSelectionResult and exposes its properties
/// to AppleScript via KVC-compliant properties.
@objc(ScriptableMenuSelection)
class ScriptableMenuSelection: NSObject {
    // MARK: - Properties

    private let result: MenuSelectionResult?
    private let selectedMenuItem: ScriptableMenuItem?

    // MARK: - Initialization

    /// Creates a selection indicating the menu was dismissed.
    override init() {
        self.result = nil
        self.selectedMenuItem = nil
        super.init()
    }

    /// Creates a selection from a MenuSelectionResult.
    init(result: MenuSelectionResult?, menuItems: [MenuItem] = []) {
        self.result = result

        // If we have a selected item result, find the matching MenuItem
        if let itemResult = result?.selectedItem,
           let uuid = UUID(uuidString: itemResult.id),
           let menuItem = menuItems.first(where: { $0.id == uuid }) {
            self.selectedMenuItem = ScriptableMenuItem(menuItem: menuItem, index: itemResult.position - 1)
        } else {
            self.selectedMenuItem = nil
        }

        super.init()
    }

    // MARK: - AppleScript Properties

    /// Whether the menu was dismissed without selection.
    @objc var wasDismissed: Bool {
        result?.wasDismissed ?? true
    }

    /// The selected menu item, if any.
    @objc var selectedItem: ScriptableMenuItem? {
        selectedMenuItem
    }

    // MARK: - NSObject Overrides

    override var objectSpecifier: NSScriptObjectSpecifier? {
        // Menu selection results are returned directly, not contained in a collection
        nil
    }
}
