//
//  IconSet.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/23/25.
//

import Foundation

/// Supported icon sets for menu items
enum IconSet: String, Codable, CaseIterable, Equatable {
    case outline
    case filled
    case simple
    case bootstrap

    var displayName: String {
        switch self {
        case .outline:
            return "Outline"
        case .filled:
            return "Filled"
        case .simple:
            return "Simple"
        case .bootstrap:
            return "Bootstrap"
        }
    }

    struct Icon {
        let name: String
        let isSystem: Bool
    }

    /// Resolve an icon for the given base identifier
    /// Falls back to the original system name if no alternative exists.
    func resolvedIcon(for baseIcon: String) -> Icon {
        switch self {
        case .outline:
            return Icon(name: baseIcon, isSystem: true)
        case .filled:
            // Prefer known filled variants; otherwise keep the base icon
            let name = filledMappings[baseIcon] ?? baseIcon
            return Icon(name: name, isSystem: true)
        case .simple:
            // Use single-tone, high-contrast symbols that avoid hierarchical palettes
            let name = simpleMappings[baseIcon] ?? baseIcon
            return Icon(name: name, isSystem: true)
        case .bootstrap:
            // Fall back to system names to ensure consistent rendering; assets proved unreliable
            let name = bootstrapSystemMappings[baseIcon] ?? baseIcon
            return Icon(name: name, isSystem: true)
        }
    }

    private var filledMappings: [String: String] {
        [
            "terminal": "rectangle.and.pencil.and.ellipsis", // closest filled-style terminal metaphor
            "safari": "safari.fill",
            "camera": "camera.fill",
            "speaker.slash": "speaker.slash.fill",
            "calendar": "calendar.circle.fill",
            "note.text": "note.text",
            "list.bullet.rectangle": "list.bullet.rectangle.fill",
            "folder": "folder.fill"
        ]
    }

    private var simpleMappings: [String: String] {
        [
            "terminal": "rectangle.grid.2x2",
            "safari": "globe",
            "camera": "camera",
            "speaker.slash": "speaker.slash",
            "calendar": "calendar",
            "note.text": "note.text",
            "list.bullet.rectangle": "list.bullet.rectangle",
            "folder": "folder"
        ]
    }

    private var bootstrapSystemMappings: [String: String] {
        [
            "terminal": "terminal",
            "safari": "globe",
            "camera": "camera",
            "speaker.slash": "speaker.slash",
            "calendar": "calendar",
            "note.text": "note.text",
            "list.bullet.rectangle": "list.bullet.rectangle",
            "folder": "folder"
        ]
    }
}
