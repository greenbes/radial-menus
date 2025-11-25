//
//  Logger.swift
//  radial-menu
//
//  Apple Unified Logging System integration
//

import Foundation
import os.log

// MARK: - Subsystem

private let subsystem = "Six-Gables-Software.radial-menu"

// MARK: - Log Level

/// Custom log level enum to avoid requiring `import os` in calling files
enum LogLevel {
    case debug
    case info
    case `default`
    case error
    case fault

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .default: return .default
        case .error: return .error
        case .fault: return .fault
        }
    }
}

// MARK: - Log Categories

enum LogCategory: String {
    case lifecycle = "Lifecycle"   // App startup, shutdown, coordinator
    case input = "Input"           // Hotkey, keyboard, mouse, controller
    case menu = "Menu"             // Menu state, selection changes
    case window = "Window"         // Window management, positioning
    case geometry = "Geometry"     // Hit detection, angle calculations
    case action = "Action"         // Action execution
    case config = "Config"         // Configuration loading/saving

    var logger: os.Logger {
        os.Logger(subsystem: subsystem, category: rawValue)
    }
}

// MARK: - Convenience Logging Functions

/// Log app lifecycle events (startup, shutdown, coordinator)
func LogLifecycle(_ message: String, level: LogLevel = .info) {
    LogCategory.lifecycle.logger.log(level: level.osLogType, "\(message, privacy: .public)")
}

/// Log input events (hotkey, keyboard, mouse, controller)
func LogInput(_ message: String, level: LogLevel = .debug) {
    LogCategory.input.logger.log(level: level.osLogType, "\(message, privacy: .public)")
}

/// Log menu state changes and selection
func LogMenu(_ message: String, level: LogLevel = .info) {
    LogCategory.menu.logger.log(level: level.osLogType, "\(message, privacy: .public)")
}

/// Log window management events
func LogWindow(_ message: String, level: LogLevel = .debug) {
    LogCategory.window.logger.log(level: level.osLogType, "\(message, privacy: .public)")
}

/// Log geometry calculations (hit detection, angles)
func LogGeometry(_ message: String) {
    LogCategory.geometry.logger.log(level: .debug, "\(message, privacy: .public)")
}

/// Log action execution events
func LogAction(_ message: String, level: LogLevel = .info) {
    LogCategory.action.logger.log(level: level.osLogType, "\(message, privacy: .public)")
}

/// Log configuration events
func LogConfig(_ message: String, level: LogLevel = .info) {
    LogCategory.config.logger.log(level: level.osLogType, "\(message, privacy: .public)")
}

/// Log errors with specified category
func LogError(_ message: String, category: LogCategory = .lifecycle) {
    category.logger.log(level: .error, "\(message, privacy: .public)")
}
