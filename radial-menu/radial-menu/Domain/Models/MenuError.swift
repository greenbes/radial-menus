//
//  MenuError.swift
//  radial-menu
//
//  Errors that can occur during menu loading and resolution.
//

import Foundation

/// Errors that can occur during menu loading and resolution.
enum MenuError: LocalizedError {
    /// A named menu was not found in the menus directory
    case menuNotFound(name: String)

    /// The specified file does not exist
    case fileNotFound(path: String)

    /// The file exists but could not be read
    case fileNotReadable(path: String)

    /// The JSON content is invalid or malformed
    case invalidJSON(reason: String)

    /// The menu definition has no items
    case emptyItemsList

    /// A general parse error occurred
    case parseError(Error)

    /// The menu name contains invalid characters
    case invalidMenuName(name: String, reason: String)

    /// Schema validation failed with one or more errors
    case schemaValidationFailed(errors: [String])

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .menuNotFound(let name):
            return "Menu '\(name)' not found"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileNotReadable(let path):
            return "Cannot read file: \(path)"
        case .invalidJSON(let reason):
            return "Invalid JSON: \(reason)"
        case .emptyItemsList:
            return "Menu must contain at least one item"
        case .parseError(let error):
            return "Parse error: \(error.localizedDescription)"
        case .invalidMenuName(let name, let reason):
            return "Invalid menu name '\(name)': \(reason)"
        case .schemaValidationFailed(let errors):
            if errors.count == 1 {
                return "Schema validation error: \(errors[0])"
            }
            return "Schema validation errors:\n" + errors.enumerated()
                .map { "  \($0.offset + 1). \($0.element)" }
                .joined(separator: "\n")
        }
    }
}
