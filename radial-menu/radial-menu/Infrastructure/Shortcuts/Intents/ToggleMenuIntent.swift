//
//  ToggleMenuIntent.swift
//  radial-menu
//
//  Intent to show, hide, or toggle the radial menu from Shortcuts.
//

import AppIntents
import Foundation
import AppKit

/// Intent to show, hide, or toggle the radial menu overlay.
///
/// This intent requires the app UI to be running since it controls
/// the visual menu overlay.
struct ToggleMenuIntent: AppIntent {
    // MARK: - AppIntent Requirements

    static var title: LocalizedStringResource = "Toggle Radial Menu"

    static var description = IntentDescription(
        "Show, hide, or toggle the radial menu overlay.",
        categoryName: "Radial Menu"
    )

    /// Launch app if not running (needed for UI)
    static var openAppWhenRun: Bool = true

    // MARK: - Parameters

    @Parameter(
        title: "Action",
        description: "Whether to show, hide, or toggle the menu",
        default: .toggle
    )
    var action: MenuActionAppEnum

    // MARK: - Perform

    func perform() async throws -> some IntentResult {
        LogShortcuts("ToggleMenuIntent: Action=\(action.rawValue)")

        // Capture action for use in closure
        let menuAction = action

        // Schedule the action on the main run loop after a brief delay
        // This ensures the app is fully initialized before we try to use it
        await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Task { @MainActor in
                    guard let viewModel = ShortcutsServiceLocator.shared.viewModel else {
                        LogShortcuts("ToggleMenuIntent: ViewModel not available after delay", level: .error)
                        continuation.resume()
                        return
                    }

                    switch menuAction {
                    case .show:
                        if !viewModel.isOpen {
                            viewModel.openMenu()
                            LogShortcuts("ToggleMenuIntent: Menu shown")
                        }
                    case .hide:
                        if viewModel.isOpen {
                            viewModel.closeMenu()
                            LogShortcuts("ToggleMenuIntent: Menu hidden")
                        }
                    case .toggle:
                        viewModel.toggleMenu()
                        LogShortcuts("ToggleMenuIntent: Menu toggled")
                    }
                    continuation.resume()
                }
            }
        }

        return .result()
    }
}
