//
//  ExternalRequestHandler.swift
//  radial-menu
//
//  Concrete implementation of external request handling.
//

import Foundation
import AppKit

/// Concrete implementation of external request handling.
///
/// This class provides a unified interface for URL scheme, App Intents, and AppleScript
/// to interact with the radial menu. It wraps the app's infrastructure components and
/// provides async methods that return structured results.
final class ExternalRequestHandler: ExternalRequestHandlerProtocol {
    // MARK: - Dependencies

    private let menuProvider: MenuProviderProtocol
    private let configManager: ConfigurationManagerProtocol
    private let actionExecutor: ActionExecutorProtocol
    private weak var viewModel: RadialMenuViewModel?

    // MARK: - Initialization

    init(
        menuProvider: MenuProviderProtocol,
        configManager: ConfigurationManagerProtocol,
        actionExecutor: ActionExecutorProtocol,
        viewModel: RadialMenuViewModel?
    ) {
        self.menuProvider = menuProvider
        self.configManager = configManager
        self.actionExecutor = actionExecutor
        self.viewModel = viewModel
    }

    // MARK: - ExternalRequestHandlerProtocol

    @MainActor
    func showMenu(
        source: MenuSource,
        position: MenuPosition?,
        returnOnly: Bool
    ) async throws -> MenuSelectionResult? {
        guard let viewModel = viewModel else {
            throw ExternalRequestError.viewModelNotAvailable
        }

        // If menu is already open, return nil
        if viewModel.isOpen {
            LogShortcuts("ExternalRequestHandler: Menu already open, returning nil")
            return nil
        }

        // Resolve menu configuration from source
        let config: MenuConfiguration
        switch menuProvider.resolve(source) {
        case .success(let resolved):
            config = resolved
        case .failure(let error):
            throw ExternalRequestError.menuSourceInvalid(reason: error.localizedDescription)
        }

        // Convert position
        let cgPosition: CGPoint? = position?.toCGPoint()

        // Apply position mode override if specified
        var effectiveConfig = config
        if let pos = position {
            switch pos {
            case .center:
                effectiveConfig.behaviorSettings.positionMode = .center
            case .cursor:
                effectiveConfig.behaviorSettings.positionMode = .atCursor
            case .fixed(let x, let y):
                effectiveConfig.behaviorSettings.positionMode = .fixedPosition
                effectiveConfig.behaviorSettings.fixedPosition = CGPoint(x: x, y: y)
            }
        }

        // Show menu and wait for selection
        return await withCheckedContinuation { continuation in
            viewModel.openMenu(
                with: effectiveConfig,
                at: cgPosition,
                returnOnly: returnOnly
            ) { selectedItem in
                if let item = selectedItem {
                    // Find the position of the item in the config
                    let position = effectiveConfig.items.firstIndex(where: { $0.id == item.id }) ?? 0
                    let itemResult = MenuSelectionResult.MenuItemResult(from: item, position: position)
                    let result = MenuSelectionResult.selected(itemResult)
                    LogShortcuts("ExternalRequestHandler: Selection made - '\(item.title)'")
                    continuation.resume(returning: result)
                } else {
                    LogShortcuts("ExternalRequestHandler: Menu dismissed")
                    continuation.resume(returning: MenuSelectionResult.dismissed())
                }
            }
        }
    }

    func executeItem(_ item: MenuItem) async throws {
        let result = actionExecutor.execute(item.action)
        switch result {
        case .success:
            LogShortcuts("ExternalRequestHandler: Executed '\(item.title)'")
        case .failure(let error):
            throw ExternalRequestError.actionFailed(reason: error.localizedDescription)
        }
    }

    func getNamedMenus() -> [MenuDescriptor] {
        menuProvider.availableMenus
    }

    func getMenuItems() -> [MenuItem] {
        configManager.currentConfiguration.items
    }

    // MARK: - Convenience Methods

    /// Find a menu item by title (case-insensitive).
    func findItem(byTitle title: String) -> MenuItem? {
        configManager.currentConfiguration.items.first {
            $0.title.lowercased() == title.lowercased()
        }
    }

    /// Find a menu item by UUID.
    func findItem(byID id: UUID) -> MenuItem? {
        configManager.currentConfiguration.items.first { $0.id == id }
    }

    /// Execute a menu item by title.
    func executeItem(byTitle title: String) async throws {
        guard let item = findItem(byTitle: title) else {
            throw ExternalRequestError.invalidParameter(
                name: "title",
                reason: "Menu item not found: \(title)"
            )
        }
        try await executeItem(item)
    }

    /// Execute a menu item by UUID.
    func executeItem(byID id: UUID) async throws {
        guard let item = findItem(byID: id) else {
            throw ExternalRequestError.invalidParameter(
                name: "id",
                reason: "Menu item not found: \(id.uuidString)"
            )
        }
        try await executeItem(item)
    }
}
