//
//  MockActionExecutor.swift
//  radial-menuTests
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation
@testable import radial_menu

/// Mock implementation of ActionExecutorProtocol for testing
class MockActionExecutor: ActionExecutorProtocol {
    var executeCallCount = 0
    var lastExecutedAction: ActionType?
    var resultToReturn: ActionResult = .success

    func execute(_ action: ActionType) -> ActionResult {
        executeCallCount += 1
        lastExecutedAction = action
        return resultToReturn
    }

    func executeAsync(
        _ action: ActionType,
        completion: @escaping (ActionResult) -> Void
    ) {
        executeCallCount += 1
        lastExecutedAction = action
        DispatchQueue.main.async {
            completion(self.resultToReturn)
        }
    }

    func reset() {
        executeCallCount = 0
        lastExecutedAction = nil
        resultToReturn = .success
    }
}
