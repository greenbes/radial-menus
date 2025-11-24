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

    init(
        id: UUID = UUID(),
        title: String,
        iconName: String,
        action: ActionType
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.action = action
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
