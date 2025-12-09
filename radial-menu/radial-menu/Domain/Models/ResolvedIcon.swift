//
//  ResolvedIcon.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/25/25.
//

import AppKit
import Foundation

/// Result of resolving a semantic icon name through an icon set
struct ResolvedIcon: Equatable {
    /// The resolved icon name (SF Symbol name, asset catalog name, or semantic identifier)
    let name: String

    /// True if this is an SF Symbol, false if it's a custom/asset catalog image
    let isSystemSymbol: Bool

    /// URL to the icon file (for custom icons loaded from disk)
    /// Nil for system symbols and asset catalog images
    let fileURL: URL?

    /// True if this is an asset catalog image (built-in non-system icon)
    let isAssetCatalog: Bool

    /// Whether to preserve the icon's original colors
    let preserveColors: Bool

    /// Direct NSImage reference (for runtime-generated icons like app icons)
    /// Nil for system symbols, asset catalog images, and file-based icons
    let nsImage: NSImage?

    // Custom Equatable implementation since NSImage doesn't conform to Equatable
    static func == (lhs: ResolvedIcon, rhs: ResolvedIcon) -> Bool {
        lhs.name == rhs.name &&
        lhs.isSystemSymbol == rhs.isSystemSymbol &&
        lhs.fileURL == rhs.fileURL &&
        lhs.isAssetCatalog == rhs.isAssetCatalog &&
        lhs.preserveColors == rhs.preserveColors &&
        lhs.nsImage === rhs.nsImage  // Reference equality for NSImage
    }

    /// Creates a resolved icon for an SF Symbol
    init(systemSymbol name: String) {
        self.name = name
        self.isSystemSymbol = true
        self.fileURL = nil
        self.isAssetCatalog = false
        self.preserveColors = false
        self.nsImage = nil
    }

    /// Creates a resolved icon for an asset catalog image
    init(assetCatalogImage name: String, preserveColors: Bool = false) {
        self.name = name
        self.isSystemSymbol = false
        self.fileURL = nil
        self.isAssetCatalog = true
        self.preserveColors = preserveColors
        self.nsImage = nil
    }

    /// Creates a resolved icon for a custom asset file
    init(customIcon name: String, fileURL: URL, preserveColors: Bool = false) {
        self.name = name
        self.isSystemSymbol = false
        self.fileURL = fileURL
        self.isAssetCatalog = false
        self.preserveColors = preserveColors
        self.nsImage = nil
    }

    /// Creates a resolved icon from a direct NSImage (for runtime app icons)
    init(nsImage: NSImage, name: String) {
        self.name = name
        self.isSystemSymbol = false
        self.fileURL = nil
        self.isAssetCatalog = false
        self.preserveColors = true  // App icons should preserve their colors
        self.nsImage = nsImage
    }

    /// Creates a placeholder icon for missing icons
    static func placeholder(for name: String) -> ResolvedIcon {
        ResolvedIcon(systemSymbol: "questionmark.circle")
    }
}
