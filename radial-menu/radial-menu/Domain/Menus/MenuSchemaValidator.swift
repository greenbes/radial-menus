//
//  MenuSchemaValidator.swift
//  radial-menu
//
//  Validates menu JSON against the schema with detailed error messages.
//

import Foundation

/// Validates menu JSON data against the schema.
///
/// Provides detailed, human-readable error messages for schema violations.
/// This complements Swift's Codable decoding with pre-validation that
/// produces better error messages.
enum MenuSchemaValidator {
    // MARK: - Validation Result

    /// A validation error with location and description.
    struct ValidationError: LocalizedError, Equatable {
        /// JSON path to the error (e.g., "items[0].action")
        let path: String

        /// Human-readable description of the error
        let message: String

        var errorDescription: String? {
            if path.isEmpty {
                return message
            }
            return "\(path): \(message)"
        }
    }

    /// Result of schema validation.
    struct ValidationResult {
        let errors: [ValidationError]

        var isValid: Bool { errors.isEmpty }

        /// Returns a formatted multi-line error message.
        func formattedErrors() -> String {
            guard !errors.isEmpty else { return "" }

            if errors.count == 1 {
                return "Schema validation error: \(errors[0].errorDescription ?? errors[0].message)"
            }

            var lines = ["Schema validation errors:"]
            for (index, error) in errors.enumerated() {
                lines.append("  \(index + 1). \(error.errorDescription ?? error.message)")
            }
            return lines.joined(separator: "\n")
        }
    }

    // MARK: - Public API

    /// Validates JSON data against the menu schema.
    ///
    /// - Parameter data: Raw JSON data to validate
    /// - Returns: ValidationResult with any errors found
    static func validate(data: Data) -> ValidationResult {
        var errors: [ValidationError] = []

        // Parse JSON
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ValidationResult(errors: [
                ValidationError(path: "", message: "Invalid JSON: could not parse as object")
            ])
        }

        // Validate root object
        validateRoot(json, errors: &errors)

