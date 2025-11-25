//
//  MenuBarController.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import AppKit
import SwiftUI
import ObjectiveC

/// Manages the menu bar status item and preferences window
class MenuBarController {
    private var statusItem: NSStatusItem?
    private var preferencesWindow: NSWindow?
    private let configManager: ConfigurationManagerProtocol
    private let iconSetProvider: IconSetProviderProtocol

    init(configManager: ConfigurationManagerProtocol, iconSetProvider: IconSetProviderProtocol) {
        self.configManager = configManager
        self.iconSetProvider = iconSetProvider
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "circle.grid.cross",
                accessibilityDescription: "Radial Menu"
            )
        }

        setupMenu()
    }

    func openPreferences() {
        if let existingWindow = preferencesWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let preferencesView = PreferencesView(
            configuration: configManager.currentConfiguration,
            iconSetProvider: iconSetProvider,
            onResetToDefault: { [weak self] in
                self?.configManager.resetToDefault()
            },
            onUpdateIconSetIdentifier: { [weak self] newIdentifier in
                guard let self else { return }
                var updated = configManager.currentConfiguration
                updated.appearanceSettings.iconSetIdentifier = newIdentifier
                do {
                    try configManager.saveConfiguration(updated)
                } catch {
                    LogError("Failed to save icon set: \(error)", category: .config)
                }
            },
            onUpdateBackgroundColor: { [weak self] newColor in
                guard let self else { return }
                var updated = configManager.currentConfiguration
                updated.appearanceSettings.backgroundColor = newColor
                do {
                    try configManager.saveConfiguration(updated)
                } catch {
                    LogError("Failed to save background color: \(error)", category: .config)
                }
            },
            onUpdateForegroundColor: { [weak self] newColor in
                guard let self else { return }
                var updated = configManager.currentConfiguration
                updated.appearanceSettings.foregroundColor = newColor
                do {
                    try configManager.saveConfiguration(updated)
                } catch {
                    LogError("Failed to save foreground color: \(error)", category: .config)
                }
            },
            onUpdateSelectedItemColor: { [weak self] newColor in
                guard let self else { return }
                var updated = configManager.currentConfiguration
                updated.appearanceSettings.selectedItemColor = newColor
                do {
                    try configManager.saveConfiguration(updated)
                } catch {
                    LogError("Failed to save selected item color: \(error)", category: .config)
                }
            },
            onUpdatePositionMode: { [weak self] newMode in
                guard let self else { return }
                var updated = configManager.currentConfiguration
                updated.behaviorSettings.positionMode = newMode
                do {
                    try configManager.saveConfiguration(updated)
                } catch {
                    LogError("Failed to save position mode: \(error)", category: .config)
                }
            },
            onAddItem: { [weak self] newItem in
                guard let self else { return }
                var updated = configManager.currentConfiguration
                updated.items.append(newItem)
                do {
                    try configManager.saveConfiguration(updated)
                } catch {
                    LogError("Failed to add menu item: \(error)", category: .config)
                }
            },
            onRemoveItem: { [weak self] itemId in
                guard let self else { return }
                var updated = configManager.currentConfiguration
                updated.items.removeAll { $0.id == itemId }
                do {
                    try configManager.saveConfiguration(updated)
                } catch {
                    LogError("Failed to remove menu item: \(error)", category: .config)
                }
            },
            onUpdateRadius: { [weak self] newRadius in
                guard let self else { return }
                var updated = configManager.currentConfiguration
                updated.appearanceSettings.radius = newRadius
                do {
                    try configManager.saveConfiguration(updated)
                } catch {
                    LogError("Failed to save radius: \(error)", category: .config)
                }
            },
            onUpdateCenterRadius: { [weak self] newCenterRadius in
                guard let self else { return }
                var updated = configManager.currentConfiguration
                updated.appearanceSettings.centerRadius = newCenterRadius
                do {
                    try configManager.saveConfiguration(updated)
                } catch {
                    LogError("Failed to save center radius: \(error)", category: .config)
                }
            },
            onUpdateJoystickDeadzone: { [weak self] newDeadzone in
                guard let self else { return }
                var updated = configManager.currentConfiguration
                updated.behaviorSettings.joystickDeadzone = newDeadzone
                do {
                    try configManager.saveConfiguration(updated)
                } catch {
                    LogError("Failed to save joystick deadzone: \(error)", category: .config)
                }
            }
        )

        let hostingView = NSHostingView(rootView: preferencesView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Radial Menu Preferences"
        window.contentView = hostingView
        window.center()
        window.setFrameAutosaveName("PreferencesWindow")
        window.isReleasedWhenClosed = false

        // Handle window close
        let delegate = PreferencesWindowDelegate { [weak self] in
            self?.preferencesWindow = nil
        }
        window.delegate = delegate

        // Store delegate to prevent deallocation
        objc_setAssociatedObject(window, "windowDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)

        preferencesWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Private Methods

    private func setupMenu() {
        let menu = NSMenu()

        // About item with build ID
        let aboutItem = NSMenuItem(
            title: "About Radial Menu",
            action: #selector(aboutMenuItemClicked),
            keyEquivalent: ""
        )
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Preferences...",
            action: #selector(preferencesMenuItemClicked),
            keyEquivalent: ","
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Quit Radial Menu",
            action: #selector(quitMenuItemClicked),
            keyEquivalent: "q"
        ))

        // Set targets
        menu.items.forEach { $0.target = self }

        statusItem?.menu = menu
    }

    @objc private func aboutMenuItemClicked() {
        let alert = NSAlert()
        alert.messageText = "Radial Menu"
        alert.informativeText = """
            A configurable radial overlay menu for macOS.

            Build: \(BuildInfo.buildID)
            Branch: \(BuildInfo.branch)
            Built: \(BuildInfo.buildTimestamp)
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func preferencesMenuItemClicked() {
        openPreferences()
    }

    @objc private func quitMenuItemClicked() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Window Delegate

private class PreferencesWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
