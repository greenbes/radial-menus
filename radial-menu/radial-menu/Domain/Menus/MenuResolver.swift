//
//  MenuResolver.swift
//  radial-menu
//
//  Pure functions for resolving menu definitions to runtime configurations.
//

import Foundation

/// Pure functions for resolving menu definitions to runtime configurations.
///
/// This enum contains stateless utility functions that transform `MenuDefinition`
/// (partial, serializable) into `MenuConfiguration` (complete, runtime).
enum MenuResolver {
    // MARK: - Resolution

    /// Resolves a `MenuDefinition` to a full `MenuConfiguration` by applying defaults.
    ///
    /// - Parameters:
    ///   - definition: The menu definition to resolve
    ///   - defaults: The default configuration to use for missing settings
    /// - Returns: A complete `MenuConfiguration` ready for use
    static func resolve(
        definition: MenuDefinition,
        defaults: MenuConfiguration
    ) -> MenuConfiguration {
        return MenuConfiguration(
            items: definition.items,
            appearanceSettings: definition.appearanceSettings ?? defaults.appearanceSettings,
            behaviorSettings: definition.behaviorSettings ?? defaults.behaviorSettings
        )
    }

    // MARK: - Validation

    /// Validates a menu definition.
    ///
    /// - Parameter definition: The definition to validate
    /// - Returns: Success if valid, or a `MenuError` describing the issue
    static func validate(_ definition: MenuDefinition) -> Result<Void, MenuError> {
        // Check for empty items
        guard !definition.items.isEmpty else {
            return .failure(.emptyItemsList)
        }

        // Validate menu name (no path traversal or special characters)
        if let error = validateMenuName(definition.name) {
            return .failure(error)
        }

        return .success(())
    }

    /// Validates a menu name for safety.
    ///
    /// - Parameter name: The menu name to validate
    /// - Returns: A `MenuError` if invalid, nil if valid
    static func validateMenuName(_ name: String) -> MenuError? {
        // Check for empty name
        guard !name.isEmpty else {
            return .invalidMenuName(name: name, reason: "name cannot be empty")
        }

        // Check for path traversal
        if name.contains("..") || name.contains("/") || name.contains("\\") {
            return .invalidMenuName(name: name, reason: "name cannot contain path components")
        }

        // Check for hidden file prefix
        if name.hasPrefix(".") {
            return .invalidMenuName(name: name, reason: "name cannot start with a dot")
        }

        return nil
    }
}
