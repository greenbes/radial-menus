//
//  radial_menuApp.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import SwiftUI
import AppIntents

@main
struct RadialMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Register async dependency provider for App Intents
        // This allows intents to wait for the ViewModel to be ready
        let viewModelProvider: @Sendable () async -> RadialMenuViewModel? = {
            await ShortcutsServiceLocator.shared.waitForViewModel()
        }
        AppDependencyManager.shared.add(dependency: viewModelProvider)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
