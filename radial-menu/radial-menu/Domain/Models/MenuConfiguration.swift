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
struct AppearanceSettings: Codable, Equatable {
    var radius: Double
    var centerRadius: Double
    var sliceHighlightScale: Double
    var animationDuration: Double
    var iconSet: IconSet = .outline
    var backgroundColor: CodableColor = CodableColor(color: .black.opacity(0.3))

    static let `default` = AppearanceSettings(
        radius: 150.0,
        centerRadius: 40.0,
        sliceHighlightScale: 1.1,
        animationDuration: 0.15,
        iconSet: .outline,
        backgroundColor: CodableColor(color: .black.opacity(0.3))
    )
}

/// Wrapper to make Color codable for storage
struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(color: Color) {
        // Extract RGBA components from Color
        let nsColor = NSColor(color)
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
