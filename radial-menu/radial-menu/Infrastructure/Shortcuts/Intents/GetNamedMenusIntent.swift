//
//  GetNamedMenusIntent.swift
//  radial-menu
//
//  Intent to list all available named menus.
//

import AppIntents

/// Intent to list all saved menu configurations.
///
/// This intent allows Shortcuts to discover what named menus are available
/// before showing one. Useful for building dynamic workflows.
struct GetNamedMenusIntent: AppIntent {
    // MARK: - AppIntent Requirements

    static var title: LocalizedStringResource = "Get Named Menus"

    static var description = IntentDescription(
        "Get a list of all saved menu configurations.",
        categoryName: "Radial Menu"
    )

    /// App doesn't need to be running for this.
    static var openAppWhenRun: Bool = false

    // MARK: - Perform

    func perform() async throws -> some IntentResult & ReturnsValue<[NamedMenuEntity]> {
        let menus = ShortcutsServiceLocator.shared.menuProvider.availableMenus
        let entities = menus.map { NamedMenuEntity(from: $0) }

        LogShortcuts("GetNamedMenusIntent: Returning \(entities.count) menus")
        return .result(value: entities)
    }
}
