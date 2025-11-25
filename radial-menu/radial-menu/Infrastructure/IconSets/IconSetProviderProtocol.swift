//
//  IconSetProviderProtocol.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/25/25.
//

import Foundation
import Combine

/// Protocol for loading and managing icon sets
protocol IconSetProviderProtocol: AnyObject {
    /// Publisher that emits when available icon sets change
    var iconSetsPublisher: AnyPublisher<[IconSetDescriptor], Never> { get }

    /// Get all available icon sets (built-in + user)
    var availableIconSets: [IconSetDescriptor] { get }

    /// Get the default icon set identifier
    var defaultIconSetIdentifier: String { get }

    /// Load the full definition for an icon set
    /// - Parameter identifier: The icon set identifier
    /// - Returns: The icon set definition, or nil if not found
    func definition(for identifier: String) -> IconSetDefinition?

    /// Get the base URL for an icon set (for resolving file paths)
    /// - Parameter identifier: The icon set identifier
    /// - Returns: The base URL, or nil if not found
    func baseURL(for identifier: String) -> URL?

    /// Resolve a semantic icon name to a renderable icon
    /// - Parameters:
    ///   - iconName: The semantic icon name (e.g., "terminal")
    ///   - iconSetIdentifier: The icon set to use
    /// - Returns: The resolved icon ready for rendering
    func resolveIcon(iconName: String, iconSetIdentifier: String) -> ResolvedIcon

    /// Import an icon set from a source directory
    /// - Parameter sourceURL: URL of the directory containing the icon set
    /// - Returns: The descriptor of the imported icon set
    /// - Throws: IconSetError if import fails
    func importIconSet(from sourceURL: URL) throws -> IconSetDescriptor

    /// Delete a user-installed icon set
    /// - Parameter identifier: The icon set identifier to delete
    /// - Throws: IconSetError if deletion fails (e.g., trying to delete built-in set)
    func deleteIconSet(identifier: String) throws

    /// Refresh the list of available icon sets by re-scanning directories
    func refresh()
}

/// Errors for icon set operations
enum IconSetError: LocalizedError {
    case manifestNotFound(URL)
    case invalidManifest(String)
    case missingRequiredField(String)
    case iconSetNotFound(String)
    case identifierAlreadyExists(String)
    case cannotDeleteBuiltIn(String)
    case importFailed(Error)
    case directoryCreationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .manifestNotFound(let url):
            return "Manifest not found at \(url.path)"
        case .invalidManifest(let reason):
            return "Invalid manifest: \(reason)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .iconSetNotFound(let identifier):
            return "Icon set '\(identifier)' not found"
        case .identifierAlreadyExists(let identifier):
            return "Icon set '\(identifier)' already exists"
        case .cannotDeleteBuiltIn(let identifier):
            return "Cannot delete built-in icon set '\(identifier)'"
        case .importFailed(let error):
            return "Import failed: \(error.localizedDescription)"
        case .directoryCreationFailed(let error):
            return "Failed to create directory: \(error.localizedDescription)"
        }
    }
}
