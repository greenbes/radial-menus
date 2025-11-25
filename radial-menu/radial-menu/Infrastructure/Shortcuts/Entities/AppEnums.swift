//
//  AppEnums.swift
//  radial-menu
//
//  AppEnum types for Shortcuts parameters.
//

import AppIntents

// MARK: - Menu Action Enum

/// Menu visibility action for ToggleMenuIntent
enum MenuActionAppEnum: String, AppEnum, CaseIterable {
    case show
    case hide
    case toggle

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Menu Action")
    }

    static var caseDisplayRepresentations: [MenuActionAppEnum: DisplayRepresentation] {
        [
            .show: DisplayRepresentation(
                title: "Show Menu",
                subtitle: "Open the radial menu"
            ),
            .hide: DisplayRepresentation(
                title: "Hide Menu",
                subtitle: "Close the radial menu"
            ),
            .toggle: DisplayRepresentation(
                title: "Toggle Menu",
                subtitle: "Show if hidden, hide if shown"
            )
        ]
    }
}

// MARK: - Action Type Enum (for Phase 2 - AddMenuItemIntent)

/// Action type for creating menu items
enum ActionTypeAppEnum: String, AppEnum, CaseIterable {
    case launchApp
    case runShellCommand
    case simulateKeyboardShortcut

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Action Type")
    }

    static var caseDisplayRepresentations: [ActionTypeAppEnum: DisplayRepresentation] {
        [
            .launchApp: DisplayRepresentation(
                title: "Launch App",
                subtitle: "Open an application"
            ),
            .runShellCommand: DisplayRepresentation(
                title: "Run Shell Command",
                subtitle: "Execute a terminal command"
            ),
            .simulateKeyboardShortcut: DisplayRepresentation(
                title: "Keyboard Shortcut",
                subtitle: "Simulate a key combination"
            )
        ]
    }
}

// MARK: - Modifier Key Enum (for Phase 2 - AddMenuItemIntent)

/// Keyboard modifier for keyboard shortcuts
enum ModifierKeyAppEnum: String, AppEnum, CaseIterable {
    case command
    case option
    case control
    case shift

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Modifier Key")
    }

    static var caseDisplayRepresentations: [ModifierKeyAppEnum: DisplayRepresentation] {
        [
            .command: DisplayRepresentation(
                title: "Command",
                subtitle: "⌘ key"
            ),
            .option: DisplayRepresentation(
                title: "Option",
                subtitle: "⌥ key"
            ),
            .control: DisplayRepresentation(
                title: "Control",
                subtitle: "⌃ key"
            ),
            .shift: DisplayRepresentation(
                title: "Shift",
                subtitle: "⇧ key"
            )
        ]
    }

    /// Converts to domain KeyModifier
    func toDomain() -> ActionType.KeyModifier {
        switch self {
        case .command: return .command
        case .option: return .option
        case .control: return .control
        case .shift: return .shift
        }
    }
}

// MARK: - Position Mode Enum (for Phase 2 - UpdateMenuSettingsIntent)

/// Menu position mode for settings
enum PositionModeAppEnum: String, AppEnum, CaseIterable {
    case atCursor
    case center
    case fixedPosition

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Position Mode")
    }

    static var caseDisplayRepresentations: [PositionModeAppEnum: DisplayRepresentation] {
        [
            .atCursor: DisplayRepresentation(
                title: "At Cursor",
                subtitle: "Show menu at mouse position"
            ),
            .center: DisplayRepresentation(
                title: "Center",
                subtitle: "Show menu at screen center"
            ),
            .fixedPosition: DisplayRepresentation(
                title: "Fixed Position",
                subtitle: "Show menu at a fixed location"
            )
        ]
    }

    /// Converts to domain PositionMode
    func toDomain() -> BehaviorSettings.PositionMode {
        switch self {
        case .atCursor: return .atCursor
        case .center: return .center
        case .fixedPosition: return .fixedPosition
        }
    }
}
