//
//  ExecuteItemScriptCommand.swift
//  radial-menu
//
//  AppleScript command to execute a menu item.
//

import Cocoa

/// AppleScript command to execute a menu item by title or ID.
///
/// Usage:
/// ```applescript
/// tell application "Radial Menu"
///     execute item "Terminal"
///     execute item "550e8400-e29b-41d4-a716-446655440000"
/// end tell
/// ```
@objc(ExecuteItemScriptCommand)
class ExecuteItemScriptCommand: NSScriptCommand {

    override func performDefaultImplementation() -> Any? {
        LogScripting("ExecuteItemScriptCommand: Executing")

        guard let identifier = directParameter as? String else {
            LogScripting("ExecuteItemScriptCommand: Missing item identifier", level: .error)
            scriptErrorNumber = NSExecutableRuntimeMismatchError
            scriptErrorString = "Missing item title or ID"
            return false
        }

        LogScripting("ExecuteItemScriptCommand: Looking for item '\(identifier)'")

        guard let handler = ShortcutsServiceLocator.shared.externalRequestHandler as? ExternalRequestHandler else {
            LogScripting("ExecuteItemScriptCommand: Handler not available", level: .error)
            scriptErrorNumber = NSExecutableRuntimeMismatchError
            scriptErrorString = "External request handler not available"
            return false
        }

        // Try to find item by UUID first, then by title
        let menuItem: MenuItem?
        if let uuid = UUID(uuidString: identifier) {
            menuItem = handler.findItem(byID: uuid)
        } else {
            menuItem = handler.findItem(byTitle: identifier)
        }

        guard let item = menuItem else {
            LogScripting("ExecuteItemScriptCommand: Item not found - '\(identifier)'", level: .error)
            scriptErrorNumber = NSExecutableRuntimeMismatchError
            scriptErrorString = "Menu item not found: \(identifier)"
            return false
        }

        // Execute the item
        var success = false
        var error: Error?

        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                try await handler.executeItem(item)
                success = true
            } catch let e {
                error = e
            }
            semaphore.signal()
        }

        // Wait for completion (with timeout)
        let waitResult = semaphore.wait(timeout: .now() + 30)
        if waitResult == .timedOut {
            LogScripting("ExecuteItemScriptCommand: Timed out", level: .error)
            scriptErrorNumber = NSExecutableRuntimeMismatchError
            scriptErrorString = "Execution timed out"
            return false
        }

        if let error = error {
            LogScripting("ExecuteItemScriptCommand: Error - \(error.localizedDescription)", level: .error)
            scriptErrorNumber = NSExecutableRuntimeMismatchError
            scriptErrorString = error.localizedDescription
            return false
        }

        LogScripting("ExecuteItemScriptCommand: Executed '\(item.title)'")
        return success
    }
}
