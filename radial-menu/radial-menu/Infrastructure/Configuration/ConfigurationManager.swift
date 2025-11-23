//
//  ConfigurationManager.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation
import Combine

/// Manages menu configuration persistence using JSON files
class ConfigurationManager: ConfigurationManagerProtocol {
    private let fileManager = FileManager.default
    private let configFileName = "radial-menu-config.json"
    private var cachedConfiguration: MenuConfiguration
    private let configurationSubject = PassthroughSubject<MenuConfiguration, Never>()

    var configurationPublisher: AnyPublisher<MenuConfiguration, Never> {
        configurationSubject.eraseToAnyPublisher()
    }

    var currentConfiguration: MenuConfiguration {
        cachedConfiguration
    }

    init() {
        // Load initial configuration
        self.cachedConfiguration = Self.loadConfigurationFromDisk() ?? .sample()
    }

    func loadConfiguration() -> MenuConfiguration {
        if let loaded = Self.loadConfigurationFromDisk() {
            cachedConfiguration = loaded
            configurationSubject.send(loaded)
            return loaded
        } else {
            // Return default if load fails
            let defaultConfig = MenuConfiguration.sample()
            cachedConfiguration = defaultConfig
            return defaultConfig
        }
    }

    func saveConfiguration(_ configuration: MenuConfiguration) throws {
        let configURL = try Self.configFileURL()

        // Ensure directory exists
        let directory = configURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configuration)

        // Write to file
        try data.write(to: configURL, options: .atomic)

        // Update cache and notify
        cachedConfiguration = configuration
        configurationSubject.send(configuration)
    }

    func resetToDefault() {
        let defaultConfig = MenuConfiguration.sample()
        cachedConfiguration = defaultConfig
        configurationSubject.send(defaultConfig)

        // Remove existing config file
        if let configURL = try? Self.configFileURL() {
            try? fileManager.removeItem(at: configURL)
        }
    }

    // MARK: - Private Helpers

    private static func loadConfigurationFromDisk() -> MenuConfiguration? {
        guard let configURL = try? configFileURL(),
              FileManager.default.fileExists(atPath: configURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            return try decoder.decode(MenuConfiguration.self, from: data)
        } catch {
            print("Failed to load configuration: \(error)")
            return nil
        }
    }

    private static func configFileURL() throws -> URL {
        // Use Application Support directory (follows macOS conventions)
        // This is equivalent to XDG_CONFIG_HOME on macOS
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )

        let bundleID = Bundle.main.bundleIdentifier ?? "com.radial-menu"
        let appDirectory = appSupport.appendingPathComponent(bundleID)

        return appDirectory.appendingPathComponent("radial-menu-config.json")
    }
}
