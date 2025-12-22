//
//  HideMenuScriptCommand.swift
//  radial-menu
//
//  AppleScript command to hide the radial menu.
//

import Cocoa

/// AppleScript command to hide the radial menu.
///
/// Usage:
/// ```applescript
/// tell application "Radial Menu"
///     hide menu
/// end tell
/// ```
@objc(HideMenuScriptCommand)
class HideMenuScriptCommand: NSScriptCommand {

    override func performDefaultImplementation() -> Any? {
        LogScripting("HideMenuScriptCommand: Executing")

        guard let viewModel = ShortcutsServiceLocator.shared.viewModel else {
            LogScripting("HideMenuScriptCommand: ViewModel not available", level: .error)
            return nil
        }

        DispatchQueue.main.async {
            if viewModel.isOpen {
                viewModel.closeMenu()
                LogScripting("HideMenuScriptCommand: Menu closed")
            } else {
                LogScripting("HideMenuScriptCommand: Menu was not open")
            }
        }

        return nil
    }
}
