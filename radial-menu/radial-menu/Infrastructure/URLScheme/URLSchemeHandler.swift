//
//  URLSchemeHandler.swift
//  radial-menu
//
//  Handles custom URL scheme for external control.
//

import Foundation
import AppKit

/// Handles radial-menu:// URL scheme commands.
///
/// Supported URLs:
/// - `radial-menu://show` - Show the default menu
/// - `radial-menu://show?menu=<name>` - Show a named menu
/// - `radial-menu://show?file=<path>` - Show a menu from a file (ephemeral)
/// - `radial-menu://show?json=<encoded-json>` - Show a menu from inline JSON (ephemeral)
/// - `radial-menu://show?json=base64:<base64>` - Show a menu from base64-encoded JSON
/// - `radial-menu://show?returnTo=<path>` - Write selected item title to file when menu closes
/// - `radial-menu://show?position=cursor` - Show at cursor position (default)
/// - `radial-menu://show?position=center` - Show at screen center
/// - `radial-menu://show?position=100,200` - Show at fixed coordinates (x,y)
/// - `radial-menu://hide` - Hide the menu
/// - `radial-menu://toggle` - Toggle menu visibility
/// - `radial-menu://execute?item=<uuid>` - Execute item by UUID
/// - `radial-menu://execute?title=<encoded-title>` - Execute item by title
/// - `radial-menu://api?returnTo=<path>` - Get API specification
/// - `radial-menu://schema?name=<name>&returnTo=<path>` - Get JSON schema by name
///
/// x-callback-url Support:
/// - `x-success=<url>` - Called with selection details on success (selected=title&id=uuid&position=N)
/// - `x-error=<url>` - Called on error (errorMessage=description)
/// - `x-cancel=<url>` - Called when menu is dismissed without selection
///
/// The `returnTo` parameter can be combined with any show command. When specified,
/// the selected item's title is written to the file path (or empty string if dismissed).
/// The action is NOT executed when returnTo is specified.
///
/// Usage from shell:
/// ```bash
/// open "radial-menu://show"
/// open "radial-menu://show?menu=development"
/// open "radial-menu://show?file=/path/to/menu.json"
/// open "radial-menu://show?returnTo=/tmp/selection.txt"  # Returns selection, no action
/// open "radial-menu://show?position=center"
/// open "radial-menu://show?x-success=myapp://selected&x-cancel=myapp://cancelled"
/// open "radial-menu://execute?title=Terminal"
/// ```
/// Parsed x-callback-url parameters.
struct XCallbackURLParams {
    let successURL: URL?
    let errorURL: URL?
    let cancelURL: URL?

    var hasCallbacks: Bool {
        successURL != nil || errorURL != nil || cancelURL != nil
    }
}

final class URLSchemeHandler {
    // MARK: - Singleton

    static let shared = URLSchemeHandler()
    private init() {}

    // MARK: - URL Scheme Identifier

    static let scheme = "radial-menu"

    // MARK: - Handle URL

    /// Handles incoming URL scheme requests.
    /// - Parameter url: The URL to handle
    /// - Returns: Whether the URL was handled successfully
    @MainActor
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme == Self.scheme else {
            LogShortcuts("URLSchemeHandler: Invalid scheme - \(url.scheme ?? "nil")", level: .error)
            return false
        }

        guard let host = url.host else {
            LogShortcuts("URLSchemeHandler: No command in URL", level: .error)
            return false
        }

        LogShortcuts("URLSchemeHandler: Handling '\(host)'")

