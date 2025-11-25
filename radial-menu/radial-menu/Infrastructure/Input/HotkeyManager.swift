//
//  HotkeyManager.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation
import Carbon

/// Manages global hotkey registration using Carbon Event Manager
class HotkeyManager: HotkeyManagerProtocol {
    private var hotKeyRef: EventHotKeyRef?
    private var callback: HotkeyCallback?
    private var eventHandler: EventHandlerRef?

    deinit {
        unregisterHotkey()
    }

    func registerHotkey(
        key: UInt32,
        modifiers: UInt32,
        callback: @escaping HotkeyCallback
    ) -> Bool {
        LogInput("Registering hotkey: key=\(key), modifiers=\(modifiers)", level: .info)

        // Unregister any existing hotkey first
        unregisterHotkey()

        self.callback = callback

        // Create event spec for hotkey
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Install event handler
        let eventHandlerCallback: EventHandlerUPP = { _, event, userData in
            LogInput("Hotkey event received")

            guard let userData = userData else {
                LogError("No userData in event handler", category: .input)
                return OSStatus(eventNotHandledErr)
            }

            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            LogInput("Calling hotkey callback")
            manager.callback?()
            LogInput("Callback completed")

            return noErr
        }

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            eventHandlerCallback,
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )

        guard status == noErr else {
            LogError("Failed to install event handler, status=\(status)", category: .input)
            return false
        }

        LogInput("Event handler installed successfully", level: .info)

        // Register the hotkey
        let hotKeyID = EventHotKeyID(
            signature: OSType(0x4D454E55), // 'MENU'
            id: UInt32(1)
        )

        var hotKeyRefTemp: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            key,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRefTemp
        )

        guard registerStatus == noErr, let hotKey = hotKeyRefTemp else {
            LogError("Failed to register hotkey, status=\(registerStatus)", category: .input)
            LogError("This likely means Accessibility permissions are not granted", category: .input)
            // Clean up event handler if hotkey registration failed
            if let handler = eventHandler {
                RemoveEventHandler(handler)
                eventHandler = nil
            }
            return false
        }

        hotKeyRef = hotKey
        LogInput("Hotkey registered successfully", level: .info)
        LogInput("Press Ctrl+Space to trigger the menu", level: .info)
        return true
    }

    func unregisterHotkey() {
        if let hotKey = hotKeyRef {
            UnregisterEventHotKey(hotKey)
            hotKeyRef = nil
        }

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }

        callback = nil
    }

    var isRegistered: Bool {
        return hotKeyRef != nil
    }
}

// MARK: - Key Code Constants

extension HotkeyManager {
    /// Common key codes for convenience
    enum KeyCode {
        static let space: UInt32 = 49
        static let escape: UInt32 = 53
        static let returnKey: UInt32 = 36
        static let tab: UInt32 = 48
        static let delete: UInt32 = 51

        static let leftArrow: UInt32 = 123
        static let rightArrow: UInt32 = 124
        static let downArrow: UInt32 = 125
        static let upArrow: UInt32 = 126
    }

    /// Common modifier flags
    enum ModifierFlag {
        static let command: UInt32 = UInt32(cmdKey)
        static let shift: UInt32 = UInt32(shiftKey)
        static let option: UInt32 = UInt32(optionKey)
        static let control: UInt32 = UInt32(controlKey)
    }
}
