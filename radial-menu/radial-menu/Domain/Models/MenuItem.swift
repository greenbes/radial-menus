//
//  MenuItem.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation

/// Represents a single item in the radial menu
struct MenuItem: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var iconName: String
    var action: ActionType

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
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.action = action
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
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

    /// Returns the resolved icon (system or asset) for the current icon set
    func resolvedIcon(for iconSet: IconSet) -> IconSet.Icon {
        iconSet.resolvedIcon(for: iconName)
    }
}
