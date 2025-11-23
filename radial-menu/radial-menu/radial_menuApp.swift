//
//  radial_menuApp.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import SwiftUI

@main
struct RadialMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
