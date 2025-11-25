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

    // MARK: - URL Scheme Handling

    func application(_ application: NSApplication, open urls: [URL]) {
        LogLifecycle("Received URL(s): \(urls.map { $0.absoluteString })")

        for url in urls {
            if url.scheme == URLSchemeHandler.scheme {
                URLSchemeHandler.shared.handle(url)
            }
        }
    }
}
