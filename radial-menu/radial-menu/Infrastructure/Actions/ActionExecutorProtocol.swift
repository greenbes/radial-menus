//
//  ActionExecutorProtocol.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation

/// Result of action execution
enum ActionResult {
    case success
    case failure(Error)
}

/// Protocol for executing menu item actions
protocol ActionExecutorProtocol {
    /// Execute an action
    /// - Parameter action: The action to execute
    /// - Returns: Result of execution
    @discardableResult
    func execute(_ action: ActionType) -> ActionResult

    /// Execute an action asynchronously
    /// - Parameters:
    ///   - action: The action to execute
    ///   - completion: Completion handler with result
    func executeAsync(
        _ action: ActionType,
        completion: @escaping (ActionResult) -> Void
    )
}

/// Errors that can occur during action execution
enum ActionExecutionError: LocalizedError {
    case applicationNotFound(path: String)
    case commandFailed(command: String, exitCode: Int32)
    case keyboardSimulationFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .applicationNotFound(let path):
            return "Application not found at path: \(path)"
        case .commandFailed(let command, let exitCode):
            return "Command '\(command)' failed with exit code \(exitCode)"
        case .keyboardSimulationFailed:
            return "Failed to simulate keyboard shortcut"
        case .permissionDenied:
            return "Permission denied for this action"
        }
    }
}
