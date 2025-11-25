//
//  ShortcutsServiceLocator.swift
//  radial-menu
//
//  Provides App Intents with access to app dependencies.
//

import Foundation

/// Service locator for Shortcuts intents to access app dependencies.
///
/// App Intents are instantiated by the system, not through our DI container.
/// This singleton provides access to the app's infrastructure components.
///
/// - Note: AppCoordinator registers dependencies on startup; intents access them here.
final class ShortcutsServiceLocator: @unchecked Sendable {
    static let shared = ShortcutsServiceLocator()

    // MARK: - Private State

    private let lock = NSLock()
    private var _configManager: ConfigurationManagerProtocol?
    private var _actionExecutor: ActionExecutorProtocol?
    private weak var _viewModel: RadialMenuViewModel?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Accessors

    /// Configuration manager for accessing menu items.
    /// Creates a new instance if not registered (handles cold-start).
    var configManager: ConfigurationManagerProtocol {
        lock.lock()
        defer { lock.unlock() }

        if let manager = _configManager {
            return manager
        }

        // Fallback: create new instance if not registered
        // This handles case where intent runs before app fully initialized
        LogShortcuts("Creating fallback ConfigurationManager for cold start", level: .info)
        let manager = ConfigurationManager()
        _configManager = manager
        return manager
    }

    /// Action executor for running menu actions.
    /// Creates a new instance if not registered (handles cold-start).
    var actionExecutor: ActionExecutorProtocol {
        lock.lock()
        defer { lock.unlock() }

        if let executor = _actionExecutor {
            return executor
        }

        // Fallback: create new instance if not registered
        LogShortcuts("Creating fallback ActionExecutor for cold start", level: .info)
        let executor = ActionExecutor()
        _actionExecutor = executor
        return executor
    }

    /// ViewModel for menu control (optional - only available when app UI is running).
    var viewModel: RadialMenuViewModel? {
        lock.lock()
        defer { lock.unlock() }
        return _viewModel
    }

    /// Whether the full app UI is available (ViewModel is set).
    var isUIAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _viewModel != nil
    }

    // MARK: - Registration (called by AppCoordinator)

    /// Registers app dependencies. Called by AppCoordinator on startup.
    ///
    /// - Parameters:
    ///   - configManager: The configuration manager instance
    ///   - actionExecutor: The action executor instance
    ///   - viewModel: The radial menu view model
    func register(
        configManager: ConfigurationManagerProtocol,
        actionExecutor: ActionExecutorProtocol,
        viewModel: RadialMenuViewModel
    ) {
        lock.lock()
        defer { lock.unlock() }

        _configManager = configManager
        _actionExecutor = actionExecutor
        _viewModel = viewModel

        LogShortcuts("Dependencies registered with ShortcutsServiceLocator")
    }

    /// Unregisters dependencies. Called by AppCoordinator on shutdown.
    func unregister() {
        lock.lock()
        defer { lock.unlock() }

        _viewModel = nil
        LogShortcuts("UI dependencies unregistered from ShortcutsServiceLocator")
    }
}
