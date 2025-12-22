//
//  ScriptableNamedMenu.swift
//  radial-menu
//
//  AppleScript-accessible named menu class.
//

import Cocoa

/// AppleScript-accessible representation of a named menu.
///
/// This class wraps a MenuDescriptor and exposes its properties
/// to AppleScript via KVC-compliant properties.
@objc(ScriptableNamedMenu)
class ScriptableNamedMenu: NSObject {
    // MARK: - Properties

    private let descriptor: MenuDescriptor

    // MARK: - Initialization

    init(descriptor: MenuDescriptor) {
        self.descriptor = descriptor
        super.init()
    }

    // MARK: - AppleScript Properties

    /// The menu name.
    @objc var name: String {
        descriptor.name
    }

    /// The menu description.
    @objc var menuDescription: String {
        descriptor.description ?? ""
    }

    /// The number of items in the menu.
    @objc var itemCount: Int {
        descriptor.itemCount
    }

    // MARK: - NSObject Overrides

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let appDescription = NSApplication.shared.classDescription as? NSScriptClassDescription else {
            return nil
        }

        return NSNameSpecifier(
            containerClassDescription: appDescription,
            containerSpecifier: nil,
            key: "scriptableNamedMenus",
            name: name
        )
    }
}
