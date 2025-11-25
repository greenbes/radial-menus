//
//  MenuDefinition.swift
//  radial-menu
//
//  Definition of a menu as stored on disk or provided dynamically.
//

import Foundation

/// Definition of a menu as stored on disk or provided dynamically.
///
/// This is the serializable format for named menus and ephemeral menus.
/// Items are required; appearance/behavior use defaults if omitted.
///
/// JSON format:
/// ```json
/// {
///   "version": 1,
///   "name": "development",
///   "description": "Development tools and apps",
///   "items": [...],
///   "appearanceSettings": { ... },  // optional
///   "behaviorSettings": { ... }     // optional
/// }
/// ```
struct MenuDefinition: Codable, Equatable {
    /// Schema version for future migration
    let version: Int

    /// Unique identifier for the menu
    let name: String

    /// Optional human-readable description
    let description: String?

    /// Required menu items
    let items: [MenuItem]

    /// Optional appearance overrides (uses defaults if nil)
    let appearanceSettings: AppearanceSettings?

    /// Optional behavior overrides (uses defaults if nil)
    let behaviorSettings: BehaviorSettings?

    // MARK: - Initialization

    init(
        version: Int = 1,
        name: String,
        description: String? = nil,
        items: [MenuItem],
        appearanceSettings: AppearanceSettings? = nil,
        behaviorSettings: BehaviorSettings? = nil
    ) {
        self.version = version
        self.name = name
        self.description = description
        self.items = items
        self.appearanceSettings = appearanceSettings
        self.behaviorSettings = behaviorSettings
    }
}
