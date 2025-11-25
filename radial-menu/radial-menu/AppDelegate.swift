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
}
