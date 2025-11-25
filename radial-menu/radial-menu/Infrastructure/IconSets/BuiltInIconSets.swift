//
//  BuiltInIconSets.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/25/25.
//

import Foundation

/// Embedded definitions for built-in icon sets
/// These are defined in code to avoid bundle resource management issues
enum BuiltInIconSets {

    /// All built-in icon set definitions
    static var all: [IconSetDefinition] {
        [outline, filled, simple, bootstrap]
    }

    // MARK: - Outline

    /// Outline icon set - uses SF Symbols directly
    static let outline = IconSetDefinition(
        descriptor: IconSetDescriptor(
            identifier: "outline",
            name: "Outline",
            description: "SF Symbols in outline style - the default icon set",
            source: .bundle
        ),
        icons: [:],  // Empty - falls back to SF Symbol with same name
        fallback: FallbackConfig(strategy: .system)
    )

    // MARK: - Filled

    /// Filled icon set - uses filled SF Symbol variants
    static let filled = IconSetDefinition(
        descriptor: IconSetDescriptor(
            identifier: "filled",
            name: "Filled",
            description: "SF Symbols in filled style",
            source: .bundle
        ),
        icons: [
            "terminal": IconDefinition(systemSymbol: "rectangle.and.pencil.and.ellipsis"),
            "safari": IconDefinition(systemSymbol: "safari.fill"),
            "camera": IconDefinition(systemSymbol: "camera.fill"),
            "speaker.slash": IconDefinition(systemSymbol: "speaker.slash.fill"),
            "calendar": IconDefinition(systemSymbol: "calendar.circle.fill"),
            "note.text": IconDefinition(systemSymbol: "note.text"),
            "list.bullet.rectangle": IconDefinition(systemSymbol: "list.bullet.rectangle.fill"),
            "folder": IconDefinition(systemSymbol: "folder.fill")
        ],
        fallback: FallbackConfig(strategy: .system)
    )

    // MARK: - Simple

    /// Simple icon set - single-tone, high-contrast SF Symbols
    static let simple = IconSetDefinition(
        descriptor: IconSetDescriptor(
            identifier: "simple",
            name: "Simple",
            description: "Single-tone, high-contrast SF Symbols",
            source: .bundle
        ),
        icons: [
            "terminal": IconDefinition(systemSymbol: "rectangle.grid.2x2"),
            "safari": IconDefinition(systemSymbol: "globe"),
            "camera": IconDefinition(systemSymbol: "camera"),
            "speaker.slash": IconDefinition(systemSymbol: "speaker.slash"),
            "calendar": IconDefinition(systemSymbol: "calendar"),
            "note.text": IconDefinition(systemSymbol: "note.text"),
            "list.bullet.rectangle": IconDefinition(systemSymbol: "list.bullet.rectangle"),
            "folder": IconDefinition(systemSymbol: "folder")
        ],
        fallback: FallbackConfig(strategy: .system)
    )

    // MARK: - Bootstrap

    /// Bootstrap icon set - mostly SF Symbols with one special full-color asset
    static let bootstrap = IconSetDefinition(
        descriptor: IconSetDescriptor(
            identifier: "bootstrap",
            name: "Bootstrap",
            description: "Bootstrap-style icons with a special full-color accent",
            source: .bundle
        ),
        icons: [
            "terminal": IconDefinition(systemSymbol: "terminal"),
            "safari": IconDefinition(systemSymbol: "globe"),
            "camera": IconDefinition(systemSymbol: "camera"),
            // Special case: rainbow is an asset catalog image with full color
            // Using assetName to indicate it's from asset catalog
            "speaker.slash": IconDefinition(assetName: "rainbow", preserveColors: true),
            "calendar": IconDefinition(systemSymbol: "calendar"),
            "note.text": IconDefinition(systemSymbol: "note.text"),
            "list.bullet.rectangle": IconDefinition(systemSymbol: "list.bullet.rectangle"),
            "folder": IconDefinition(systemSymbol: "folder")
        ],
        fallback: FallbackConfig(strategy: .system)
    )
}
