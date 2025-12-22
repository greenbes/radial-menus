//
//  MenuProvider.swift
//  radial-menu
//
//  Loads and resolves menus from various sources.
//

import Foundation
import Combine

/// Loads and resolves menus from various sources.
///
/// Named menus are stored at:
/// `~/Library/Application Support/com.radial-menu/menus/<name>.json`
final class MenuProvider: MenuProviderProtocol {
    // MARK: - Constants

    private static let menusDirectoryName = "menus"

    // MARK: - Dependencies

    private let configManager: ConfigurationManagerProtocol
    private let fileManager = FileManager.default

    // MARK: - Published State

    private let namedMenusSubject = CurrentValueSubject<[MenuDescriptor], Never>([])

    var namedMenusPublisher: AnyPublisher<[MenuDescriptor], Never> {
        namedMenusSubject.eraseToAnyPublisher()
    }

    var availableMenus: [MenuDescriptor] {
        namedMenusSubject.value
    }

    // MARK: - Private State

    private var cachedDefinitions: [String: MenuDefinition] = [:]
    private var menuFilePaths: [String: URL] = [:]

    // MARK: - Initialization

    init(configManager: ConfigurationManagerProtocol) {
        self.configManager = configManager
        refresh()
    }

    // MARK: - Public Methods

    func resolve(_ source: MenuSource) -> Result<MenuConfiguration, MenuError> {
        switch source {
        case .default:
            return .success(configManager.currentConfiguration)

        case .named(let name):
            return resolveNamed(name)

        case .file(let url):
            return resolveFile(url)

        case .json(let jsonString):
            return resolveJSON(jsonString)
        }
    }

    func refresh() {
        var descriptors: [MenuDescriptor] = []
        var paths: [String: URL] = [:]

        // Discover named menus from the menus directory
        let discoveredMenus = discoverMenus()
        for (url, definition) in discoveredMenus {
            let name = definition.name
            descriptors.append(MenuDescriptor.from(definition, filePath: url))
            paths[name] = url
            cachedDefinitions[name] = definition
        }

        menuFilePaths = paths
        namedMenusSubject.send(descriptors)

        LogConfig("Refreshed menus: \(descriptors.map { $0.name })")
    }

    func hasAppSpecificMenu(bundleIdentifier: String) -> Bool {
        // First check if already discovered/cached
        if menuFilePaths[bundleIdentifier] != nil {
            return true
        }

        // Otherwise check if file exists on disk
        guard let menusDir = menusDirectory() else {
            return false
        }

        let menuURL = menusDir.appendingPathComponent("\(bundleIdentifier).json")
        return fileManager.fileExists(atPath: menuURL.path)
    }

    // MARK: - Private Methods - Resolution

    private func resolveNamed(_ name: String) -> Result<MenuConfiguration, MenuError> {
        LogConfig("MenuProvider.resolveNamed: Resolving '\(name)'")

        // Validate name
        if let error = MenuResolver.validateMenuName(name) {
            LogConfig("MenuProvider.resolveNamed: Name validation failed - \(error)", level: .error)
            return .failure(error)
        }

        // Check cache first
        if let cached = cachedDefinitions[name] {
            LogConfig("MenuProvider.resolveNamed: Found in cache")
            let config = MenuResolver.resolve(
                definition: cached,
                defaults: configManager.currentConfiguration
            )
            return .success(config)
        }

        LogConfig("MenuProvider.resolveNamed: Not in cache, menuFilePaths = \(menuFilePaths.keys.sorted())")

        // Try to load from disk
        guard let url = menuFilePaths[name] else {
            // Menu not in discovered list, try loading by name
            LogConfig("MenuProvider.resolveNamed: Not in menuFilePaths, trying direct load")
            guard let menusDir = menusDirectory() else {
                LogConfig("MenuProvider.resolveNamed: No menus directory", level: .error)
                return .failure(.menuNotFound(name: name))
            }

            let menuURL = menusDir.appendingPathComponent("\(name).json")
            LogConfig("MenuProvider.resolveNamed: Trying to load from \(menuURL.path)")
            return loadAndResolve(from: menuURL, cacheName: name)
        }

        LogConfig("MenuProvider.resolveNamed: Loading from \(url.path)")
        return loadAndResolve(from: url, cacheName: name)
    }

    private func resolveFile(_ url: URL) -> Result<MenuConfiguration, MenuError> {
        // Ephemeral - don't cache
        return loadAndResolve(from: url, cacheName: nil)
    }