        return ValidationResult(errors: errors)
    }

    /// Validates a JSON string against the menu schema.
    ///
    /// - Parameter jsonString: JSON string to validate
    /// - Returns: ValidationResult with any errors found
    static func validate(jsonString: String) -> ValidationResult {
        guard let data = jsonString.data(using: .utf8) else {
            return ValidationResult(errors: [
                ValidationError(path: "", message: "Invalid JSON: could not convert string to data")
            ])
        }
        return validate(data: data)
    }

    // MARK: - Root Validation

    private static func validateRoot(_ json: [String: Any], errors: inout [ValidationError]) {
        // Required: version
        if let version = json["version"] {
            if let versionInt = version as? Int {
                if versionInt != 1 {
                    errors.append(ValidationError(
                        path: "version",
                        message: "must be 1 (got \(versionInt))"
                    ))
                }
            } else {
                errors.append(ValidationError(
                    path: "version",
                    message: "must be an integer"
                ))
            }
        } else {
            errors.append(ValidationError(
                path: "version",
                message: "is required"
            ))
        }

        // Required: name
        if let name = json["name"] {
            if let nameStr = name as? String {
                validateMenuName(nameStr, errors: &errors)
            } else {
                errors.append(ValidationError(
                    path: "name",
                    message: "must be a string"
                ))
            }
        } else {
            errors.append(ValidationError(
                path: "name",
                message: "is required"
            ))
        }

        // Required: items
        if let items = json["items"] {
            if let itemsArray = items as? [[String: Any]] {
                validateItems(itemsArray, errors: &errors)
            } else if items is [Any] {
                errors.append(ValidationError(
                    path: "items",
                    message: "must be an array of objects"
                ))
            } else {
                errors.append(ValidationError(
                    path: "items",
                    message: "must be an array"
                ))
            }
        } else {
            errors.append(ValidationError(
                path: "items",
                message: "is required"
            ))
        }

        // Optional: description (string)
        if let desc = json["description"], !(desc is String) {
            errors.append(ValidationError(
                path: "description",
                message: "must be a string"
            ))
        }

        // Optional: centerTitle (string)
        if let centerTitle = json["centerTitle"], !(centerTitle is String) {
            errors.append(ValidationError(
                path: "centerTitle",
                message: "must be a string"
            ))
        }

        // Optional: appearanceSettings
        if let appearance = json["appearanceSettings"] {
            if let appearanceObj = appearance as? [String: Any] {
                validateAppearanceSettings(appearanceObj, errors: &errors)
            } else {
                errors.append(ValidationError(
                    path: "appearanceSettings",
                    message: "must be an object"
                ))
            }
        }

        // Optional: behaviorSettings
        if let behavior = json["behaviorSettings"] {
            if let behaviorObj = behavior as? [String: Any] {
                validateBehaviorSettings(behaviorObj, errors: &errors)
            } else {
                errors.append(ValidationError(
                    path: "behaviorSettings",
                    message: "must be an object"
                ))
            }
        }

        // Check for unknown keys
        let knownKeys: Set<String> = [
            "version", "name", "description", "centerTitle",
            "items", "appearanceSettings", "behaviorSettings"
        ]
        for key in json.keys where !knownKeys.contains(key) {
            errors.append(ValidationError(
                path: key,
                message: "unknown property"
            ))
        }
    }

    // MARK: - Name Validation

    private static func validateMenuName(_ name: String, errors: inout [ValidationError]) {
        if name.isEmpty {
            errors.append(ValidationError(
                path: "name",
                message: "cannot be empty"
            ))
            return
        }

        if name.hasPrefix(".") {
            errors.append(ValidationError(
                path: "name",
                message: "cannot start with a dot"
            ))
        }

        if name.contains("/") || name.contains("\\") {
            errors.append(ValidationError(
                path: "name",
                message: "cannot contain path separators (/ or \\)"
            ))
        }

        if name.contains("..") {
            errors.append(ValidationError(
                path: "name",
                message: "cannot contain path traversal (..)"
            ))
        }
    }

    // MARK: - Items Validation

    private static func validateItems(_ items: [[String: Any]], errors: inout [ValidationError]) {
        if items.isEmpty {
            errors.append(ValidationError(
                path: "items",
                message: "must contain at least 1 item"
            ))
            return
        }

        if items.count > 12 {
            errors.append(ValidationError(
                path: "items",
                message: "cannot contain more than 12 items (got \(items.count))"
            ))
        }

        for (index, item) in items.enumerated() {
            validateMenuItem(item, index: index, errors: &errors)
        }
    }

    private static func validateMenuItem(_ item: [String: Any], index: Int, errors: inout [ValidationError]) {
        let path = "items[\(index)]"

        // Required: title
        if let title = item["title"] {
            if let titleStr = title as? String {
                if titleStr.isEmpty {
                    errors.append(ValidationError(
                        path: "\(path).title",
                        message: "cannot be empty"
                    ))
                }
            } else {
                errors.append(ValidationError(
                    path: "\(path).title",
                    message: "must be a string"
                ))
            }
        } else {
            errors.append(ValidationError(
                path: "\(path).title",
                message: "is required"
            ))
        }

        // Required: iconName
        if let iconName = item["iconName"] {
            if let iconStr = iconName as? String {
                if iconStr.isEmpty {
                    errors.append(ValidationError(
                        path: "\(path).iconName",
                        message: "cannot be empty"
                    ))
                }
            } else {
                errors.append(ValidationError(
                    path: "\(path).iconName",
                    message: "must be a string"
                ))
            }
        } else {
            errors.append(ValidationError(
                path: "\(path).iconName",
                message: "is required"
            ))
        }

        // Required: action
        if let action = item["action"] {
            if let actionObj = action as? [String: Any] {
                validateAction(actionObj, path: "\(path).action", errors: &errors)
            } else {
                errors.append(ValidationError(
                    path: "\(path).action",
                    message: "must be an object"
                ))
            }
        } else {
            errors.append(ValidationError(
                path: "\(path).action",
                message: "is required"
            ))
        }

        // Optional: id (UUID string)
        if let id = item["id"], !(id is String) {
            errors.append(ValidationError(
                path: "\(path).id",
                message: "must be a string (UUID format)"
            ))
        }

        // Optional: preserveColors (boolean)
        if let preserveColors = item["preserveColors"], !(preserveColors is Bool) {
            errors.append(ValidationError(
                path: "\(path).preserveColors",
                message: "must be a boolean"
            ))
        }

        // Optional: accessibilityLabel (string)
        if let label = item["accessibilityLabel"], !(label is String) {
            errors.append(ValidationError(
                path: "\(path).accessibilityLabel",
                message: "must be a string"
            ))
        }

        // Optional: accessibilityHint (string)
        if let hint = item["accessibilityHint"], !(hint is String) {
            errors.append(ValidationError(
                path: "\(path).accessibilityHint",
                message: "must be a string"
            ))
        }

        // Check for unknown keys
        let knownKeys: Set<String> = [
            "id", "title", "iconName", "action",
            "preserveColors", "accessibilityLabel", "accessibilityHint"
        ]
        for key in item.keys where !knownKeys.contains(key) {
            errors.append(ValidationError(
                path: "\(path).\(key)",
                message: "unknown property"
            ))
        }
    }

    // MARK: - Action Validation

    private static let validActionTypes: Set<String> = [
        "launchApp", "runShellCommand", "simulateKeyboardShortcut",
        "openTaskSwitcher", "activateApp", "internalCommand"
    ]

    private static func validateAction(_ action: [String: Any], path: String, errors: inout [ValidationError]) {
        // Action must have exactly one key
        if action.isEmpty {
            errors.append(ValidationError(
                path: path,
                message: "must specify an action type"
            ))
            return
        }

        if action.count > 1 {
            errors.append(ValidationError(
                path: path,
                message: "must have exactly one action type (got: \(action.keys.sorted().joined(separator: ", ")))"
            ))
            return
        }

        let actionType = action.keys.first!
        let actionValue = action[actionType]!

        guard validActionTypes.contains(actionType) else {
            errors.append(ValidationError(
                path: path,
                message: "unknown action type '\(actionType)'. Valid types: \(validActionTypes.sorted().joined(separator: ", "))"
            ))
            return
        }

        switch actionType {
        case "launchApp":
            validateLaunchAppAction(actionValue, path: "\(path).launchApp", errors: &errors)

        case "runShellCommand":
            validateRunShellCommandAction(actionValue, path: "\(path).runShellCommand", errors: &errors)

        case "simulateKeyboardShortcut":
            validateKeyboardShortcutAction(actionValue, path: "\(path).simulateKeyboardShortcut", errors: &errors)

        case "openTaskSwitcher":
            if !(actionValue is [String: Any]) {
                errors.append(ValidationError(
                    path: "\(path).openTaskSwitcher",
                    message: "must be an empty object {}"
                ))
            }

        case "activateApp":
            validateActivateAppAction(actionValue, path: "\(path).activateApp", errors: &errors)

        case "internalCommand":
            validateInternalCommandAction(actionValue, path: "\(path).internalCommand", errors: &errors)

        default:
            break
        }
    }

    private static func validateLaunchAppAction(_ value: Any, path: String, errors: inout [ValidationError]) {
        guard let obj = value as? [String: Any] else {
            errors.append(ValidationError(path: path, message: "must be an object"))
            return
        }

        if let pathValue = obj["path"] {
            if let pathStr = pathValue as? String {
                if !pathStr.hasPrefix("/") {
                    errors.append(ValidationError(
                        path: "\(path).path",
                        message: "must be an absolute path (start with /)"
                    ))
                }
                if !pathStr.hasSuffix(".app") {
                    errors.append(ValidationError(
                        path: "\(path).path",
                        message: "must end with .app"
                    ))
                }
            } else {
                errors.append(ValidationError(
                    path: "\(path).path",
                    message: "must be a string"
                ))
            }
        } else {
            errors.append(ValidationError(
                path: "\(path).path",
                message: "is required"
            ))
        }
    }

    private static func validateRunShellCommandAction(_ value: Any, path: String, errors: inout [ValidationError]) {
        guard let obj = value as? [String: Any] else {
            errors.append(ValidationError(path: path, message: "must be an object"))
            return
        }

        if let command = obj["command"] {
            if let cmdStr = command as? String {
                if cmdStr.isEmpty {
                    errors.append(ValidationError(
                        path: "\(path).command",
                        message: "cannot be empty"
                    ))
                }
            } else {
                errors.append(ValidationError(
                    path: "\(path).command",
                    message: "must be a string"
                ))
            }
        } else {
            errors.append(ValidationError(
                path: "\(path).command",
                message: "is required"
            ))
        }
    }

    private static func validateKeyboardShortcutAction(_ value: Any, path: String, errors: inout [ValidationError]) {
        guard let obj = value as? [String: Any] else {
            errors.append(ValidationError(path: path, message: "must be an object"))
            return
        }

        // Required: modifiers
        if let modifiers = obj["modifiers"] {
            if let modArray = modifiers as? [String] {
                let validModifiers: Set<String> = ["command", "option", "control", "shift"]
                for (index, mod) in modArray.enumerated() {
                    if !validModifiers.contains(mod) {
                        errors.append(ValidationError(
                            path: "\(path).modifiers[\(index)]",
                            message: "invalid modifier '\(mod)'. Valid: \(validModifiers.sorted().joined(separator: ", "))"
                        ))
                    }
                }
            } else {
                errors.append(ValidationError(
                    path: "\(path).modifiers",
                    message: "must be an array of strings"
                ))
            }
        } else {
            errors.append(ValidationError(
                path: "\(path).modifiers",
                message: "is required"
            ))
        }

        // Required: key
        if let key = obj["key"] {
            if let keyStr = key as? String {
                if keyStr.isEmpty {
                    errors.append(ValidationError(
                        path: "\(path).key",
                        message: "cannot be empty"
                    ))
                }
            } else {
                errors.append(ValidationError(
                    path: "\(path).key",
                    message: "must be a string"
                ))
            }
        } else {
            errors.append(ValidationError(
                path: "\(path).key",
                message: "is required"
            ))
        }
    }

    private static func validateActivateAppAction(_ value: Any, path: String, errors: inout [ValidationError]) {
        guard let obj = value as? [String: Any] else {
            errors.append(ValidationError(path: path, message: "must be an object"))
            return
        }

        if let bundleId = obj["bundleIdentifier"] {
            if let idStr = bundleId as? String {
                if idStr.isEmpty {
                    errors.append(ValidationError(
                        path: "\(path).bundleIdentifier",
                        message: "cannot be empty"
                    ))
                }
            } else {
                errors.append(ValidationError(
                    path: "\(path).bundleIdentifier",
                    message: "must be a string"
                ))
            }
        } else {
            errors.append(ValidationError(
                path: "\(path).bundleIdentifier",
                message: "is required"
            ))
        }
    }

    private static func validateInternalCommandAction(_ value: Any, path: String, errors: inout [ValidationError]) {
        guard let commandStr = value as? String else {
            errors.append(ValidationError(
                path: path,
                message: "must be a string"
            ))
            return
        }

        let validCommands: Set<String> = ["switchApp", "finder"]
        if !validCommands.contains(commandStr) {
            errors.append(ValidationError(
                path: path,
                message: "unknown command '\(commandStr)'. Valid: \(validCommands.sorted().joined(separator: ", "))"
            ))
        }
    }

    // MARK: - Appearance Settings Validation

    private static func validateAppearanceSettings(_ settings: [String: Any], errors: inout [ValidationError]) {
        let path = "appearanceSettings"

        // radius: 50-500
        if let radius = settings["radius"] {
            if let val = radius as? Double {
                if val < 50 || val > 500 {
                    errors.append(ValidationError(
                        path: "\(path).radius",
                        message: "must be between 50 and 500 (got \(val))"
                    ))
                }
            } else if let val = radius as? Int {
                if val < 50 || val > 500 {
                    errors.append(ValidationError(
                        path: "\(path).radius",
                        message: "must be between 50 and 500 (got \(val))"
                    ))
                }
            } else {
                errors.append(ValidationError(
                    path: "\(path).radius",
                    message: "must be a number"
                ))
            }
        }

        // centerRadius: 10-100
        if let centerRadius = settings["centerRadius"] {
            if let val = centerRadius as? Double {
                if val < 10 || val > 100 {
                    errors.append(ValidationError(
                        path: "\(path).centerRadius",
                        message: "must be between 10 and 100 (got \(val))"
                    ))
                }
            } else if let val = centerRadius as? Int {
                if val < 10 || val > 100 {
                    errors.append(ValidationError(
                        path: "\(path).centerRadius",
                        message: "must be between 10 and 100 (got \(val))"
                    ))
                }
            } else {
                errors.append(ValidationError(
                    path: "\(path).centerRadius",
                    message: "must be a number"
                ))
            }
        }

        // sliceHighlightScale: 1.0-2.0
        if let scale = settings["sliceHighlightScale"] {
            if let val = scale as? Double {
                if val < 1.0 || val > 2.0 {
                    errors.append(ValidationError(
                        path: "\(path).sliceHighlightScale",
                        message: "must be between 1.0 and 2.0 (got \(val))"
                    ))
                }
            } else {
                errors.append(ValidationError(
                    path: "\(path).sliceHighlightScale",
                    message: "must be a number"
                ))
            }
        }

        // animationDuration: 0-1.0
        if let duration = settings["animationDuration"] {
            if let val = duration as? Double {
                if val < 0 || val > 1.0 {
                    errors.append(ValidationError(
                        path: "\(path).animationDuration",
                        message: "must be between 0 and 1.0 (got \(val))"
                    ))
                }
            } else {
                errors.append(ValidationError(
                    path: "\(path).animationDuration",
                    message: "must be a number"
                ))
            }
        }

        // iconSetIdentifier: string
        if let iconSet = settings["iconSetIdentifier"], !(iconSet is String) {
            errors.append(ValidationError(
                path: "\(path).iconSetIdentifier",
                message: "must be a string"
            ))
        }

        // Color properties
        for colorKey in ["backgroundColor", "foregroundColor", "selectedItemColor"] {
            if let color = settings[colorKey] {
                if let colorObj = color as? [String: Any] {
                    validateColor(colorObj, path: "\(path).\(colorKey)", errors: &errors)
                } else {
                    errors.append(ValidationError(
                        path: "\(path).\(colorKey)",
                        message: "must be an object"
                    ))
                }
            }
        }
    }

    private static func validateColor(_ color: [String: Any], path: String, errors: inout [ValidationError]) {
        let requiredComponents = ["red", "green", "blue", "alpha"]

        for component in requiredComponents {
            if let value = color[component] {
                if let num = value as? Double {
                    if num < 0 || num > 1 {
                        errors.append(ValidationError(
                            path: "\(path).\(component)",
                            message: "must be between 0 and 1 (got \(num))"
                        ))
                    }
                } else if let num = value as? Int {
                    if num < 0 || num > 1 {
                        errors.append(ValidationError(
                            path: "\(path).\(component)",
                            message: "must be between 0 and 1 (got \(num))"
                        ))
                    }
                } else {
                    errors.append(ValidationError(
                        path: "\(path).\(component)",
                        message: "must be a number"
                    ))
                }
            } else {
                errors.append(ValidationError(
                    path: "\(path).\(component)",
                    message: "is required"
                ))
            }
        }
    }

    // MARK: - Behavior Settings Validation

    private static func validateBehaviorSettings(_ settings: [String: Any], errors: inout [ValidationError]) {
        let path = "behaviorSettings"

        // positionMode: enum
        if let mode = settings["positionMode"] {
            if let modeStr = mode as? String {
                let validModes: Set<String> = ["atCursor", "center", "fixedPosition"]
                if !validModes.contains(modeStr) {
                    errors.append(ValidationError(
                        path: "\(path).positionMode",
                        message: "must be one of: \(validModes.sorted().joined(separator: ", "))"
                    ))
                }
            } else {
                errors.append(ValidationError(
                    path: "\(path).positionMode",
                    message: "must be a string"
                ))
            }
        }

        // fixedPosition: object with x, y
        if let fixed = settings["fixedPosition"] {
            if let fixedObj = fixed as? [String: Any] {
                if fixedObj["x"] == nil {
                    errors.append(ValidationError(
                        path: "\(path).fixedPosition.x",
                        message: "is required"
                    ))
                } else if !(fixedObj["x"] is Double) && !(fixedObj["x"] is Int) {
                    errors.append(ValidationError(
                        path: "\(path).fixedPosition.x",
                        message: "must be a number"
                    ))
                }

                if fixedObj["y"] == nil {
                    errors.append(ValidationError(
                        path: "\(path).fixedPosition.y",
                        message: "is required"
                    ))
                } else if !(fixedObj["y"] is Double) && !(fixedObj["y"] is Int) {
                    errors.append(ValidationError(
                        path: "\(path).fixedPosition.y",
                        message: "must be a number"
                    ))
                }
            } else if !(fixed is NSNull) {
                errors.append(ValidationError(
                    path: "\(path).fixedPosition",
                    message: "must be an object or null"
                ))
            }
        }

        // showOnAllSpaces: boolean
        if let show = settings["showOnAllSpaces"], !(show is Bool) {
            errors.append(ValidationError(
                path: "\(path).showOnAllSpaces",
                message: "must be a boolean"
            ))
        }

        // joystickDeadzone: 0-1
        if let deadzone = settings["joystickDeadzone"] {
            if let val = deadzone as? Double {
                if val < 0 || val > 1 {
                    errors.append(ValidationError(
                        path: "\(path).joystickDeadzone",
                        message: "must be between 0 and 1 (got \(val))"
                    ))
                }
            } else {
                errors.append(ValidationError(
                    path: "\(path).joystickDeadzone",
                    message: "must be a number"
                ))
            }
        }
    }
}
