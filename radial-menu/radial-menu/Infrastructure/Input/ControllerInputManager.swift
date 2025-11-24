//
//  ControllerInputManager.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation
import GameController

/// Manages game controller input using the GameController framework
class ControllerInputManager: ControllerInputProtocol {
    private var controller: GCController?
    private var callback: StateChangeCallback?
    private var previousState: ControllerState?
    private var pollTimer: Timer?

    deinit {
        stopMonitoring()
    }

    func startMonitoring(callback: @escaping StateChangeCallback) {
        self.callback = callback

        // Enable background event monitoring so controller works when app isn't focused
        // This is required on macOS 11.3+ where the default is false
        GCController.shouldMonitorBackgroundEvents = true

        // Observe controller connections
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerConnected(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDisconnected(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )

        // Check for already connected controllers
        if let firstController = GCController.controllers().first {
            setupController(firstController)
        }

        // Start polling timer for state changes (60Hz)
        // Add to .common modes so it fires even when app doesn't have focus
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.pollControllerState()
        }
        RunLoop.current.add(timer, forMode: .common)
        pollTimer = timer
    }

    func stopMonitoring() {
        NotificationCenter.default.removeObserver(self)
        pollTimer?.invalidate()
        pollTimer = nil
        controller = nil
        callback = nil
    }

    var isControllerConnected: Bool {
        return controller != nil
    }

    var currentState: ControllerState {
        guard let controller = controller,
              let gamepad = controller.extendedGamepad else {
            return ControllerState(
                leftStickX: 0,
                leftStickY: 0,
                buttonAPressed: false,
                menuButtonPressed: false,
                homeButtonPressed: false,
                dpadLeft: false,
                dpadRight: false
            )
        }

        return ControllerState(
            leftStickX: Double(gamepad.leftThumbstick.xAxis.value),
            leftStickY: Double(gamepad.leftThumbstick.yAxis.value),
            buttonAPressed: gamepad.buttonA.isPressed,
            menuButtonPressed: gamepad.buttonMenu.isPressed,
            homeButtonPressed: gamepad.buttonHome?.isPressed ?? false,
            dpadLeft: gamepad.dpad.left.isPressed,
            dpadRight: gamepad.dpad.right.isPressed
        )
    }

    // MARK: - Private Methods

    @objc private func controllerConnected(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        setupController(controller)
    }

    @objc private func controllerDisconnected(_ notification: Notification) {
        self.controller = nil
        previousState = nil
    }

    private func setupController(_ controller: GCController) {
        self.controller = controller

        // Ensure we have extended gamepad support
        guard controller.extendedGamepad != nil else { return }

        // Initial state
        previousState = currentState
    }

    private func pollControllerState() {
        guard controller != nil else { return }

        let newState = currentState

        // Only notify if state has changed
        if previousState != newState {
            callback?(newState)
            previousState = newState
        }
    }
}
