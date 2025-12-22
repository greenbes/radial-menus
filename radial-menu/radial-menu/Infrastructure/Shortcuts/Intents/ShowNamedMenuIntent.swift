//
//  ShowNamedMenuIntent.swift
//  radial-menu
//
//  Intent to show a pre-configured named menu.
//

import AppIntents
import Foundation

/// Intent to show a saved menu by name and return the selection.
///
/// Named menus are stored in `~/Library/Application Support/com.radial-menu/menus/`.
/// This intent provides a picker UI for selecting from available menus.
struct ShowNamedMenuIntent: AppIntent {
    // MARK: - AppIntent Requirements

    static var title: LocalizedStringResource = "Show Named Menu"

    static var description = IntentDescription(
        "Show a saved menu by name and optionally return the selection.",
        categoryName: "Radial Menu"
    )

    /// Launch app if not running (needed for UI).
    static var openAppWhenRun: Bool = true

    // MARK: - Parameters

    @Parameter(
        title: "Menu",
        description: "The named menu to display"
    )
    var menu: NamedMenuEntity

    @Parameter(
        title: "Return Only",
        description: "If true, returns the selection without executing the action",
        default: false
    )
    var returnOnly: Bool

    // MARK: - Perform

    func perform() async throws -> some IntentResult & ReturnsValue<MenuSelectionResultEntity> {
        LogShortcuts("ShowNamedMenuIntent: Showing '\(menu.name)', returnOnly=\(returnOnly)")

        // Wait for app to be ready
        try? await Task.sleep(nanoseconds: 500_000_000)

        let result: MenuSelectionResult?

        do {
            let handler = ShortcutsServiceLocator.shared.externalRequestHandler
            result = try await handler.showMenu(
                source: .named(menu.name),
                position: nil,
                returnOnly: returnOnly
            )
        } catch {
            LogShortcuts("ShowNamedMenuIntent: Error - \(error.localizedDescription)", level: .error)
            throw error
        }

        let entity = MenuSelectionResultEntity(from: result)
        LogShortcuts("ShowNamedMenuIntent: Returning result, dismissed=\(entity.wasDismissed)")
        return .result(value: entity)
    }
}
