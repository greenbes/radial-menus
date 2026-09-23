public enum ShutdownOutcome: Equatable, Sendable {
    case completed
    case failed(String)
}

public struct Shutdown: Equatable, Sendable {
    public let deadline: OperationID
    public let releaseOperation: OperationID?
}

public enum ApplicationLifecycle: Equatable, Sendable {
    case running
    case stopping(Shutdown)
    case stopped(ShutdownOutcome)
}

extension Change {
    mutating func stop() {
        guard running else { return }
        guard let deadline = allocateOperation() else {
            finishShutdown(.failed("Cannot allocate a shutdown operation")); return
        }
        lifecycle = .stopping(Shutdown(deadline: deadline, releaseOperation: nil))
        controllers.removeAll()
        if let session = phase.session { cancel(session.scope, .applicationStopping) }
        // Recovery is superseded by the final release operation, which has a
        // newer identity. Its late acknowledgment cannot reopen the application.
        if case .unavailable(let failure, _) = phase { phase = .unavailable(failure, nil) }
    }

    mutating func advanceShutdown() {
        guard case .stopping(let shutdown) = lifecycle,
              shutdown.releaseOperation == nil, phase.session == nil else { return }
        guard let operation = allocateOperation() else {
            finishShutdown(.failed("Cannot allocate a resource release operation")); return
        }
        lifecycle = .stopping(Shutdown(deadline: shutdown.deadline, releaseOperation: operation))
        effects.append(.releaseResources(operation))
    }

    mutating func resourcesReleased(_ operation: OperationID) {
        guard case .stopping(let shutdown) = lifecycle, shutdown.releaseOperation == operation else { return }
        finishShutdown(.completed)
    }

    mutating func releaseFailed(_ operation: OperationID, _ message: String) {
        guard case .stopping(let shutdown) = lifecycle, shutdown.releaseOperation == operation else { return }
        finishShutdown(.failed(message))
    }

    mutating func shutdownDeadline(_ operation: OperationID) {
        guard case .stopping(let shutdown) = lifecycle, shutdown.deadline == operation else { return }
        let message = "Application shutdown timed out"
        if let session = phase.session {
            let choice: Choice?
            if case .dismissing(_, _, let outcome) = phase { choice = outcome.choice } else { choice = nil }
            let failure = SessionFailure(message: message, committedChoice: choice)
            outputs.append(.completed(session.scope.session, .failed(failure)))
            effects.append(.endInput(session.scope))
            phase = .unavailable(failure, nil)
        } else {
            phase = .unavailable(SessionFailure(message: message), nil)
        }
        // Attempt teardown even when an acknowledgment was lost. Do not wait
        // beyond the overall deadline or turn a late acknowledgment into success.
        if let release = allocateOperation() { effects.append(.releaseResources(release)) }
        finishShutdown(.failed(message))
    }

    private mutating func finishShutdown(_ outcome: ShutdownOutcome) {
        lifecycle = .stopped(outcome)
        controllers.removeAll()
        resetMovement()
        pointer = PointerState()
        outputs.append(.shutdownCompleted(outcome))
    }
}
