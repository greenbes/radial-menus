//
//  ConfigurationManagerProtocol.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation
import Combine

/// Protocol for managing menu configuration persistence
protocol ConfigurationManagerProtocol {
    /// Publisher that emits when configuration changes
    var configurationPublisher: AnyPublisher<MenuConfiguration, Never> { get }

    /// Load the current configuration
    /// - Returns: Current menu configuration
    func loadConfiguration() -> MenuConfiguration

    /// Save a configuration
    /// - Parameter configuration: Configuration to save
    /// - Throws: Error if save fails
    func saveConfiguration(_ configuration: MenuConfiguration) throws

    /// Reset to default configuration
    func resetToDefault()

    /// Get the current configuration (cached)
    var currentConfiguration: MenuConfiguration { get }
}

/// Errors that can occur during configuration management
enum ConfigurationError: LocalizedError {
    case fileNotFound
    case invalidFormat
    case saveFailed(Error)
    case loadFailed(Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Configuration file not found"
        case .invalidFormat:
            return "Configuration file has invalid format"
        case .saveFailed(let error):
            return "Failed to save configuration: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load configuration: \(error.localizedDescription)"
        }
    }
}