        switch host.lowercased() {
        case "show":
            return handleShow(url)

        case "hide":
            return handleHide()

        case "toggle":
            return handleToggle()

        case "execute":
            return handleExecute(url)

        case "api":
            return handleAPI(url)

        case "schema":
            return handleSchema(url)

        default:
            LogShortcuts("URLSchemeHandler: Unknown command '\(host)'", level: .error)
            return false
        }
    }

    // MARK: - Command Handlers

    @MainActor
    private func handleShow(_ url: URL) -> Bool {
        LogShortcuts("URLSchemeHandler.handleShow: URL = \(url.absoluteString)")

        let xCallback = parseXCallbackParams(from: url)
        let returnToPath = parseReturnToPath(from: url)

        LogShortcuts("URLSchemeHandler.handleShow: returnToPath = \(returnToPath ?? "nil")")

        guard let viewModel = ShortcutsServiceLocator.shared.viewModel else {
            LogShortcuts("URLSchemeHandler: ViewModel not available for show", level: .error)
            // Write empty result so scripts don't hang
            if let path = returnToPath {
                writeResult("", to: path)
            }
            callErrorCallback(xCallback, message: "Application not ready")
            return false
        }

        LogShortcuts("URLSchemeHandler.handleShow: ViewModel available, isOpen = \(viewModel.isOpen)")

        // If menu is already open, don't reopen
        if viewModel.isOpen {
            LogShortcuts("URLSchemeHandler: Menu already open")
            return true
        }

        // Parse menu source and position from URL parameters
        let source = parseMenuSource(from: url)
        let position = parsePosition(from: url)

        LogShortcuts("URLSchemeHandler.handleShow: source = \(source), position = \(String(describing: position))")

        // Determine if we should return only (no action execution)
        let returnOnly = returnToPath != nil || xCallback.hasCallbacks
        LogShortcuts("URLSchemeHandler.handleShow: returnOnly = \(returnOnly)")

        // Create completion handler for returnTo, x-callback-url, or both
        let completion: ((MenuItem?) -> Void)? = { [weak self] selectedItem in
            // Write to file if returnTo specified
            if let path = returnToPath {
                self?.writeResult(selectedItem?.title ?? "", to: path)
            }

            // Call x-callback-url if specified
            if let item = selectedItem {
                let items = ShortcutsServiceLocator.shared.configManager.currentConfiguration.items
                let itemPosition = items.firstIndex(where: { $0.id == item.id }).map { $0 + 1 } ?? 0
                self?.callSuccessCallback(xCallback, item: item, position: itemPosition)
            } else {
                self?.callCancelCallback(xCallback)
            }
        }

        // Resolve the menu configuration
        let menuProvider = ShortcutsServiceLocator.shared.menuProvider
        let configResult: Result<MenuConfiguration, MenuError>

        LogShortcuts("URLSchemeHandler.handleShow: Available named menus = \(menuProvider.availableMenus.map { $0.name })")

        if case .default = source {
            LogShortcuts("URLSchemeHandler.handleShow: Using default configuration")
            configResult = .success(ShortcutsServiceLocator.shared.configManager.currentConfiguration)
        } else {
            LogShortcuts("URLSchemeHandler.handleShow: Resolving menu from source...")
            configResult = menuProvider.resolve(source)
        }

        LogShortcuts("URLSchemeHandler.handleShow: Resolution result = \(configResult)")

        switch configResult {
        case .success(var config):
            LogShortcuts("URLSchemeHandler.handleShow: Config resolved with \(config.items.count) items")
            // Apply position override if specified
            if let position = position {
                switch position {
                case .center:
                    config.behaviorSettings.positionMode = BehaviorSettings.PositionMode.center
                case .cursor:
                    config.behaviorSettings.positionMode = BehaviorSettings.PositionMode.atCursor
                case .fixed(let x, let y):
                    config.behaviorSettings.positionMode = BehaviorSettings.PositionMode.fixedPosition
                    config.behaviorSettings.fixedPosition = CGPoint(x: x, y: y)
                }
            }

            viewModel.openMenu(
                with: config,
                at: position?.toCGPoint(),
                returnOnly: returnOnly,
                completion: returnOnly ? completion : nil
            )
            LogShortcuts("URLSchemeHandler: Menu shown, returnOnly=\(returnOnly), position=\(String(describing: position))")
            return true

        case .failure(let error):
            LogShortcuts("URLSchemeHandler: Failed to resolve menu - \(error.localizedDescription)", level: .error)
            // Write empty result to returnTo file so scripts don't hang
            if let path = returnToPath {
                writeResult("", to: path)
            }
            callErrorCallback(xCallback, message: error.localizedDescription)
            return false
        }
    }

    /// Parses the returnTo file path from URL query parameters.
    private func parseReturnToPath(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        return components.queryItems?.first(where: { $0.name == "returnTo" })?.value
    }

    /// Writes the selection result to a file.
    private func writeResult(_ result: String, to path: String) {
        do {
            try result.write(toFile: path, atomically: true, encoding: .utf8)
            LogShortcuts("URLSchemeHandler: Wrote result '\(result)' to \(path)")
        } catch {
            LogShortcuts("URLSchemeHandler: Failed to write result to \(path): \(error)", level: .error)
        }
    }

    /// Parses a MenuSource from URL query parameters.
    ///
    /// Priority: json > file > menu > default
    private func parseMenuSource(from url: URL) -> MenuSource {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .default
        }

        let queryItems = components.queryItems ?? []

        // Check for inline JSON (highest priority)
        if let jsonString = queryItems.first(where: { $0.name == "json" })?.value {
            // Check for base64 prefix
            if jsonString.hasPrefix("base64:") {
                let base64String = String(jsonString.dropFirst(7))
                if let data = Data(base64Encoded: base64String),
                   let decoded = String(data: data, encoding: .utf8) {
                    LogShortcuts("URLSchemeHandler: Using base64-decoded JSON source")
                    return .json(decoded)
                } else {
                    LogShortcuts("URLSchemeHandler: Failed to decode base64 JSON", level: .error)
                    return .default
                }
            }
            LogShortcuts("URLSchemeHandler: Using inline JSON source")
            return .json(jsonString)
        }

        // Check for file path
        if let filePath = queryItems.first(where: { $0.name == "file" })?.value {
            LogShortcuts("URLSchemeHandler: Using file source: \(filePath)")
            return .file(URL(fileURLWithPath: filePath))
        }

        // Check for named menu
        if let menuName = queryItems.first(where: { $0.name == "menu" })?.value {
            LogShortcuts("URLSchemeHandler: Using named menu: \(menuName)")
            return .named(menuName)
        }

        // Default menu
        return .default
    }

    /// Parses position from URL query parameters.
    ///
    /// Supported formats:
    /// - `position=cursor` - At cursor (default)
    /// - `position=center` - At screen center
    /// - `position=100,200` - Fixed coordinates (x,y)
    private func parsePosition(from url: URL) -> MenuPosition? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let positionString = components.queryItems?.first(where: { $0.name == "position" })?.value else {
            return nil
        }

        switch positionString.lowercased() {
        case "cursor":
            return .cursor
        case "center":
            return .center
        default:
            // Try to parse as "x,y" coordinates
            let parts = positionString.split(separator: ",")
            if parts.count == 2,
               let x = Double(parts[0].trimmingCharacters(in: .whitespaces)),
               let y = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                return .fixed(x: x, y: y)
            }
            LogShortcuts("URLSchemeHandler: Invalid position format: \(positionString)", level: .error)
            return nil
        }
    }

    /// Parses x-callback-url parameters from URL.
    private func parseXCallbackParams(from url: URL) -> XCallbackURLParams {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return XCallbackURLParams(successURL: nil, errorURL: nil, cancelURL: nil)
        }

        let queryItems = components.queryItems ?? []

        let successURL = queryItems.first(where: { $0.name == "x-success" })?.value.flatMap { URL(string: $0) }
        let errorURL = queryItems.first(where: { $0.name == "x-error" })?.value.flatMap { URL(string: $0) }
        let cancelURL = queryItems.first(where: { $0.name == "x-cancel" })?.value.flatMap { URL(string: $0) }

        return XCallbackURLParams(successURL: successURL, errorURL: errorURL, cancelURL: cancelURL)
    }

    // MARK: - x-callback-url Handlers

    /// Calls the x-success callback URL with selection details.
    private func callSuccessCallback(_ params: XCallbackURLParams, item: MenuItem, position: Int) {
        guard let baseURL = params.successURL else { return }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []

        queryItems.append(URLQueryItem(name: "selected", value: item.title))
        queryItems.append(URLQueryItem(name: "id", value: item.id.uuidString))
        queryItems.append(URLQueryItem(name: "position", value: String(position)))
        queryItems.append(URLQueryItem(name: "actionType", value: item.action.typeDescription))

        components?.queryItems = queryItems

        if let callbackURL = components?.url {
            LogShortcuts("URLSchemeHandler: Calling x-success callback: \(callbackURL)")
            NSWorkspace.shared.open(callbackURL)
        }
    }

    /// Calls the x-error callback URL with an error message.
    private func callErrorCallback(_ params: XCallbackURLParams, message: String) {
        guard let baseURL = params.errorURL else { return }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []

        queryItems.append(URLQueryItem(name: "errorMessage", value: message))
        components?.queryItems = queryItems

        if let callbackURL = components?.url {
            LogShortcuts("URLSchemeHandler: Calling x-error callback: \(callbackURL)")
            NSWorkspace.shared.open(callbackURL)
        }
    }

    /// Calls the x-cancel callback URL.
    private func callCancelCallback(_ params: XCallbackURLParams) {
        guard let cancelURL = params.cancelURL else { return }

        LogShortcuts("URLSchemeHandler: Calling x-cancel callback: \(cancelURL)")
        NSWorkspace.shared.open(cancelURL)
    }

    @MainActor
    private func handleHide() -> Bool {
        guard let viewModel = ShortcutsServiceLocator.shared.viewModel else {
            LogShortcuts("URLSchemeHandler: ViewModel not available for hide", level: .error)
            return false
        }

        if viewModel.isOpen {
            viewModel.closeMenu()
        }

        LogShortcuts("URLSchemeHandler: Menu hidden")
        return true
    }

    @MainActor
    private func handleToggle() -> Bool {
        guard let viewModel = ShortcutsServiceLocator.shared.viewModel else {
            LogShortcuts("URLSchemeHandler: ViewModel not available for toggle", level: .error)
            return false
        }

        viewModel.toggleMenu()
        LogShortcuts("URLSchemeHandler: Menu toggled")
        return true
    }

    private func handleExecute(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            LogShortcuts("URLSchemeHandler: Failed to parse URL components", level: .error)
            return false
        }

        let queryItems = components.queryItems ?? []

        // Try to find item by UUID first
        if let uuidString = queryItems.first(where: { $0.name == "item" })?.value,
           let uuid = UUID(uuidString: uuidString) {
            return executeItem(withID: uuid)
        }

        // Try to find by title
        if let title = queryItems.first(where: { $0.name == "title" })?.value {
            return executeItem(withTitle: title)
        }

        LogShortcuts("URLSchemeHandler: No item or title parameter provided", level: .error)
        return false
    }

    // MARK: - Item Execution

    private func executeItem(withID uuid: UUID) -> Bool {
        let config = ShortcutsServiceLocator.shared.configManager.currentConfiguration

        guard let item = config.items.first(where: { $0.id == uuid }) else {
            LogShortcuts("URLSchemeHandler: Item not found with ID \(uuid)", level: .error)
            return false
        }

        return executeMenuItem(item)
    }

    private func executeItem(withTitle title: String) -> Bool {
        let config = ShortcutsServiceLocator.shared.configManager.currentConfiguration

        // Case-insensitive search
        guard let item = config.items.first(where: {
            $0.title.lowercased() == title.lowercased()
        }) else {
            LogShortcuts("URLSchemeHandler: Item not found with title '\(title)'", level: .error)
            return false
        }

        return executeMenuItem(item)
    }

    private func executeMenuItem(_ item: MenuItem) -> Bool {
        LogShortcuts("URLSchemeHandler: Executing '\(item.title)'")

        let executor = ShortcutsServiceLocator.shared.actionExecutor
        let result = executor.execute(item.action)

        switch result {
        case .success:
            LogShortcuts("URLSchemeHandler: Successfully executed '\(item.title)'")
            return true

        case .failure(let error):
            LogShortcuts("URLSchemeHandler: Failed to execute '\(item.title)' - \(error)", level: .error)
            return false
        }
    }

    // MARK: - API Discovery

    /// Handles the `api` command - returns API specification.
    private func handleAPI(_ url: URL) -> Bool {
        guard let returnToPath = parseReturnToPath(from: url) else {
            LogShortcuts("URLSchemeHandler: api command requires returnTo parameter", level: .error)
            return false
        }

        let spec = APISpecGenerator.generate()

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(spec)

            guard let json = String(data: data, encoding: .utf8) else {
                LogShortcuts("URLSchemeHandler: Failed to encode API spec as UTF-8", level: .error)
                return false
            }

            try json.write(toFile: returnToPath, atomically: true, encoding: .utf8)
            LogShortcuts("URLSchemeHandler: Wrote API spec to \(returnToPath)")
            return true

        } catch {
            LogShortcuts("URLSchemeHandler: Failed to write API spec - \(error)", level: .error)
            return false
        }
    }

    /// Handles the `schema` command - returns a specific JSON schema.
    private func handleSchema(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            LogShortcuts("URLSchemeHandler: Failed to parse schema URL", level: .error)
            return false
        }

        let queryItems = components.queryItems ?? []

        guard let schemaName = queryItems.first(where: { $0.name == "name" })?.value else {
            LogShortcuts("URLSchemeHandler: schema command requires name parameter", level: .error)
            return false
        }

        guard let returnToPath = parseReturnToPath(from: url) else {
            LogShortcuts("URLSchemeHandler: schema command requires returnTo parameter", level: .error)
            return false
        }

        // Map schema names to file paths
        let validSchemas = ["menu-configuration", "menu-selection-result", "api-spec"]
        guard validSchemas.contains(schemaName) else {
            LogShortcuts("URLSchemeHandler: Unknown schema '\(schemaName)'", level: .error)
            return false
        }

        // Try to load schema from bundle
        if let schemaData = loadSchema(named: schemaName) {
            do {
                try schemaData.write(toFile: returnToPath, atomically: true, encoding: .utf8)
                LogShortcuts("URLSchemeHandler: Wrote schema '\(schemaName)' to \(returnToPath)")
                return true
            } catch {
                LogShortcuts("URLSchemeHandler: Failed to write schema - \(error)", level: .error)
                return false
            }
        }

        LogShortcuts("URLSchemeHandler: Schema '\(schemaName)' not found", level: .error)
        return false
    }

    /// Loads a schema file from the bundle or resources directory.
    private func loadSchema(named name: String) -> String? {
        let filename = "\(name).schema"

        // Try bundle resources (in schemas subdirectory)
        if let url = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "schemas"),
           let data = try? Data(contentsOf: url),
           let content = String(data: data, encoding: .utf8) {
            LogShortcuts("URLSchemeHandler: Loaded schema '\(name)' from bundle subdirectory")
            return content
        }

        // Try without subdirectory (flat Resources)
        if let url = Bundle.main.url(forResource: filename, withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let content = String(data: data, encoding: .utf8) {
            LogShortcuts("URLSchemeHandler: Loaded schema '\(name)' from bundle root")
            return content
        }

        // Try Resources/schemas directory relative to executable
        if let executableURL = Bundle.main.executableURL {
            let schemasURL = executableURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources")
                .appendingPathComponent("schemas")
                .appendingPathComponent("\(name).schema.json")

            if let data = try? Data(contentsOf: schemasURL),
               let content = String(data: data, encoding: .utf8) {
                LogShortcuts("URLSchemeHandler: Loaded schema '\(name)' from Resources/schemas")
                return content
            }
        }

        LogShortcuts("URLSchemeHandler: Schema '\(name)' not found in bundle", level: .error)
        return nil
    }
}
