//
//  APISpecGenerator.swift
//  radial-menu
//
//  Generates API specification at runtime for external callers.
//

import Foundation

/// Generates the API specification from runtime data.
enum APISpecGenerator {
    /// Current API specification version
    static let apiVersion = "1.0.0"

    /// Generates the full API specification.
    static func generate() -> APISpec {
        let namedMenus = ShortcutsServiceLocator.shared.menuProvider.availableMenus
        let currentItems = ShortcutsServiceLocator.shared.configManager.currentConfiguration.items

        return APISpec(
            apiVersion: apiVersion,
            appVersion: appVersion,
            buildID: BuildInfo.buildID,
            scheme: URLSchemeHandler.scheme,
            baseURL: "\(URLSchemeHandler.scheme)://",
            commands: generateCommands(),
            actionTypes: generateActionTypes(),
            schemas: generateSchemas(),
            namedMenus: namedMenus.map { menu in
                APISpec.NamedMenu(
                    name: menu.name,
                    description: menu.description,
                    itemCount: menu.itemCount
                )
            },
            currentMenuItems: currentItems.enumerated().map { index, item in
                APISpec.MenuItemSummary(
                    id: item.id.uuidString,
                    title: item.title,
                    iconName: item.iconName,
                    actionType: item.action.typeDescription,
                    position: index
                )
            }
        )
    }

    /// Returns the app version from the bundle.
    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    // MARK: - Commands

    private static func generateCommands() -> [String: APISpec.Command] {
        [
            "show": APISpec.Command(
                description: "Show the radial menu",
                parameters: [
                    "menu": APISpec.Parameter(
                        type: "string",
                        description: "Name of a saved menu to display"
                    ),
                    "file": APISpec.Parameter(
                        type: "string",
                        description: "File path to a menu JSON definition"
                    ),
                    "json": APISpec.Parameter(
                        type: "string",
                        description: "Inline JSON menu definition (prefix with 'base64:' for base64-encoded JSON)"
                    ),
                    "position": APISpec.Parameter(
                        type: "string",
                        description: "Where to display the menu",
                        enumValues: ["cursor", "center", "{x},{y}"],
                        defaultValue: "cursor"
                    ),
                    "returnTo": APISpec.Parameter(
                        type: "string",
                        description: "File path to write selection result JSON (disables action execution)"
                    ),
                    "x-success": APISpec.Parameter(
                        type: "string",
                        description: "Callback URL on successful selection",
                        format: "uri"
                    ),
                    "x-error": APISpec.Parameter(
                        type: "string",
                        description: "Callback URL on error",
                        format: "uri"
                    ),
                    "x-cancel": APISpec.Parameter(
                        type: "string",
                        description: "Callback URL when menu is dismissed",
                        format: "uri"
                    )
                ],
                examples: [
                    "radial-menu://show",
                    "radial-menu://show?menu=development",
                    "radial-menu://show?position=center&returnTo=/tmp/selection.json",
                    "radial-menu://show?json=base64:eyJ2ZXJzaW9uIjoxLCJuYW1lIjoiVGVzdCIsIml0ZW1zIjpbXX0="
                ]
            ),
            "hide": APISpec.Command(
                description: "Hide the radial menu if visible",
                parameters: [:],
                examples: ["radial-menu://hide"]
            ),
            "toggle": APISpec.Command(
                description: "Toggle menu visibility",
                parameters: [:],
                examples: ["radial-menu://toggle"]
            ),
            "execute": APISpec.Command(
                description: "Execute a menu item's action directly without showing the menu",
                parameters: [
                    "item": APISpec.Parameter(
                        type: "string",
                        description: "UUID of the menu item to execute",
                        format: "uuid"
                    ),
                    "title": APISpec.Parameter(
                        type: "string",
                        description: "Title of the menu item to execute (case-insensitive)"
                    )
                ],
                examples: [
                    "radial-menu://execute?title=Terminal",
                    "radial-menu://execute?item=550e8400-e29b-41d4-a716-446655440000"
                ]
            ),
            "api": APISpec.Command(
                description: "Get API specification",
                parameters: [
                    "returnTo": APISpec.Parameter(
                        type: "string",
                        description: "File path to write the API specification JSON",
                        required: true
                    )
                ],
                examples: [
                    "radial-menu://api?returnTo=/tmp/api-spec.json"
                ]
            ),
            "schema": APISpec.Command(
                description: "Get a JSON schema by name",
                parameters: [
                    "name": APISpec.Parameter(
                        type: "string",
                        description: "Schema name to retrieve",
                        required: true,
                        enumValues: ["menu-configuration", "menu-selection-result", "api-spec"]
                    ),
                    "returnTo": APISpec.Parameter(
                        type: "string",
                        description: "File path to write the schema JSON",
                        required: true
                    )
                ],
                examples: [
                    "radial-menu://schema?name=menu-configuration&returnTo=/tmp/schema.json",
                    "radial-menu://schema?name=menu-selection-result&returnTo=/tmp/schema.json"
                ]
            )
        ]
    }

