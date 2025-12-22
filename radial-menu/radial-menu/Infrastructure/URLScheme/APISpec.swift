//
//  APISpec.swift
//  radial-menu
//
//  API specification data model for self-describing external API.
//

import Foundation

/// API specification for external callers to discover available commands and types.
struct APISpec: Codable {
    /// API specification version
    let apiVersion: String

    /// Application version from bundle
    let appVersion: String

    /// Build identifier (commit hash)
    let buildID: String

    /// URL scheme identifier
    let scheme: String

    /// Base URL for commands
    let baseURL: String

    /// Available URL scheme commands
    let commands: [String: Command]

    /// Available action types for menu items
    let actionTypes: [String: ActionTypeInfo]

    /// JSON schemas for input/output validation
    let schemas: Schemas

    /// Currently available named menus
    let namedMenus: [NamedMenu]

    /// Current menu items in default configuration
    let currentMenuItems: [MenuItemSummary]

    // MARK: - Nested Types

    /// A URL scheme command
    struct Command: Codable {
        let description: String
        let parameters: [String: Parameter]
        let examples: [String]
    }

    /// A command parameter
    struct Parameter: Codable {
        let type: String
        let description: String
        let required: Bool
        let format: String?
        let enumValues: [String]?
        let defaultValue: String?

        enum CodingKeys: String, CodingKey {
            case type
            case description
            case required
            case format
            case enumValues = "enum"
            case defaultValue = "default"
        }

        init(
            type: String,
            description: String,
            required: Bool = false,
            format: String? = nil,
            enumValues: [String]? = nil,
            defaultValue: String? = nil
        ) {
            self.type = type
            self.description = description
            self.required = required
            self.format = format
            self.enumValues = enumValues
            self.defaultValue = defaultValue
        }
    }

    /// Information about an action type
    struct ActionTypeInfo: Codable {
        let description: String
        let format: AnyCodable
        let properties: [String: Parameter]?
        let availableCommands: [String]?
    }

    /// Container for JSON schemas
    struct Schemas: Codable {
        let menuConfiguration: AnyCodable
        let menuSelectionResult: AnyCodable
    }

    /// Summary of a named menu
    struct NamedMenu: Codable {
        let name: String
        let description: String?
        let itemCount: Int
    }

    /// Summary of a menu item
    struct MenuItemSummary: Codable {
        let id: String
        let title: String
        let iconName: String
        let actionType: String
        let position: Int
    }
}

// MARK: - AnyCodable Helper

/// Type-erased Codable wrapper for embedding raw JSON structures
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Unable to encode value of type \(type(of: value))"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
}
