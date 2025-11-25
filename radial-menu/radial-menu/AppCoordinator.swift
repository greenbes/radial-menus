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
    private let accessibilityManager: AccessibilityManager

    // MARK: - Presentation Components

    private let viewModel: RadialMenuViewModel
    private let menuBarController: MenuBarController

    // MARK: - Controller State Tracking

    private var previousDpadLeft = false
    private var previousDpadRight = false
    private var previousHomeButton = false
    private var previousButtonA = false
    private var previousButtonB = false

    // MARK: - Initialization

    init() {
        // Create infrastructure components
        self.configManager = ConfigurationManager()
        self.actionExecutor = ActionExecutor()
        self.hotkeyManager = HotkeyManager()
        self.controllerInput = ControllerInputManager()
        self.accessibilityManager = AccessibilityManager()

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
            overlayWindow: overlayWindow,
            accessibilityManager: accessibilityManager
        )

        // Create menu bar controller
        self.menuBarController = MenuBarController(configManager: configManager)
    }

    // MARK: - Lifecycle

    func start() {
        LogLifecycle("AppCoordinator starting")

        // Start accessibility monitoring
        LogLifecycle("Starting accessibility observation", level: .debug)
        accessibilityManager.startObserving()

        // Setup menu bar
        LogLifecycle("Setting up menu bar", level: .debug)
        menuBarController.setupMenuBar()
        LogLifecycle("Menu bar setup complete", level: .debug)

        // Register global hotkey (Ctrl + Space)
        LogLifecycle("Registering global hotkey", level: .debug)
        let success = hotkeyManager.registerHotkey(
            key: HotkeyManager.KeyCode.space,
            modifiers: HotkeyManager.ModifierFlag.control,
            callback: { [weak self] in
                LogInput("Hotkey pressed", level: .info)
                guard let self = self else {
                    LogError("self is nil in hotkey callback", category: .input)
                    return
                }
                LogInput("Calling toggleMenu()")
                self.viewModel.toggleMenu()
                LogInput("toggleMenu() returned")
            }
        )

        if !success {
            LogError("Failed to register global hotkey", category: .input)
        } else {
            LogInput("Global hotkey registered successfully", level: .info)
        }

        // Start controller input monitoring
        LogLifecycle("Starting controller monitoring", level: .debug)
        controllerInput.startMonitoring { [weak self] state in
            self?.handleControllerInput(state)
        }
        LogLifecycle("Controller monitoring started", level: .debug)

        // Update overlay window content
        LogLifecycle("Updating overlay window content", level: .debug)
        updateOverlayWindowContent()
        LogLifecycle("AppCoordinator start complete")
    }

    func stop() {
        hotkeyManager.unregisterHotkey()
        controllerInput.stopMonitoring()
        accessibilityManager.stopObserving()
    }

    // MARK: - Private Methods

    private func updateOverlayWindowContent() {
        let menuView = RadialMenuView(viewModel: viewModel)

        overlayWindow.updateContent(menuView)
    }

    private func handleControllerInput(_ state: ControllerState) {
        // Handle Home button to toggle menu (edge-triggered)
        if state.homeButtonPressed && !previousHomeButton {
            viewModel.toggleMenu()
        }
        previousHomeButton = state.homeButtonPressed

        // Handle d-pad for navigation (edge-triggered, like keyboard arrows)
        if state.dpadRight && !previousDpadRight {
            viewModel.handleKeyboardNavigation(clockwise: true)
        }
        if state.dpadLeft && !previousDpadLeft {
            viewModel.handleKeyboardNavigation(clockwise: false)
        }
        previousDpadRight = state.dpadRight
        previousDpadLeft = state.dpadLeft

        // Handle left analog stick for selection
        viewModel.handleControllerInput(
            x: state.leftStickX,
            y: state.leftStickY
        )

        // Handle right analog stick for menu repositioning
        viewModel.handleRightStickInput(
            x: state.rightStickX,
            y: state.rightStickY
        )

        // Handle A button for confirmation (edge-triggered)
        // A is bottom button: X on PlayStation, A on Xbox
        if state.buttonAPressed && !previousButtonA {
            viewModel.handleConfirm()
        }
        previousButtonA = state.buttonAPressed

        // Handle B button to cancel/close menu (edge-triggered)
        // B is right button: Circle on PlayStation, B on Xbox
        if state.buttonBPressed && !previousButtonB {
            viewModel.closeMenu()
        }
        previousButtonB = state.buttonBPressed
    }
}
