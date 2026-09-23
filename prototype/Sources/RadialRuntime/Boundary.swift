import RadialCore

public typealias EventReceiver = @MainActor (Event) -> Void

@MainActor public protocol WindowDriver: AnyObject {
    var receive: EventReceiver? { get set }
    func present(scope: InputScope, operation: OperationID)
    func inspectPresentation(scope: InputScope, operation: OperationID)
    func dismiss(scope: InputScope, operation: OperationID)
    func recover(operation: OperationID)
    func move(scope: InputScope, placement: Placement, operation: OperationID)
    func releaseResources(operation: OperationID)
}

@MainActor public protocol MovementScheduler: AnyObject {
    func startMovement(id: MovementID, receive: @escaping EventReceiver)
    func stopMovement(id: MovementID)
}

@MainActor public protocol ControllerDriver: AnyObject {
    var receive: EventReceiver? { get set }
    func start()
    func stop()
    func baseline(scope: InputScope)
    func endInput(scope: InputScope)
    func resetInput(connection: ConnectionID)
}

@MainActor public protocol DeadlineScheduler: AnyObject {
    func schedule(operation: OperationID, after seconds: Double, receive: @escaping EventReceiver)
    func cancel(operation: OperationID)
}
