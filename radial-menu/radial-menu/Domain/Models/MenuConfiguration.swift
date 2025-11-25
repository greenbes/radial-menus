//
//  MenuConfiguration.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation
import SwiftUI

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
struct AppearanceSettings: Equatable {
    var radius: Double
    var centerRadius: Double
    var sliceHighlightScale: Double
    var animationDuration: Double
    var iconSetIdentifier: String
    var backgroundColor: CodableColor
    var foregroundColor: CodableColor
    var selectedItemColor: CodableColor

    init(
        radius: Double = 150.0,
        centerRadius: Double = 40.0,
        sliceHighlightScale: Double = 1.1,
        animationDuration: Double = 0.15,
        iconSetIdentifier: String = "outline",
        backgroundColor: CodableColor = CodableColor(color: .black.opacity(0.3)),
        foregroundColor: CodableColor = CodableColor(color: .white),
        selectedItemColor: CodableColor = CodableColor(color: .blue.opacity(0.8))
    ) {
        self.radius = radius
        self.centerRadius = centerRadius
        self.sliceHighlightScale = sliceHighlightScale
        self.animationDuration = animationDuration
        self.iconSetIdentifier = iconSetIdentifier
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.selectedItemColor = selectedItemColor
    }

    static let `default` = AppearanceSettings()
}

// MARK: - AppearanceSettings Codable (with migration)

extension AppearanceSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case radius, centerRadius, sliceHighlightScale, animationDuration
        case iconSetIdentifier, iconSet  // Support both new and old keys
        case backgroundColor, foregroundColor, selectedItemColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        radius = try container.decode(Double.self, forKey: .radius)
        centerRadius = try container.decode(Double.self, forKey: .centerRadius)
        sliceHighlightScale = try container.decode(Double.self, forKey: .sliceHighlightScale)
        animationDuration = try container.decode(Double.self, forKey: .animationDuration)

        // Migration: try new key first, then fall back to old IconSet enum
        if let identifier = try? container.decode(String.self, forKey: .iconSetIdentifier) {
            iconSetIdentifier = identifier
        } else if let oldIconSet = try? container.decode(String.self, forKey: .iconSet) {
            // Old format stored IconSet enum as its raw string value
            iconSetIdentifier = oldIconSet
        } else {
            iconSetIdentifier = "outline"
        }

        backgroundColor = try container.decode(CodableColor.self, forKey: .backgroundColor)
        foregroundColor = try container.decode(CodableColor.self, forKey: .foregroundColor)
        selectedItemColor = try container.decode(CodableColor.self, forKey: .selectedItemColor)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(radius, forKey: .radius)
        try container.encode(centerRadius, forKey: .centerRadius)
        try container.encode(sliceHighlightScale, forKey: .sliceHighlightScale)
        try container.encode(animationDuration, forKey: .animationDuration)
        try container.encode(iconSetIdentifier, forKey: .iconSetIdentifier)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(foregroundColor, forKey: .foregroundColor)
        try container.encode(selectedItemColor, forKey: .selectedItemColor)
    }
}

/// Wrapper to make Color codable for storage
struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(color: Color) {
        // Extract RGBA components from Color
        // Convert to RGB color space to ensure getRed works
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.alpha = Double(a)
    }

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

/// Behavior settings for the radial menu
struct BehaviorSettings: Codable, Equatable {
    enum PositionMode: String, Codable {
        case atCursor
        case center
        case fixedPosition

        var displayName: String {
            switch self {
            case .atCursor:
                return "Cursor"
            case .center:
                return "Center"
            case .fixedPosition:
                return "Fixed Position"
            }
        }
    }

    var positionMode: PositionMode
    var fixedPosition: CGPoint?
    var showOnAllSpaces: Bool
    var joystickDeadzone: Double

    static let `default` = BehaviorSettings(
        positionMode: .atCursor,
        fixedPosition: nil,
        showOnAllSpaces: false,
        joystickDeadzone: 0.3
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
                ),
                MenuItem(
                    title: "Calendar",
                    iconName: "calendar",
                    action: .launchApp(path: "/System/Applications/Calendar.app")
                ),
                MenuItem(
                    title: "Notes",
                    iconName: "note.text",
                    action: .launchApp(path: "/System/Applications/Notes.app")
                ),
                MenuItem(
                    title: "Reminders",
                    iconName: "list.bullet.rectangle",
                    action: .launchApp(path: "/System/Applications/Reminders.app")
                ),
                MenuItem(
                    title: "Files",
                    iconName: "folder",
                    action: .launchApp(path: "/System/Applications/Finder.app")
                )
            ]
        )
    }
}
