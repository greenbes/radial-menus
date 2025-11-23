//
//  MenuConfiguration.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation

/// Configuration for the radial menu
struct MenuConfiguration: Codable, Equatable {
    var items: [MenuItem]
    var appearanceSettings: AppearanceSettings
    var behaviorSettings: BehaviorSettings

    init(
        items: [MenuItem] = [],
        appearanceSettings: AppearanceSettings = .default,
        behaviorSettings: BehaviorSettings = .default
    ) {
        self.items = items
        self.appearanceSettings = appearanceSettings
        self.behaviorSettings = behaviorSettings
    }
}

/// Appearance settings for the radial menu
struct AppearanceSettings: Codable, Equatable {
    var radius: Double
    var centerRadius: Double
    var sliceHighlightScale: Double
    var animationDuration: Double

    static let `default` = AppearanceSettings(
        radius: 150.0,
        centerRadius: 40.0,
        sliceHighlightScale: 1.1,
        animationDuration: 0.15
    )
}

/// Behavior settings for the radial menu
struct BehaviorSettings: Codable, Equatable {
    enum PositionMode: String, Codable {
        case atCursor
        case fixedPosition
    }

    var positionMode: PositionMode
    var fixedPosition: CGPoint?
    var showOnAllSpaces: Bool

    static let `default` = BehaviorSettings(
        positionMode: .atCursor,
        fixedPosition: nil,
        showOnAllSpaces: false
    )
}

extension MenuConfiguration {
    /// Creates a default configuration with sample items
    static func sample() -> MenuConfiguration {
        MenuConfiguration(
            items: [
                MenuItem(
                    title: "Terminal",
                    iconName: "terminal",
                    action: .launchApp(path: "/System/Applications/Utilities/Terminal.app")
                ),
                MenuItem(
                    title: "Safari",
                    iconName: "safari",
                    action: .launchApp(path: "/System/Applications/Safari.app")
                ),
                MenuItem(
                    title: "Screenshot",
                    iconName: "camera",
                    action: .simulateKeyboardShortcut(
                        modifiers: [.command, .shift],
                        key: "4"
                    )
                ),
                MenuItem(
                    title: "Mute",
                    iconName: "speaker.slash",
                    action: .runShellCommand(command: "osascript -e 'set volume output muted true'")
                )
            ]
        )
    }
}
