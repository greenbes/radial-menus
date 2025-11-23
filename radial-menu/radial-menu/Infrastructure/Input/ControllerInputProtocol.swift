//
//  ControllerInputProtocol.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation

/// Controller state
struct ControllerState: Equatable {
    let leftStickX: Double
    let leftStickY: Double
    let buttonAPressed: Bool
    let menuButtonPressed: Bool
}

/// Protocol for controller input management
protocol ControllerInputProtocol {
    /// Callback for controller state changes
    typealias StateChangeCallback = (ControllerState) -> Void

    /// Start monitoring for controller input
    /// - Parameter callback: Callback to invoke when controller state changes
    func startMonitoring(callback: @escaping StateChangeCallback)

    /// Stop monitoring controller input
    func stopMonitoring()

    /// Check if a controller is currently connected
    var isControllerConnected: Bool { get }

    /// Get the current controller state
    var currentState: ControllerState { get }
}
