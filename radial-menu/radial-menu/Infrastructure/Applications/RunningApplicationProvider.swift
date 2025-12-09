//
//  RunningApplicationProvider.swift
//  radial-menu
//
//  Implementation of RunningApplicationProviderProtocol using NSWorkspace.
//

import AppKit
import Foundation

/// Provides information about currently running applications
final class RunningApplicationProvider: RunningApplicationProviderProtocol {

    /// Returns currently running user-visible applications (Cmd-Tab style filtering)
    /// - Returns: Array of RunningAppInfo excluding radial-menu itself
    func runningApplications() -> [RunningAppInfo] {
        let ownBundleID = Bundle.main.bundleIdentifier ?? ""

        return NSWorkspace.shared.runningApplications
            .filter { app in
                // Only user-visible apps (activationPolicy .regular appears in Cmd-Tab)
                app.activationPolicy == .regular &&
                // Exclude ourselves
                app.bundleIdentifier != ownBundleID &&
                // Must have a bundle identifier
                app.bundleIdentifier != nil
            }
            .compactMap { app -> RunningAppInfo? in
                guard let bundleID = app.bundleIdentifier else { return nil }
                return RunningAppInfo(
                    id: bundleID,
                    bundleIdentifier: bundleID,
                    localizedName: app.localizedName ?? "Unknown",
                    icon: app.icon
                )
            }
    }
}
