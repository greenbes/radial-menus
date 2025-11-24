//
//  AppCoordinator.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation
import AppKit
import SwiftUI

/// Main coordinator that wires all dependencies and manages application lifecycle
class AppCoordinator {
    // MARK: - Infrastructure Components

    private let configManager: ConfigurationManagerProtocol
    private let actionExecutor: ActionExecutorProtocol
    private let hotkeyManager: HotkeyManagerProtocol
    private let controllerInput: ControllerInputProtocol
    private let overlayWindow: OverlayWindowProtocol

    // MARK: - Presentation Components

    private let viewModel: RadialMenuViewModel
    private let menuBarController: MenuBarController

    // MARK: - Controller State Tracking

    private var previousDpadLeft = false
    private var previousDpadRight = false

    // MARK: - Initialization

    init() {
        // Create infrastructure components
        self.configManager = ConfigurationManager()
        self.actionExecutor = ActionExecutor()
        self.hotkeyManager = HotkeyManager()
        self.controllerInput = ControllerInputManager()

        // Calculate initial window size based on configuration radius
        let initialRadius = configManager.currentConfiguration.appearanceSettings.radius
        let initialWindowSize = initialRadius * 2.2
        self.overlayWindow = OverlayWindowController(
            windowSize: CGSize(width: initialWindowSize, height: initialWindowSize)
        )

        // Create view model
        self.viewModel = RadialMenuViewModel(
            configManager: configManager,
            actionExecutor: actionExecutor,
            overlayWindow: overlayWindow
        )

        // Create menu bar controller
        self.menuBarController = MenuBarController(configManager: configManager)
    }

    // MARK: - Lifecycle

    func start() {
        Log("📋 AppCoordinator: Starting...")

        // Setup menu bar
        Log("📋 AppCoordinator: Setting up menu bar...")
        menuBarController.setupMenuBar()
        Log("📋 AppCoordinator: Menu bar setup complete")

        // Register global hotkey (Ctrl + Space)
        Log("📋 AppCoordinator: Registering global hotkey...")
        let success = hotkeyManager.registerHotkey(
            key: HotkeyManager.KeyCode.space,
            modifiers: HotkeyManager.ModifierFlag.control,
            callback: { [weak self] in
                Log("⌨️  Hotkey pressed!")
                guard let self = self else {
                    Log("⚠️  AppCoordinator: self is nil in hotkey callback")
                    return
                }
                Log("⌨️  AppCoordinator: Calling viewModel.toggleMenu()")
                self.viewModel.toggleMenu()
                Log("⌨️  AppCoordinator: viewModel.toggleMenu() returned")
            }
        )

        if !success {
            Log("⚠️  Warning: Failed to register global hotkey")
        } else {
            Log("✅ Global hotkey registered successfully")
        }

        // Start controller input monitoring
        Log("📋 AppCoordinator: Starting controller monitoring...")
        controllerInput.startMonitoring { [weak self] state in
            self?.handleControllerInput(state)
        }
        Log("📋 AppCoordinator: Controller monitoring started")

        // Update overlay window content
        Log("📋 AppCoordinator: Updating overlay window content...")
        updateOverlayWindowContent()
        Log("📋 AppCoordinator: Start complete!")
    }

    func stop() {
        hotkeyManager.unregisterHotkey()
        controllerInput.stopMonitoring()
    }

    // MARK: - Private Methods

    private func updateOverlayWindowContent() {
        let menuView = RadialMenuView(viewModel: viewModel)

        overlayWindow.updateContent(menuView)
    }

    private func handleControllerInput(_ state: ControllerState) {
        // Handle menu button to toggle menu
        if state.menuButtonPressed {
            viewModel.toggleMenu()
            return
        }

        // Handle d-pad for navigation (edge-triggered, like keyboard arrows)
        if state.dpadRight && !previousDpadRight {
            viewModel.handleKeyboardNavigation(clockwise: true)
        }
        if state.dpadLeft && !previousDpadLeft {
            viewModel.handleKeyboardNavigation(clockwise: false)
        }
        previousDpadRight = state.dpadRight
        previousDpadLeft = state.dpadLeft

        // Handle analog stick for selection
        viewModel.handleControllerInput(
            x: state.leftStickX,
            y: state.leftStickY
        )

        // Handle A button for confirmation
        if state.buttonAPressed {
            viewModel.handleConfirm()
        }
    }
}
