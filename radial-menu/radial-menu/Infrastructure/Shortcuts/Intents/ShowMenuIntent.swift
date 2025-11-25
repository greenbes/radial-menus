//
//  ShowMenuIntent.swift
//  radial-menu
//
//  Intent to show the radial menu and wait for user selection.
//

import AppIntents
import Foundation
import AppKit

/// Intent to show the radial menu and return the selected item.
///
/// This intent opens the menu and waits for the user to select an item
/// or dismiss the menu. Returns the selected item's title, or empty if dismissed.
struct ShowMenuIntent: AppIntent {
    // MARK: - AppIntent Requirements

    static var title: LocalizedStringResource = "Show Radial Menu"

    static var description = IntentDescription(
        "Show the radial menu and wait for user selection.",
        categoryName: "Radial Menu"
    )

    /// Launch app if not running (needed for UI)
    static var openAppWhenRun: Bool = true

    // MARK: - Parameters

    @Parameter(
        title: "Wait for Selection",
        description: "If true, waits for user to select an item before returning",
        default: true
    )
    var waitForSelection: Bool

    // MARK: - Perform

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Capture parameter value before entering closures to avoid capturing self
        let shouldWait = waitForSelection

        // Schedule the action on the main run loop after a brief delay
        // This ensures the app is fully initialized before we try to use it
        let result: String = await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Task { @MainActor in
                    LogShortcuts("ShowMenuIntent: waitForSelection=\(shouldWait)")
                    guard let viewModel = ShortcutsServiceLocator.shared.viewModel else {
                        LogShortcuts("ShowMenuIntent: ViewModel not available", level: .error)
                        continuation.resume(returning: "")
                        return
                    }

                    if viewModel.isOpen {
                        LogShortcuts("ShowMenuIntent: Menu already open")
                        continuation.resume(returning: "")
                        return
                    }

                    if shouldWait {
                        // Open menu with completion handler - resume when menu closes
                        viewModel.openMenu { selectedItem in
                            let title = selectedItem?.title ?? ""
                            LogShortcuts("ShowMenuIntent: Menu closed, selected='\(title)'")
                            continuation.resume(returning: title)
                        }
                        LogShortcuts("ShowMenuIntent: Menu shown, waiting for selection")
                    } else {
                        // Just open the menu and return immediately
                        viewModel.openMenu()
                        LogShortcuts("ShowMenuIntent: Menu shown")
                        continuation.resume(returning: "")
                    }
                }
            }
        }

        return .result(value: result)
    }
}
