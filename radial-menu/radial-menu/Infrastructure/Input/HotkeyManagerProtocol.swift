//
//  HotkeyManagerProtocol.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation

/// Protocol for managing global hotkeys
protocol HotkeyManagerProtocol {
    /// Callback when hotkey is pressed
    typealias HotkeyCallback = () -> Void

    /// Register a global hotkey
    /// - Parameters:
    ///   - key: The key code
    ///   - modifiers: Modifier flags
    ///   - callback: Callback to invoke when hotkey is pressed
    /// - Returns: True if registration succeeded
    func registerHotkey(
        key: UInt32,
        modifiers: UInt32,
        callback: @escaping HotkeyCallback
    ) -> Bool

    /// Unregister the hotkey
    func unregisterHotkey()

    /// Check if a hotkey is currently registered
    var isRegistered: Bool { get }
}
