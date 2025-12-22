//
//  ScriptableMenuItem.swift
//  radial-menu
//
//  AppleScript-accessible menu item class.
//

import Cocoa

/// AppleScript-accessible representation of a menu item.
///
/// This class wraps a domain MenuItem and exposes its properties
/// to AppleScript via KVC-compliant properties.
@objc(ScriptableMenuItem)
class ScriptableMenuItem: NSObject {
    // MARK: - Properties

    private let menuItem: MenuItem
    private let index: Int

    // MARK: - Initialization

    init(menuItem: MenuItem, index: Int) {
        self.menuItem = menuItem
        self.index = index
        super.init()
    }

    // MARK: - AppleScript Properties

    /// The unique identifier (UUID string).
    @objc var uniqueID: String {
        menuItem.id.uuidString
    }

    /// The display title.
    @objc var title: String {
        menuItem.title
    }

    /// The icon name.
    @objc var iconName: String {
        menuItem.iconName
    }

    /// The 1-based position in the menu.
    @objc var position: Int {
        index + 1
    }

    /// The action type identifier.
    @objc var actionType: String {
        menuItem.action.typeDescription
    }

    /// The action value (path, command, etc.).
    @objc var actionValue: String {
        switch menuItem.action {
        case .launchApp(let path):
            return path
        case .runShellCommand(let command):
            return command
        case .simulateKeyboardShortcut(let modifiers, let key):
            let modString = modifiers.map { $0.rawValue }.joined(separator: "+")
            return modString.isEmpty ? key : "\(modString)+\(key)"
        case .activateApp(let bundleID):
            return bundleID
        case .internalCommand(let command):
            return command.rawValue
        case .openTaskSwitcher:
            return ""
        }
    }

    // MARK: - NSObject Overrides

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let appDescription = NSApplication.shared.classDescription as? NSScriptClassDescription else {
            return nil
        }

        return NSUniqueIDSpecifier(
            containerClassDescription: appDescription,
            containerSpecifier: nil,
            key: "scriptableMenuItems",
            uniqueID: uniqueID
        )
    }
}
