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

    init(configManager: ConfigurationManagerProtocol) {
        self.configManager = configManager
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
            onResetToDefault: { [weak self] in
                self?.configManager.resetToDefault()
            },
            onUpdateIconSet: { [weak self] newSet in
                guard let self else { return }
                var updated = configManager.currentConfiguration
                updated.appearanceSettings.iconSet = newSet
                do {
                    try configManager.saveConfiguration(updated)
                } catch {
                    print("❌ Failed to save icon set: \(error)")
                }
            },
            onUpdateBackgroundColor: { [weak self] newColor in
                guard let self else { return }
                var updated = configManager.currentConfiguration
                updated.appearanceSettings.backgroundColor = newColor
                do {
                    try configManager.saveConfiguration(updated)
                } catch {
                    print("❌ Failed to save background color: \(error)")
                }
            },
            onUpdateForegroundColor: { [weak self] newColor in
                guard let self else { return }
                var updated = configManager.currentConfiguration
                updated.appearanceSettings.foregroundColor = newColor
                do {
                    try configManager.saveConfiguration(updated)
                } catch {
                    print("❌ Failed to save foreground color: \(error)")
                }
            },
            onUpdateSelectedItemColor: { [weak self] newColor in
                guard let self else { return }
                var updated = configManager.currentConfiguration
                updated.appearanceSettings.selectedItemColor = newColor
                do {
                    try configManager.saveConfiguration(updated)
                } catch {
                    print("❌ Failed to save selected item color: \(error)")
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
