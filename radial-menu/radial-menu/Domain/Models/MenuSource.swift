//
//  MenuSource.swift
//  radial-menu
//
//  Represents the source from which to load a menu configuration.
//

import Foundation

/// Represents the source from which to load a menu configuration.
///
/// Used by `MenuProvider` to determine how to resolve a menu:
/// - `.default`: Uses the user's configured default menu
/// - `.named(String)`: Loads a named menu from the menus directory
/// - `.file(URL)`: Loads an ephemeral menu from a file path
/// - `.json(String)`: Parses an ephemeral menu from inline JSON
enum MenuSource: Equatable {
    /// The default menu (current user configuration)
    case `default`

    /// A named menu stored in the menus directory
    case named(String)

    /// A menu loaded from an external file path (ephemeral)
    case file(URL)

    /// A menu parsed from inline JSON string (ephemeral)
    case json(String)
}
