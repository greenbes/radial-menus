//
//  IconSetDefinition.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/25/25.
//

import Foundation

/// Complete definition of an icon set including all mappings
struct IconSetDefinition: Codable, Equatable {
    /// Identity and metadata
    let descriptor: IconSetDescriptor

    /// Map of semantic icon names to their definitions
    /// Key: semantic name (e.g., "terminal", "safari")
    /// Value: icon definition specifying file or system symbol
    let icons: [String: IconDefinition]

    /// Fallback behavior for icons not explicitly defined
    let fallback: FallbackConfig

    init(
        descriptor: IconSetDescriptor,
        icons: [String: IconDefinition] = [:],
        fallback: FallbackConfig = .default
    ) {
        self.descriptor = descriptor
        self.icons = icons
        self.fallback = fallback
    }
}

// MARK: - IconDefinition

/// Definition of a single icon within an icon set
struct IconDefinition: Codable, Equatable {
    /// Filename relative to icons/ directory (e.g., "terminal.pdf")
    /// Nil if using a system symbol or asset catalog
    let file: String?

    /// SF Symbol name if using a system symbol instead of a file
    /// Takes precedence over file if both are specified
    let systemSymbol: String?

    /// Asset catalog image name (for built-in assets)
    /// Used for special icons bundled in the app's asset catalog
    let assetName: String?

    /// When true, preserves the icon's original colors
    /// Defaults to false (uses application tint)
    let preserveColors: Bool

    init(file: String, preserveColors: Bool = false) {
        self.file = file
        self.systemSymbol = nil
        self.assetName = nil
        self.preserveColors = preserveColors
    }

    init(systemSymbol: String) {
        self.file = nil
        self.systemSymbol = systemSymbol
        self.assetName = nil
        self.preserveColors = false
    }

    init(assetName: String, preserveColors: Bool = false) {
        self.file = nil
        self.systemSymbol = nil
        self.assetName = assetName
        self.preserveColors = preserveColors
    }

    init(file: String?, systemSymbol: String?, assetName: String? = nil, preserveColors: Bool = false) {
        self.file = file
        self.systemSymbol = systemSymbol
        self.assetName = assetName
        self.preserveColors = preserveColors
    }
}

// MARK: - IconDefinition Shorthand Decoding

extension IconDefinition {
    /// Custom decoder to support shorthand notation: "terminal.pdf" instead of { "file": "terminal.pdf" }
    init(from decoder: Decoder) throws {
        // Try shorthand string first
        if let container = try? decoder.singleValueContainer(),
           let filename = try? container.decode(String.self) {
            self.file = filename
            self.systemSymbol = nil
            self.assetName = nil
            self.preserveColors = false
            return
        }

        // Fall back to full object format
        let container = try decoder.container(keyedBy: CodingKeys.self)
        file = try container.decodeIfPresent(String.self, forKey: .file)
        systemSymbol = try container.decodeIfPresent(String.self, forKey: .systemSymbol)
        assetName = try container.decodeIfPresent(String.self, forKey: .assetName)
        preserveColors = try container.decodeIfPresent(Bool.self, forKey: .preserveColors) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case file
        case systemSymbol
        case assetName
        case preserveColors
    }
}

// MARK: - FallbackConfig

/// Configuration for handling icons not explicitly defined in the icon set
struct FallbackConfig: Codable, Equatable {
    /// Strategy for resolving missing icons
    let strategy: FallbackStrategy

    static let `default` = FallbackConfig(strategy: .system)

    init(strategy: FallbackStrategy) {
        self.strategy = strategy
    }
}

/// Strategy for resolving icons not found in an icon set
enum FallbackStrategy: String, Codable, Equatable {
    /// Use SF Symbol with the same name as the semantic icon name
    case system

    /// No fallback - returns a placeholder icon
    case none
}
