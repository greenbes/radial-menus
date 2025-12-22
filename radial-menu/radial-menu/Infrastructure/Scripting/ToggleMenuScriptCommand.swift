//
//  ToggleMenuScriptCommand.swift
//  radial-menu
//
//  AppleScript command to toggle the radial menu.
//

import Cocoa

/// AppleScript command to toggle the radial menu visibility.
///
/// Usage:
/// ```applescript
/// tell application "Radial Menu"
///     toggle menu
/// end tell
/// ```
@objc(ToggleMenuScriptCommand)
class ToggleMenuScriptCommand: NSScriptCommand {

    override func performDefaultImplementation() -> Any? {
        LogScripting("ToggleMenuScriptCommand: Executing")

        guard let viewModel = ShortcutsServiceLocator.shared.viewModel else {
            LogScripting("ToggleMenuScriptCommand: ViewModel not available", level: .error)
            return nil
        }

        DispatchQueue.main.async {
            if viewModel.isOpen {
                viewModel.closeMenu()
                LogScripting("ToggleMenuScriptCommand: Menu closed")
            } else {
                viewModel.openMenu()
                LogScripting("ToggleMenuScriptCommand: Menu opened")
            }
        }

        return nil
    }
}