    // MARK: - Action Types

    private static func generateActionTypes() -> [String: APISpec.ActionTypeInfo] {
        [
            "launchApp": APISpec.ActionTypeInfo(
                description: "Launch an application",
                format: AnyCodable(["launchApp": ["path": "/path/to/app.app"]]),
                properties: [
                    "path": APISpec.Parameter(
                        type: "string",
                        description: "Path to the application bundle (.app)",
                        required: true
                    )
                ],
                availableCommands: nil
            ),
            "runShellCommand": APISpec.ActionTypeInfo(
                description: "Execute a shell command",
                format: AnyCodable(["runShellCommand": ["command": "echo hello"]]),
                properties: [
                    "command": APISpec.Parameter(
                        type: "string",
                        description: "Shell command to execute",
                        required: true
                    )
                ],
                availableCommands: nil
            ),
            "simulateKeyboardShortcut": APISpec.ActionTypeInfo(
                description: "Simulate a keyboard shortcut",
                format: AnyCodable([
                    "simulateKeyboardShortcut": [
                        "modifiers": ["command", "shift"],
                        "key": "4"
                    ]
                ]),
                properties: [
                    "modifiers": APISpec.Parameter(
                        type: "array",
                        description: "Modifier keys for the shortcut",
                        required: true,
                        enumValues: ["command", "option", "control", "shift"]
                    ),
                    "key": APISpec.Parameter(
                        type: "string",
                        description: "The key to press (e.g., 'a', '4', 'space')",
                        required: true
                    )
                ],
                availableCommands: nil
            ),
            "openTaskSwitcher": APISpec.ActionTypeInfo(
                description: "Open the macOS task switcher (Cmd+Tab)",
                format: AnyCodable(["openTaskSwitcher": [String: String]()]),
                properties: nil,
                availableCommands: nil
            ),
            "activateApp": APISpec.ActionTypeInfo(
                description: "Activate an application by bundle identifier",
                format: AnyCodable(["activateApp": ["bundleIdentifier": "com.apple.Safari"]]),
                properties: [
                    "bundleIdentifier": APISpec.Parameter(
                        type: "string",
                        description: "Bundle identifier of the application",
                        required: true
                    )
                ],
                availableCommands: nil
            ),
            "internalCommand": APISpec.ActionTypeInfo(
                description: "Execute a predefined internal command",
                format: AnyCodable(["internalCommand": "switchApp"]),
                properties: nil,
                availableCommands: InternalCommand.allCases.map { $0.rawValue }
            )
        ]
    }

    // MARK: - Schemas

    private static func generateSchemas() -> APISpec.Schemas {
        APISpec.Schemas(
            menuConfiguration: loadSchemaAsAnyCodable("menu-configuration"),
            menuSelectionResult: loadSchemaAsAnyCodable("menu-selection-result")
        )
    }

    /// Loads a bundled JSON schema file and returns it as AnyCodable.
    private static func loadSchemaAsAnyCodable(_ name: String) -> AnyCodable {
        let filename = "\(name).schema"

        // Try to load from bundle resources (in schemas subdirectory)
        if let url = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "schemas"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) {
            LogShortcuts("APISpecGenerator: Loaded schema '\(name)' from bundle subdirectory")
            return AnyCodable(json)
        }

        // Try without subdirectory (flat Resources)
        if let url = Bundle.main.url(forResource: filename, withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) {
            LogShortcuts("APISpecGenerator: Loaded schema '\(name)' from bundle root")
            return AnyCodable(json)
        }

        // Fallback: try Resources/schemas directory relative to executable
        if let executableURL = Bundle.main.executableURL {
            let schemasURL = executableURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources")
                .appendingPathComponent("schemas")
                .appendingPathComponent("\(name).schema.json")

            if let data = try? Data(contentsOf: schemasURL),
               let json = try? JSONSerialization.jsonObject(with: data) {
                LogShortcuts("APISpecGenerator: Loaded schema '\(name)' from Resources/schemas")
                return AnyCodable(json)
            }
        }

        // Return placeholder if schema not found
        LogShortcuts("APISpecGenerator: Schema '\(name)' not found in bundle", level: .error)
        return AnyCodable([
            "$comment": "Schema '\(name)' not found - see schemas/\(name).schema.json in repository"
        ])
    }
}
