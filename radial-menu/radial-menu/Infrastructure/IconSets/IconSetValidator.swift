//
//  IconSetValidator.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/25/25.
//

import Foundation

/// Validates icon set directories and manifests
enum IconSetValidator {

    /// Result of validating an icon set
    struct ValidationResult {
        let isValid: Bool
        let errors: [ValidationError]
        let warnings: [ValidationWarning]

        static func valid() -> ValidationResult {
            ValidationResult(isValid: true, errors: [], warnings: [])
        }

        static func invalid(_ errors: [ValidationError], warnings: [ValidationWarning] = []) -> ValidationResult {
            ValidationResult(isValid: false, errors: errors, warnings: warnings)
        }
    }

    /// Validation errors (prevent loading)
    enum ValidationError: LocalizedError {
        case manifestNotFound
        case invalidJSON(Error)
        case missingVersion
        case unsupportedVersion(Int)
        case missingIdentifier
        case invalidIdentifier(String)
        case missingName
        case missingIconsField

        var errorDescription: String? {
            switch self {
            case .manifestNotFound:
                return "manifest.json not found"
            case .invalidJSON(let error):
                return "Invalid JSON: \(error.localizedDescription)"
            case .missingVersion:
                return "Missing 'version' field"
            case .unsupportedVersion(let version):
                return "Unsupported manifest version: \(version)"
            case .missingIdentifier:
                return "Missing 'identifier' field"
            case .invalidIdentifier(let id):
                return "Invalid identifier '\(id)': must contain only lowercase letters, numbers, hyphens, and periods"
            case .missingName:
                return "Missing 'name' field"
            case .missingIconsField:
                return "Missing 'icons' field"
            }
        }
    }

    /// Validation warnings (logged but don't prevent loading)
    enum ValidationWarning: LocalizedError {
        case missingIconFile(iconName: String, fileName: String)
        case unreadableImage(iconName: String, fileName: String)
        case unknownField(String)

        var errorDescription: String? {
            switch self {
            case .missingIconFile(let iconName, let fileName):
                return "Icon '\(iconName)' references missing file '\(fileName)'"
            case .unreadableImage(let iconName, let fileName):
                return "Icon '\(iconName)' file '\(fileName)' is unreadable"
            case .unknownField(let field):
                return "Unknown field '\(field)' in manifest"
            }
        }
    }

    // MARK: - Validation Methods

    /// Validates an icon set directory
    /// - Parameter directoryURL: URL of the icon set directory
    /// - Returns: Validation result with errors and warnings
    static func validate(directoryURL: URL) -> ValidationResult {
        let manifestURL = directoryURL.appendingPathComponent("manifest.json")

        // Check manifest exists
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            return .invalid([.manifestNotFound])
        }

        // Parse manifest
        let manifestData: Data
        do {
            manifestData = try Data(contentsOf: manifestURL)
        } catch {
            return .invalid([.invalidJSON(error)])
        }

        // Decode as raw JSON first for validation
        let json: [String: Any]
        do {
            guard let decoded = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any] else {
                return .invalid([.invalidJSON(NSError(domain: "IconSetValidator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Root must be an object"]))])
            }
            json = decoded
        } catch {
            return .invalid([.invalidJSON(error)])
        }

        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []

        // Validate required fields
        if let version = json["version"] as? Int {
            if version != 1 {
                errors.append(.unsupportedVersion(version))
            }
        } else {
            errors.append(.missingVersion)
        }

        if let identifier = json["identifier"] as? String {
            if !isValidIdentifier(identifier) {
                errors.append(.invalidIdentifier(identifier))
            }
        } else {
            errors.append(.missingIdentifier)
        }

        if json["name"] as? String == nil {
            errors.append(.missingName)
        }

        guard let icons = json["icons"] as? [String: Any] else {
            errors.append(.missingIconsField)
            return .invalid(errors, warnings: warnings)
        }

        // Don't validate files if we have structural errors
        if !errors.isEmpty {
            return .invalid(errors, warnings: warnings)
        }

        // Validate icon files exist
        let iconsDir = directoryURL.appendingPathComponent("icons")
        for (iconName, value) in icons {
            let filename: String?
            if let str = value as? String {
                filename = str
            } else if let dict = value as? [String: Any] {
                filename = dict["file"] as? String
            } else {
                filename = nil
            }

            if let filename = filename {
                let fileURL = iconsDir.appendingPathComponent(filename)
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    warnings.append(.missingIconFile(iconName: iconName, fileName: filename))
                }
            }
        }

        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }

    /// Checks if an identifier is valid (lowercase, numbers, hyphens, periods)
    private static func isValidIdentifier(_ identifier: String) -> Bool {
        let pattern = "^[a-z0-9.-]+$"
        return identifier.range(of: pattern, options: .regularExpression) != nil
    }
}
