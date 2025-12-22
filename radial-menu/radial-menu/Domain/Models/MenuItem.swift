//
//  MenuItem.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation

/// Represents a single item in the radial menu
struct MenuItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var iconName: String
    var action: ActionType

    // MARK: - Icon Rendering

    /// When true, preserves the icon's original colors instead of applying the application tint.
    /// Defaults to false (uses application tint).
    var preserveColors: Bool

    // MARK: - Accessibility Metadata (optional overrides)

    /// Custom accessibility label. If nil, uses title.
    var accessibilityLabel: String?

    /// Custom accessibility hint. If nil, uses action-based hint.
    var accessibilityHint: String?

    // MARK: - Computed Accessibility Properties

    /// Effective label for VoiceOver (uses title if no override)
    var effectiveAccessibilityLabel: String {
        accessibilityLabel ?? title
    }

    /// Effective hint for VoiceOver (uses action-based hint if no override)
    var effectiveAccessibilityHint: String {
        accessibilityHint ?? action.accessibilityHint
    }

    init(
        id: UUID = UUID(),
        title: String,
        iconName: String,
        action: ActionType,
        preserveColors: Bool = false,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.action = action
        self.preserveColors = preserveColors
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }
}

// MARK: - Codable

extension MenuItem: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, iconName, action
        case preserveColors
        case accessibilityLabel, accessibilityHint
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Auto-generate UUID if not provided (for external menu definitions)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        iconName = try container.decode(String.self, forKey: .iconName)
        action = try container.decode(ActionType.self, forKey: .action)
        // Default to false for existing configurations without this field
        preserveColors = try container.decodeIfPresent(Bool.self, forKey: .preserveColors) ?? false
        accessibilityLabel = try container.decodeIfPresent(String.self, forKey: .accessibilityLabel)
        accessibilityHint = try container.decodeIfPresent(String.self, forKey: .accessibilityHint)
    }
}

extension MenuItem {
    /// Creates a sample menu item for testing and previews
    static func sample() -> MenuItem {
        MenuItem(
            title: "Terminal",
            iconName: "terminal",
            action: .launchApp(path: "/System/Applications/Utilities/Terminal.app")
        )
    }
}
