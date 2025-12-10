//
//  InternalCommand.swift
//  radial-menu
//
//  Created by Steven Greenberg on 12/09/25.
//

import Foundation

/// Predefined internal commands available for menu items
enum InternalCommand: String, Codable, CaseIterable, Equatable {
    case switchApp
    case finder

    /// Display name shown in the UI
    var displayName: String {
        switch self {
        case .switchApp:
            return "Switch App"
        case .finder:
            return "Finder"
        }
    }

    /// Description of what the command does
    var commandDescription: String {
        switch self {
        case .switchApp:
            return "Open the application switcher"
        case .finder:
            return "Activate Finder and bring windows to front"
        }
    }

    /// SF Symbol icon name for the command
    var iconName: String {
        switch self {
        case .switchApp:
            return "square.stack.3d.up"
        case .finder:
            return "folder"
        }
    }
}
