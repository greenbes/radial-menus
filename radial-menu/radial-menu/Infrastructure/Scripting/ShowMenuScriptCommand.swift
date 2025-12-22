//
//  ShowMenuScriptCommand.swift
//  radial-menu
//
//  AppleScript command to show the radial menu.
//

import Cocoa

/// AppleScript command to show the radial menu.
///
/// Usage:
/// ```applescript
/// tell application "Radial Menu"
///     show menu
///     show menu "development"
///     show menu with items "{...}" return only true
/// end tell
/// ```
@objc(ShowMenuScriptCommand)
class ShowMenuScriptCommand: NSScriptCommand {

    override func performDefaultImplementation() -> Any? {
        LogScripting("ShowMenuScriptCommand: Executing")

        // Get parameters
        let menuName = directParameter as? String
        let withItems = evaluatedArguments?["withItems"] as? String
        let returnOnly = evaluatedArguments?["returnOnly"] as? Bool ?? false

        LogScripting("ShowMenuScriptCommand: menuName=\(menuName ?? "nil"), withItems=\(withItems != nil), returnOnly=\(returnOnly)")

        // Determine menu source
        let source: MenuSource
        if let json = withItems {
            source = .json(json)
        } else if let name = menuName {
            source = .named(name)
        } else {
            source = .default
        }

        // Get the external request handler
        let handler = ShortcutsServiceLocator.shared.externalRequestHandler as? ExternalRequestHandler

        // Need to run async code synchronously for AppleScript
        var result: MenuSelectionResult?
        var error: Error?

        let semaphore = DispatchSemaphore(value: 0)

        Task { @MainActor in
            do {
                result = try await handler?.showMenu(
                    source: source,
                    position: nil,
                    returnOnly: returnOnly
                )
            } catch let e {
                error = e
            }
            semaphore.signal()
        }

        // Wait for completion (with timeout)
        let waitResult = semaphore.wait(timeout: .now() + 60)
        if waitResult == .timedOut {
            LogScripting("ShowMenuScriptCommand: Timed out waiting for menu", level: .error)
            scriptErrorNumber = NSExecutableRuntimeMismatchError
            scriptErrorString = "Menu operation timed out"
            return nil
        }

        if let error = error {
            LogScripting("ShowMenuScriptCommand: Error - \(error.localizedDescription)", level: .error)
            scriptErrorNumber = NSExecutableRuntimeMismatchError
            scriptErrorString = error.localizedDescription
            return nil
        }

        // Get current menu items for creating the ScriptableMenuSelection
        let menuItems = ShortcutsServiceLocator.shared.configManager.currentConfiguration.items

        let selection = ScriptableMenuSelection(result: result, menuItems: menuItems)
        LogScripting("ShowMenuScriptCommand: Returning selection, dismissed=\(selection.wasDismissed)")
        return selection
    }
}

// MARK: - Logging Helper

/// Log function for scripting operations.
/// Uses the Shortcuts category since scripting is part of external request handling.
func LogScripting(_ message: String, level: LogLevel = .debug) {
    LogShortcuts(message, level: level)
}
