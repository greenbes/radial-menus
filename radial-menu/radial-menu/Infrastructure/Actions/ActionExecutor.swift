//
//  ActionExecutor.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation
import AppKit
import CoreGraphics

/// Concrete implementation of ActionExecutorProtocol
class ActionExecutor: ActionExecutorProtocol {
    func execute(_ action: ActionType) -> ActionResult {
        switch action {
        case .launchApp(let path):
            return executeLaunchApp(path: path)

        case .runShellCommand(let command):
            return executeShellCommand(command: command)

        case .simulateKeyboardShortcut(let modifiers, let key):
            return executeKeyboardShortcut(modifiers: modifiers, key: key)

        case .openTaskSwitcher:
            // This action is intercepted by the ViewModel before reaching the executor
            // Return success as a no-op if it somehow reaches here
            return .success

        case .activateApp(let bundleIdentifier):
            return executeActivateApp(bundleIdentifier: bundleIdentifier)

        case .internalCommand(let command):
            return executeInternalCommand(command)
        }
    }

    func executeAsync(
        _ action: ActionType,
        completion: @escaping (ActionResult) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.execute(action)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    // MARK: - Private Execution Methods

    private func executeLaunchApp(path: String) -> ActionResult {
        let url = URL(fileURLWithPath: path)

        // Check if app exists
        guard FileManager.default.fileExists(atPath: path) else {
            return .failure(ActionExecutionError.applicationNotFound(path: path))
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, error in
            if let error = error {
                LogError("Failed to launch app: \(error)", category: .action)
            }
        }
        return .success
    }

    private func executeActivateApp(bundleIdentifier: String) -> ActionResult {
        // Find the running application by bundle identifier
        guard let app = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            return .failure(ActionExecutionError.applicationNotFound(path: bundleIdentifier))
        }

        // Activate the application (bring to foreground)
        let success = app.activate(options: [.activateIgnoringOtherApps])
        if success {
            return .success
        } else {
            return .failure(ActionExecutionError.applicationNotFound(path: bundleIdentifier))
        }
    }

    private func executeInternalCommand(_ command: InternalCommand) -> ActionResult {
        switch command {
        case .switchApp:
            // This is intercepted by the ViewModel before reaching the executor
            // Return success as a no-op if it somehow reaches here
            return .success

        case .finder:
            return executeFinderCommand()
        }
    }

    private func executeFinderCommand() -> ActionResult {
        let finderBundleID = "com.apple.finder"

        // Find the Finder application
        guard let finder = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == finderBundleID }) else {
            // Finder not running (unlikely), launch it
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: homeDirectory.path)
            return .success
        }

        // Check if Finder has any windows by querying the Accessibility API
        // or use a simpler approach: check window count via CGWindowList
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let finderWindows = windowList.filter { windowInfo in
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int32,
                  let windowLayer = windowInfo[kCGWindowLayer as String] as? Int,
                  windowLayer == 0 else {  // Normal windows are at layer 0
                return false
            }
            return ownerPID == finder.processIdentifier
        }

        if finderWindows.isEmpty {
            // No Finder windows exist, create one at home directory
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: homeDirectory.path)
        } else {
            // Finder windows exist, just activate Finder to bring them to front
            finder.activate(options: [.activateIgnoringOtherApps])
        }

        return .success
    }

    private func executeShellCommand(command: String) -> ActionResult {
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let exitCode = process.terminationStatus
            if exitCode == 0 {
                return .success
            } else {
                return .failure(
                    ActionExecutionError.commandFailed(
                        command: command,
                        exitCode: exitCode
                    )
                )
            }
        } catch {
            return .failure(error)
        }
    }

    private func executeKeyboardShortcut(
        modifiers: [ActionType.KeyModifier],
        key: String
    ) -> ActionResult {
        // Convert modifiers to CGEventFlags
        var flags: CGEventFlags = []
        for modifier in modifiers {
            switch modifier {
            case .command:
                flags.insert(.maskCommand)
            case .option:
                flags.insert(.maskAlternate)
            case .control:
                flags.insert(.maskControl)
            case .shift:
                flags.insert(.maskShift)
            }
        }

        // Try to convert key string to key code
        guard let keyCode = KeyCodeMapper.keyCode(for: key) else {
            return .failure(ActionExecutionError.keyboardSimulationFailed)
        }

        // Create and post key down event
        guard let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: true
        ) else {
            return .failure(ActionExecutionError.keyboardSimulationFailed)
        }

        keyDownEvent.flags = flags
        keyDownEvent.post(tap: .cghidEventTap)

        // Create and post key up event
        guard let keyUpEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: false
        ) else {
            return .failure(ActionExecutionError.keyboardSimulationFailed)
        }

        keyUpEvent.flags = flags
        keyUpEvent.post(tap: .cghidEventTap)

        return .success
    }
}

// MARK: - Key Code Mapper

/// Helper for mapping key strings to macOS key codes
enum KeyCodeMapper {
    static func keyCode(for key: String) -> CGKeyCode? {
        let lowercaseKey = key.lowercased()

        // Map common keys
        let keyMap: [String: CGKeyCode] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
            "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
            "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
            "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
            "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
            "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
            "n": 45, "m": 46, ".": 47, "`": 50,
            "space": 49, "return": 36, "tab": 48, "delete": 51, "escape": 53,
            "left": 123, "right": 124, "down": 125, "up": 126
        ]

        return keyMap[lowercaseKey]
    }
}
