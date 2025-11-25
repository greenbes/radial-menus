//
//  AppDelegate.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        LogLifecycle("Application did finish launching")

        // Customize the application menu's About item
        customizeMainMenu()

        // Create and start the coordinator
        coordinator = AppCoordinator()
        LogLifecycle("Coordinator created")
        coordinator?.start()
        LogLifecycle("Coordinator started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        LogLifecycle("Application will terminate")
        coordinator?.stop()
    }

    // MARK: - Menu Customization

    private func customizeMainMenu() {
        // Find and customize the About menu item in the application menu
        guard let mainMenu = NSApp.mainMenu,
              let appMenu = mainMenu.items.first?.submenu else {
            return
        }

        // Find the About menu item and change its action
        for item in appMenu.items {
            if item.action == #selector(NSApplication.orderFrontStandardAboutPanel(_:)) {
                item.action = #selector(showCustomAboutPanel)
                item.target = self
                break
            }
        }
    }

    @objc private func showCustomAboutPanel() {
        // Show the standard About panel with custom credits containing build info
        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .credits: NSAttributedString(
                string: """
                    A configurable radial overlay menu for macOS.

                    Build: \(BuildInfo.buildID)
                    Branch: \(BuildInfo.branch)
                    Built: \(BuildInfo.buildTimestamp)
                    """,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
        ]
        NSApp.orderFrontStandardAboutPanel(options: options)
    }
}
