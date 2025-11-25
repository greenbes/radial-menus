//
//  ToggleMenuIntent.swift
//  radial-menu
//
//  Intent to show, hide, or toggle the radial menu from Shortcuts.
//

import AppIntents
import Foundation

/// Type alias for the ViewModel provider dependency
typealias ViewModelProvider = @Sendable () async -> RadialMenuViewModel?

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

    // MARK: - Dependencies

    /// Provider that waits for ViewModel to be ready
    @Dependency
    var viewModelProvider: ViewModelProvider

    // MARK: - Parameters

    @Parameter(
        title: "Action",
        description: "Whether to show, hide, or toggle the menu",
        default: .toggle
    )
    var action: MenuActionAppEnum

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult {
        LogShortcuts("ToggleMenuIntent: Action=\(action.rawValue)")

        // Wait for app initialization when launched via Shortcuts
        // The app may still be starting up when the intent runs
        guard let viewModel = await viewModelProvider() else {
            LogShortcuts("ToggleMenuIntent: ViewModel not available", level: .error)
            throw ShortcutsIntentError.menuNotAvailable
        }
        LogShortcuts("ToggleMenuIntent: ViewModel acquired")

        switch action {
        case .show:
            if !viewModel.isOpen {
                viewModel.openMenu()
                LogShortcuts("ToggleMenuIntent: Menu shown")
            } else {
                LogShortcuts("ToggleMenuIntent: Menu already open")
            }
            return .result(dialog: "Menu shown")

        case .hide:
            if viewModel.isOpen {
                viewModel.closeMenu()
                LogShortcuts("ToggleMenuIntent: Menu hidden")
            } else {
                LogShortcuts("ToggleMenuIntent: Menu already closed")
            }
            return .result(dialog: "Menu hidden")

        case .toggle:
            viewModel.toggleMenu()
            let resultMessage = viewModel.isOpen ? "Menu shown" : "Menu hidden"
            LogShortcuts("ToggleMenuIntent: \(resultMessage)")
            return .result(dialog: "\(resultMessage)")
        }
    }
}
