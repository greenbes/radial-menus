//
//  IconSetProvider.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/25/25.
//

import Foundation
import Combine

/// Manages icon sets from both bundle and user directories
final class IconSetProvider: IconSetProviderProtocol {

    // MARK: - Constants

    private static let iconSetsDirectoryName = "icon-sets"
    private static let manifestFileName = "manifest.json"

    // MARK: - Published State

    private let iconSetsSubject = CurrentValueSubject<[IconSetDescriptor], Never>([])

    var iconSetsPublisher: AnyPublisher<[IconSetDescriptor], Never> {
        iconSetsSubject.eraseToAnyPublisher()
    }

    var availableIconSets: [IconSetDescriptor] {
        iconSetsSubject.value
    }

    var defaultIconSetIdentifier: String {
        "outline"
    }

    // MARK: - Private State

    private let fileManager = FileManager.default
    private var cachedDefinitions: [String: IconSetDefinition] = [:]
    private var iconSetURLs: [String: URL] = [:]

    // MARK: - Initialization

    init() {
        refresh()
    }

    // MARK: - Public Methods

    func definition(for identifier: String) -> IconSetDefinition? {
        // Return cached definition if available
        if let cached = cachedDefinitions[identifier] {
            return cached
        }

        // Try to load from disk
        guard let url = iconSetURLs[identifier] else {
            return nil
        }

        if let definition = loadDefinition(from: url, source: sourceForURL(url)) {
            cachedDefinitions[identifier] = definition
            return definition
        }

        return nil
    }

    func baseURL(for identifier: String) -> URL? {
        iconSetURLs[identifier]
    }

    func resolveIcon(iconName: String, iconSetIdentifier: String) -> ResolvedIcon {
        // Get definition and base URL
        guard let definition = definition(for: iconSetIdentifier),
              let baseURL = baseURL(for: iconSetIdentifier) else {
            // Fall back to system symbol if icon set not found
            LogConfig("Icon set '\(iconSetIdentifier)' not found, falling back to system symbol", level: .debug)
            return ResolvedIcon(systemSymbol: iconName)
        }

        return IconResolver.resolve(
            iconName: iconName,
            using: definition,
            iconSetBaseURL: baseURL
        )
    }

    func importIconSet(from sourceURL: URL) throws -> IconSetDescriptor {
        // Validate the source directory
        let validation = IconSetValidator.validate(directoryURL: sourceURL)
        guard validation.isValid else {
            let errorMessages = validation.errors.map { $0.localizedDescription }.joined(separator: ", ")
            throw IconSetError.invalidManifest(errorMessages)
        }

        // Log warnings
        for warning in validation.warnings {
            LogConfig("Import warning: \(warning.localizedDescription)", level: .debug)
        }

        // Load the definition to get the identifier
        guard let parsedDefinition = loadDefinition(from: sourceURL, source: .user) else {
            throw IconSetError.invalidManifest("Failed to parse manifest")
        }

        let identifier = parsedDefinition.descriptor.identifier

        // Check for existing icon set with same identifier
        if iconSetURLs[identifier] != nil {
            throw IconSetError.identifierAlreadyExists(identifier)
        }

        // Get target directory
        guard let userIconSetsDir = userIconSetsDirectory() else {
            throw IconSetError.directoryCreationFailed(NSError(domain: "IconSetProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not access user icon sets directory"]))
        }

        let targetDir = userIconSetsDir.appendingPathComponent(identifier)

        // Copy the icon set
        do {
            try fileManager.copyItem(at: sourceURL, to: targetDir)
        } catch {
            throw IconSetError.importFailed(error)
        }

        // Refresh to pick up the new set
        refresh()

        // Return the descriptor
        guard let newDefinition = definition(for: identifier) else {
            throw IconSetError.iconSetNotFound(identifier)
        }

