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
/// - `radial-menu://show` - Show the menu
/// - `radial-menu://hide` - Hide the menu
/// - `radial-menu://toggle` - Toggle menu visibility
/// - `radial-menu://execute?item=<uuid>` - Execute item by UUID
/// - `radial-menu://execute?title=<encoded-title>` - Execute item by title
///
/// Usage from shell:
/// ```bash
/// open "radial-menu://show"
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
            return handleShow()

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
    private func handleShow() -> Bool {
        guard let viewModel = ShortcutsServiceLocator.shared.viewModel else {
            LogShortcuts("URLSchemeHandler: ViewModel not available for show", level: .error)
            return false
        }

        if !viewModel.isOpen {
            viewModel.openMenu()
        }

        LogShortcuts("URLSchemeHandler: Menu shown")
        return true
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
