//
//  MenuProviderProtocol.swift
//  radial-menu
//
//  Protocol for resolving menu configurations from various sources.
//

import Foundation
import Combine

/// Protocol for resolving menu configurations from various sources.
///
/// Implementations handle loading menus from:
/// - The default user configuration
/// - Named menus stored in the menus directory
/// - External file paths (ephemeral)
/// - Inline JSON strings (ephemeral)
protocol MenuProviderProtocol {
    /// Publisher that emits when available named menus change.
    var namedMenusPublisher: AnyPublisher<[MenuDescriptor], Never> { get }

    /// Currently available named menus.
    var availableMenus: [MenuDescriptor] { get }

    /// Resolves a menu configuration from the given source.
    ///
    /// - Parameter source: The source to load from
    /// - Returns: Success with the configuration, or failure with an error
    func resolve(_ source: MenuSource) -> Result<MenuConfiguration, MenuError>

    /// Refresh the list of available named menus from disk.
    func refresh()
}
