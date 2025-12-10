//
//  ActionType.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation

/// Represents the type of action a menu item can perform
enum ActionType: Codable, Equatable {
    case launchApp(path: String)
    case runShellCommand(command: String)
    case simulateKeyboardShortcut(modifiers: [KeyModifier], key: String)
    case openTaskSwitcher
    case activateApp(bundleIdentifier: String)
    case internalCommand(InternalCommand)

    enum KeyModifier: String, Codable {
        case command
        case option
        case control
        case shift
    }
}

extension ActionType {
    var description: String {
        switch self {
        case .launchApp(let path):
            return "Launch app: \(path)"
        case .runShellCommand(let command):
            return "Run: \(command)"
        case .simulateKeyboardShortcut(let modifiers, let key):
            let modString = modifiers.map { $0.rawValue }.joined(separator: "+")
            return "\(modString)+\(key)"
        case .openTaskSwitcher:
            return "Open task switcher"
        case .activateApp(let bundleIdentifier):
            return "Activate app: \(bundleIdentifier)"
        case .internalCommand(let command):
            return command.commandDescription
        }
    }

    /// Accessibility hint describing what the action will do
    var accessibilityHint: String {
        switch self {
        case .launchApp(let path):
            let appName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            return "Double tap to launch \(appName)"
        case .runShellCommand:
            return "Double tap to run command"
        case .simulateKeyboardShortcut(let modifiers, let key):
            let modString = modifiers.map { $0.rawValue.capitalized }.joined(separator: "+")
            if modString.isEmpty {
                return "Double tap to press \(key)"
            }
            return "Double tap to press \(modString)+\(key)"
        case .openTaskSwitcher:
            return "Double tap to open task switcher"
        case .activateApp:
            return "Double tap to switch to this app"
        case .internalCommand(let command):
            return "Double tap to \(command.commandDescription.lowercased())"
        }
    }
}
