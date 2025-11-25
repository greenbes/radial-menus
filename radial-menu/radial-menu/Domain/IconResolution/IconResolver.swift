//
//  IconResolver.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/25/25.
//

import Foundation

/// Pure functions for icon resolution
/// All functions are side-effect-free and deterministic
enum IconResolver {

    /// Resolves a semantic icon name using the given icon set definition
    ///
    /// - Parameters:
    ///   - iconName: The semantic icon name (e.g., "terminal", "safari")
    ///   - definition: The icon set definition containing mappings
    ///   - iconSetBaseURL: Base URL of the icon set directory (for resolving file paths)
    /// - Returns: A resolved icon ready for rendering
    static func resolve(
        iconName: String,
        using definition: IconSetDefinition,
        iconSetBaseURL: URL
    ) -> ResolvedIcon {
        // Check if icon is explicitly defined in the set
        if let iconDef = definition.icons[iconName] {
            return resolveDefinition(
                iconDef,
                iconName: iconName,
                iconSetBaseURL: iconSetBaseURL
            )
        }

        // Apply fallback strategy
        return applyFallback(
            for: iconName,
            strategy: definition.fallback.strategy
        )
    }

    /// Resolves an IconDefinition to a ResolvedIcon
    private static func resolveDefinition(
        _ definition: IconDefinition,
        iconName: String,
        iconSetBaseURL: URL
    ) -> ResolvedIcon {
        // System symbol takes precedence if specified
        if let symbolName = definition.systemSymbol {
            return ResolvedIcon(systemSymbol: symbolName)
        }

        // Asset catalog image (built-in assets)
        if let assetName = definition.assetName {
            return ResolvedIcon(
                assetCatalogImage: assetName,
                preserveColors: definition.preserveColors
            )
        }

        // File-based icon (user-defined icon sets)
        if let filename = definition.file {
            let fileURL = iconSetBaseURL
                .appendingPathComponent("icons")
                .appendingPathComponent(filename)
            return ResolvedIcon(
                customIcon: iconName,
                fileURL: fileURL,
                preserveColors: definition.preserveColors
            )
        }

        // Neither file, symbol, nor asset specified - use fallback
        return ResolvedIcon(systemSymbol: iconName)
    }

    /// Applies the fallback strategy for an undefined icon
    private static func applyFallback(
        for iconName: String,
        strategy: FallbackStrategy
    ) -> ResolvedIcon {
        switch strategy {
        case .system:
            // Use SF Symbol with the same semantic name
            return ResolvedIcon(systemSymbol: iconName)
        case .none:
            // Return placeholder
            return ResolvedIcon.placeholder(for: iconName)
        }
    }
}
