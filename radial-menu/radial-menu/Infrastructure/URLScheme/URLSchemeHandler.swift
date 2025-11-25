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
/// - `radial-menu://hide` - Hide the menu
/// - `radial-menu://toggle` - Toggle menu visibility
/// - `radial-menu://execute?item=<uuid>` - Execute item by UUID
/// - `radial-menu://execute?title=<encoded-title>` - Execute item by title
///
/// Usage from shell:
/// ```bash
/// open "radial-menu://show"
/// open "radial-menu://show?menu=development"
/// open "radial-menu://show?file=/path/to/menu.json"
/// open "radial-menu://execute?title=Terminal"
/// ```
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

        default:
            LogShortcuts("URLSchemeHandler: Unknown command '\(host)'", level: .error)
            return false
        }
    }

    // MARK: - Command Handlers

    @MainActor
    private func handleShow(_ url: URL) -> Bool {
        guard let viewModel = ShortcutsServiceLocator.shared.viewModel else {
            LogShortcuts("URLSchemeHandler: ViewModel not available for show", level: .error)
            return false
        }

        // If menu is already open, don't reopen
        if viewModel.isOpen {
            LogShortcuts("URLSchemeHandler: Menu already open")
            return true
        }

        // Parse menu source from URL parameters
        let source = parseMenuSource(from: url)

        // For default source, just open the menu normally
        if case .default = source {
            viewModel.openMenu()
            LogShortcuts("URLSchemeHandler: Default menu shown")
            return true
        }

        // For other sources, resolve via MenuProvider
        let menuProvider = ShortcutsServiceLocator.shared.menuProvider

        switch menuProvider.resolve(source) {
        case .success(let config):
            viewModel.openMenu(with: config)
            LogShortcuts("URLSchemeHandler: Menu shown from source \(source)")
            return true

        case .failure(let error):
            LogShortcuts("URLSchemeHandler: Failed to resolve menu - \(error.localizedDescription)", level: .error)
            return false
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
}