        LogConfig("Imported icon set: \(identifier)")
        return newDefinition.descriptor
    }

    func deleteIconSet(identifier: String) throws {
        // Check if it's a user icon set
        guard let url = iconSetURLs[identifier] else {
            throw IconSetError.iconSetNotFound(identifier)
        }

        // Verify it's not a built-in set
        if sourceForURL(url) == .bundle {
            throw IconSetError.cannotDeleteBuiltIn(identifier)
        }

        // Delete the directory
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw IconSetError.importFailed(error)
        }

        // Remove from cache
        cachedDefinitions.removeValue(forKey: identifier)
        iconSetURLs.removeValue(forKey: identifier)

        // Refresh
        refresh()

        LogConfig("Deleted icon set: \(identifier)")
    }

    func refresh() {
        var descriptors: [IconSetDescriptor] = []
        var urls: [String: URL] = [:]

        // Load built-in icon sets from bundle
        let bundleSets = discoverBundleIconSets()
        for (url, definition) in bundleSets {
            let identifier = definition.descriptor.identifier
            descriptors.append(definition.descriptor)
            urls[identifier] = url
            cachedDefinitions[identifier] = definition
        }

        // Load user icon sets
        let userSets = discoverUserIconSets()
        for (url, definition) in userSets {
            let identifier = definition.descriptor.identifier
            // User sets can override built-in sets with same identifier
            if let existingIndex = descriptors.firstIndex(where: { $0.identifier == identifier }) {
                descriptors[existingIndex] = definition.descriptor
            } else {
                descriptors.append(definition.descriptor)
            }
            urls[identifier] = url
            cachedDefinitions[identifier] = definition
        }

        iconSetURLs = urls
        iconSetsSubject.send(descriptors)

        LogConfig("Refreshed icon sets: \(descriptors.map { $0.identifier })")
    }

    // MARK: - Private Methods

    private func discoverBundleIconSets() -> [(URL, IconSetDefinition)] {
        // Built-in icon sets are embedded in code, not loaded from bundle
        // This avoids Xcode resource copying issues and ensures they're always available
        return BuiltInIconSets.all.map { definition in
            // Use a placeholder URL for built-in sets (they don't use file-based icons)
            let placeholderURL = URL(fileURLWithPath: "/builtin/\(definition.descriptor.identifier)")
            return (placeholderURL, definition)
        }
    }

    private func discoverUserIconSets() -> [(URL, IconSetDefinition)] {
        guard let userDir = userIconSetsDirectory() else {
            return []
        }

        return discoverIconSets(in: userDir, source: .user)
    }

    private func discoverIconSets(in directory: URL, source: IconSetSource) -> [(URL, IconSetDefinition)] {
        var results: [(URL, IconSetDefinition)] = []

        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for itemURL in contents {
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    continue
                }

                // Validate
                let validation = IconSetValidator.validate(directoryURL: itemURL)
                if !validation.isValid {
                    LogConfig("Skipping invalid icon set at \(itemURL.lastPathComponent): \(validation.errors.map { $0.localizedDescription })", level: .debug)
                    continue
                }

                // Log warnings
                for warning in validation.warnings {
                    LogConfig("Icon set \(itemURL.lastPathComponent): \(warning.localizedDescription)", level: .debug)
                }

                // Load definition
                if let definition = loadDefinition(from: itemURL, source: source) {
                    results.append((itemURL, definition))
                }
            }
        } catch {
            LogError("Failed to enumerate icon sets in \(directory.path): \(error)", category: .config)
        }

        return results
    }

    private func loadDefinition(from directoryURL: URL, source: IconSetSource) -> IconSetDefinition? {
        let manifestURL = directoryURL.appendingPathComponent(Self.manifestFileName)

        guard let data = try? Data(contentsOf: manifestURL) else {
            return nil
        }

        do {
            let manifest = try JSONDecoder().decode(IconSetManifest.self, from: data)
            return manifest.toDefinition(source: source)
        } catch {
            LogError("Failed to decode manifest at \(manifestURL.path): \(error)", category: .config)
            return nil
        }
    }

    private func userIconSetsDirectory() -> URL? {
        do {
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            let bundleID = Bundle.main.bundleIdentifier ?? "com.radial-menu"
            let iconSetsDir = appSupport
                .appendingPathComponent(bundleID)
                .appendingPathComponent(Self.iconSetsDirectoryName)

            // Ensure directory exists
            if !fileManager.fileExists(atPath: iconSetsDir.path) {
                try fileManager.createDirectory(at: iconSetsDir, withIntermediateDirectories: true)
            }

            return iconSetsDir
        } catch {
            LogError("Failed to get user icon sets directory: \(error)", category: .config)
            return nil
        }
    }

    private func sourceForURL(_ url: URL) -> IconSetSource {
        if let resourcePath = Bundle.main.resourcePath,
           url.path.hasPrefix(resourcePath) {
            return .bundle
        }
        return .user
    }
}

// MARK: - Manifest JSON Structure

/// Internal structure for parsing manifest.json files
private struct IconSetManifest: Codable {
    let version: Int
    let identifier: String
    let name: String
    let description: String?
    let author: AuthorManifest?
    let icons: [String: IconDefinition]
    let fallback: FallbackManifest?

    struct AuthorManifest: Codable {
        let name: String?
        let url: String?
        let email: String?
    }

    struct FallbackManifest: Codable {
        let strategy: String
    }

    func toDefinition(source: IconSetSource) -> IconSetDefinition {
        let descriptor = IconSetDescriptor(
            identifier: identifier,
            name: name,
            description: description,
            author: author.map { IconSetDescriptor.Author(name: $0.name, url: $0.url, email: $0.email) },
            source: source
        )

        let fallbackConfig: FallbackConfig
        if let fallbackManifest = fallback,
           let strategy = FallbackStrategy(rawValue: fallbackManifest.strategy) {
            fallbackConfig = FallbackConfig(strategy: strategy)
        } else {
            fallbackConfig = .default
        }

        return IconSetDefinition(
            descriptor: descriptor,
            icons: icons,
            fallback: fallbackConfig
        )
    }
}
