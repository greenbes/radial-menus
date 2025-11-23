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
        // Force logger initialization
        _ = Logger.shared
        Log("🚀 AppDelegate: Application did finish launching")
        
        // Create and start the coordinator
        coordinator = AppCoordinator()
        Log("🚀 AppDelegate: Coordinator created")
        coordinator?.start()
        Log("🚀 AppDelegate: Coordinator started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up
        Log("🛑 AppDelegate: Application will terminate")
        coordinator?.stop()
    }
}