    private func resolveJSON(_ jsonString: String) -> Result<MenuConfiguration, MenuError> {
        guard let data = jsonString.data(using: .utf8) else {
            return .failure(.invalidJSON(reason: "Could not convert string to data"))
        }

        // Validate against schema first for better error messages
        let schemaResult = MenuSchemaValidator.validate(data: data)
        if !schemaResult.isValid {
            let errorMessages = schemaResult.errors.map { $0.errorDescription ?? $0.message }
            return .failure(.schemaValidationFailed(errors: errorMessages))
        }

        do {
            let definition = try JSONDecoder().decode(MenuDefinition.self, from: data)

            // Validate
            let validationResult = MenuResolver.validate(definition)
            if case .failure(let error) = validationResult {
                return .failure(error)
            }

            let config = MenuResolver.resolve(
                definition: definition,
                defaults: configManager.currentConfiguration
            )
            return .success(config)
        } catch {
            return .failure(.invalidJSON(reason: error.localizedDescription))
        }
    }

    private func loadAndResolve(from url: URL, cacheName: String?) -> Result<MenuConfiguration, MenuError> {
        LogConfig("MenuProvider.loadAndResolve: Loading from \(url.path)")

        // Load definition
        let loadResult = loadDefinition(from: url)

        switch loadResult {
        case .success(let definition):
            LogConfig("MenuProvider.loadAndResolve: Loaded definition '\(definition.name)' with \(definition.items.count) items")

            // Cache if named
            if let name = cacheName {
                cachedDefinitions[name] = definition
            }

            // Validate
            let validationResult = MenuResolver.validate(definition)
            if case .failure(let error) = validationResult {
                LogConfig("MenuProvider.loadAndResolve: Validation failed - \(error)", level: .error)
                return .failure(error)
            }

            let config = MenuResolver.resolve(
                definition: definition,
                defaults: configManager.currentConfiguration
            )
            LogConfig("MenuProvider.loadAndResolve: Resolved config with \(config.items.count) items")
            return .success(config)

        case .failure(let error):
            LogConfig("MenuProvider.loadAndResolve: Load failed - \(error)", level: .error)
            return .failure(error)
        }
    }

    // MARK: - Private Methods - Loading

    private func loadDefinition(from url: URL) -> Result<MenuDefinition, MenuError> {
        LogConfig("MenuProvider.loadDefinition: Checking \(url.path)")

        guard fileManager.fileExists(atPath: url.path) else {
            LogConfig("MenuProvider.loadDefinition: File not found", level: .error)
            return .failure(.fileNotFound(path: url.path))
        }

        guard let data = try? Data(contentsOf: url) else {
            LogConfig("MenuProvider.loadDefinition: Could not read file", level: .error)
            return .failure(.fileNotReadable(path: url.path))
        }

        LogConfig("MenuProvider.loadDefinition: Read \(data.count) bytes")

        // Validate against schema first for better error messages
        let validationResult = MenuSchemaValidator.validate(data: data)
        if !validationResult.isValid {
            let errorMessages = validationResult.errors.map { $0.errorDescription ?? $0.message }
            LogConfig("MenuProvider.loadDefinition: Schema validation failed - \(errorMessages)", level: .error)
            return .failure(.schemaValidationFailed(errors: errorMessages))
        }

        LogConfig("MenuProvider.loadDefinition: Schema validation passed")

        do {
            let definition = try JSONDecoder().decode(MenuDefinition.self, from: data)
            LogConfig("MenuProvider.loadDefinition: Decoded successfully")
            return .success(definition)
        } catch {
            LogConfig("MenuProvider.loadDefinition: Parse error - \(error)", level: .error)
            return .failure(.parseError(error))
        }
    }

    // MARK: - Private Methods - Discovery

    private func discoverMenus() -> [(URL, MenuDefinition)] {
        guard let menusDir = menusDirectory() else {
            return []
        }

        var results: [(URL, MenuDefinition)] = []

        guard fileManager.fileExists(atPath: menusDir.path) else {
            return []
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: menusDir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            for fileURL in contents {
                // Only process JSON files
                guard fileURL.pathExtension.lowercased() == "json" else {
                    continue
                }

                // Try to load the definition
                if case .success(let definition) = loadDefinition(from: fileURL) {
                    // Validate
                    if case .success = MenuResolver.validate(definition) {
                        results.append((fileURL, definition))
                    } else {
                        LogConfig("Skipping invalid menu at \(fileURL.lastPathComponent)", level: .debug)
                    }
                } else {
                    LogConfig("Failed to load menu from \(fileURL.lastPathComponent)", level: .debug)
                }
            }
        } catch {
            LogError("Failed to enumerate menus directory: \(error)", category: .config)
        }

        return results
    }

    private func menusDirectory() -> URL? {
        do {
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            let bundleID = Bundle.main.bundleIdentifier ?? "com.radial-menu"
            let menusDir = appSupport
                .appendingPathComponent(bundleID)
                .appendingPathComponent(Self.menusDirectoryName)

            // Ensure directory exists
            if !fileManager.fileExists(atPath: menusDir.path) {
                try fileManager.createDirectory(at: menusDir, withIntermediateDirectories: true)
            }

            return menusDir
        } catch {
            LogError("Failed to get menus directory: \(error)", category: .config)
            return nil
        }
    }
}
