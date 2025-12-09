//
//  RunningApplicationProviderProtocol.swift
//  radial-menu
//
//  Protocol for retrieving running applications for the task switcher.
//

import AppKit
import Foundation

/// Value type representing a running application
struct RunningAppInfo: Identifiable {
    /// Unique identifier (same as bundleIdentifier)
    let id: String

    /// The application's bundle identifier
    let bundleIdentifier: String

    /// The localized display name of the application
    let localizedName: String

    /// The application's icon
    let icon: NSImage?
}

/// Protocol for providing running application information
protocol RunningApplicationProviderProtocol {
    /// Returns currently running user-visible applications
    /// - Returns: Array of RunningAppInfo for apps that appear in Cmd-Tab
    func runningApplications() -> [RunningAppInfo]
}
