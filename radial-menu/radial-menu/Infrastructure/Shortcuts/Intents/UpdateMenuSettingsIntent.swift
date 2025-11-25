//
//  UpdateMenuSettingsIntent.swift
//  radial-menu
//
//  Intent to update menu settings via Shortcuts.
//

import AppIntents
import Foundation

/// Intent to update radial menu appearance and behavior settings.
///
/// Allows users to change menu settings directly from Shortcuts workflows.
/// All parameters are optional - only specified values are changed.
struct UpdateMenuSettingsIntent: AppIntent {
    // MARK: - AppIntent Requirements

    static var title: LocalizedStringResource = "Update Menu Settings"

    static var description = IntentDescription(
        "Change radial menu appearance and behavior settings.",
        categoryName: "Radial Menu"
    )

    static var openAppWhenRun: Bool = false

    // MARK: - Appearance Parameters

    @Parameter(
        title: "Radius",
        description: "Menu radius in points (50-300)"
    )
    var radius: Double?

    @Parameter(
        title: "Center Radius",
        description: "Center hole radius in points (20-100)"
    )
    var centerRadius: Double?

    @Parameter(
        title: "Icon Set",
        description: "Icon set identifier (outline, filled, simple, bootstrap, or custom)"
    )
    var iconSet: String?

    // MARK: - Behavior Parameters

    @Parameter(
        title: "Position Mode",
        description: "Where the menu appears when opened"
    )
    var positionMode: PositionModeAppEnum?

    // MARK: - Perform

    func perform() async throws -> some IntentResult {
        LogShortcuts("UpdateMenuSettingsIntent: Starting")

        let configManager = ShortcutsServiceLocator.shared.configManager
        var config = configManager.currentConfiguration
        var changes: [String] = []

        // Validate and apply radius
        if let radius = radius {
            guard radius >= 50 && radius <= 300 else {
                throw ShortcutsIntentError.invalidParameter(
                    name: "radius",
                    reason: "Must be between 50 and 300"
                )
            }
            config.appearanceSettings.radius = radius
            changes.append("radius=\(Int(radius))")
        }

        // Validate and apply center radius
        if let centerRadius = centerRadius {
            guard centerRadius >= 20 && centerRadius <= 100 else {
                throw ShortcutsIntentError.invalidParameter(
                    name: "centerRadius",
                    reason: "Must be between 20 and 100"
                )
            }
            config.appearanceSettings.centerRadius = centerRadius
            changes.append("centerRadius=\(Int(centerRadius))")
        }

        // Apply icon set
        if let iconSet = iconSet {
            config.appearanceSettings.iconSetIdentifier = iconSet
            changes.append("iconSet=\(iconSet)")
        }

        // Apply position mode
        if let positionMode = positionMode {
            config.behaviorSettings.positionMode = positionMode.toDomain()
            changes.append("positionMode=\(positionMode.rawValue)")
        }

        // If no changes, return early
        guard !changes.isEmpty else {
            LogShortcuts("UpdateMenuSettingsIntent: No changes specified")
            return .result(dialog: "No settings changed")
        }

        // Save configuration
        do {
            try configManager.saveConfiguration(config)
        } catch {
            LogShortcuts("UpdateMenuSettingsIntent: Failed to save - \(error)", level: .error)
            throw ShortcutsIntentError.configurationError(reason: error.localizedDescription)
        }

        let changesDescription = changes.joined(separator: ", ")
        LogShortcuts("UpdateMenuSettingsIntent: Success - \(changesDescription)")
        return .result(dialog: "Updated: \(changesDescription)")
    }
}
