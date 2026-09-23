public struct MovementSettings: Equatable, Sendable {
    public let speed: Double
    public let deadZone: Double
    public let maximumStep: Double

    public init(speed: Double, deadZone: Double, maximumStep: Double) throws {
        guard speed.isFinite, speed > 0, deadZone.isFinite, (0..<1).contains(deadZone),
              maximumStep.isFinite, maximumStep > 0, (speed * maximumStep).isFinite else { throw InvalidSettings() }
        self.speed = speed
        self.deadZone = deadZone
        self.maximumStep = maximumStep
    }

    public struct InvalidSettings: Error {}
    public static let standard: Self = {
        do { return try Self(speed: 600, deadZone: 0.2, maximumStep: 0.1) }
        catch { preconditionFailure("Invalid built-in movement settings") }
    }()

    /// Desktop velocity in logical points per second; positive y points up.
    public func velocity(for stick: Vector) -> Vector {
        guard stick.isFinite, abs(stick.x) <= 1, abs(stick.y) <= 1 else { return .zero }
        let magnitude = stick.magnitude
        guard magnitude > deadZone else { return .zero }
        let rate = speed * ((min(magnitude, 1) - deadZone) / (1 - deadZone))
        return Vector(x: stick.x / magnitude * rate, y: stick.y / magnitude * rate)
    }
}

/// An observed desktop frame and the usable bounds of its assigned screen.
public struct Placement: Equatable, Sendable {
    public let layout: UInt64
    public let screenID: String
    public let bounds: Rect
    public let frame: Rect

    public init(layout: UInt64, screenID: String, bounds: Rect, frame: Rect) {
        self.layout = layout; self.screenID = screenID; self.bounds = bounds; self.frame = frame
    }

    public var isValid: Bool {
        layout > 0 && !screenID.isEmpty && frame.clamped(to: bounds) == frame
    }

    public func replacingFrame(_ frame: Rect) -> Self {
        Self(layout: layout, screenID: screenID, bounds: bounds, frame: frame)
    }
}

extension Rect {
    public func clamped(to bounds: Rect) -> Rect? {
        guard [x, y, width, height, bounds.x, bounds.y, bounds.width, bounds.height].allSatisfy(\.isFinite),
              width > 0, height > 0, bounds.width >= width, bounds.height >= height,
              (bounds.x + bounds.width).isFinite, (bounds.y + bounds.height).isFinite else { return nil }
        return Rect(x: min(max(x, bounds.x), bounds.x + bounds.width - width),
                    y: min(max(y, bounds.y), bounds.y + bounds.height - height), width: width, height: height)
    }
}

public struct MovementID: Hashable, Sendable {
    public let scope: InputScope
    public let connection: ConnectionID
    public let sequence: UInt64
    public init(scope: InputScope, connection: ConnectionID, sequence: UInt64) {
        self.scope = scope; self.connection = connection; self.sequence = sequence
    }
}

public struct MovementActivity: Equatable, Sendable {
    public let id: MovementID
    public let velocity: Vector
    public let time: Double
}

public struct PendingMovement: Equatable, Sendable {
    public let operation: OperationID
    public let target: Rect
}

public struct MovementState: Equatable, Sendable {
    public let placement: Placement?
    public let desired: Rect?
    public let activity: MovementActivity?
    public let pending: PendingMovement?

    init(placement: Placement? = nil, desired: Rect? = nil,
         activity: MovementActivity? = nil, pending: PendingMovement? = nil) {
        self.placement = placement; self.desired = desired
        self.activity = activity; self.pending = pending
    }
}

extension Change {
    mutating func resetMovement(keepingPlacement: Bool = false) {
        let placement = keepingPlacement ? movement.placement : nil
        movement = MovementState(placement: placement, desired: placement?.frame)
    }

    mutating func placementObserved(_ scope: InputScope, _ placement: Placement) {
        guard phase.session?.scope == scope else { return }
        switch phase { case .active, .presenting: break; default: return }
        guard placement.isValid else { cancel(scope, .layoutUnavailable); return }
        guard movement.placement.map({ placement.layout > $0.layout }) ?? true else { return }
        movement = MovementState(placement: placement, desired: placement.frame)
        if phase.isActive { effects.append(.baseline(scope)) }
    }

    mutating func movementInput(_ connection: ConnectionID, _ scope: InputScope,
                                _ frame: ControllerFrame, armed: Bool) {
        guard active(scope) != nil, movement.placement != nil else { return }
        let velocity = armed ? movementSettings.velocity(for: frame.rightStick) : .zero
        let oldActivity = movement.activity
        if let oldActivity, frame.observedAt < oldActivity.time { return }
        advanceMovement(to: frame.observedAt)
        let id = oldActivity?.id ?? MovementID(scope: scope, connection: connection, sequence: frame.sequence)
        let activity = velocity == .zero ? nil : MovementActivity(id: id, velocity: velocity, time: frame.observedAt)
        movement = MovementState(placement: movement.placement, desired: movement.desired,
                                 activity: activity, pending: movement.pending)
        // A stop supersedes any pending move. Its newer operation also prevents
        // an already queued native command from taking effect after release.
        requestMovement(scope, superseding: oldActivity != nil && activity == nil)
    }

    mutating func movementTick(_ id: MovementID, _ time: Double) {
        guard active(id.scope) != nil, movement.activity?.id == id,
              time.isFinite, time > (movement.activity?.time ?? time) else { return }
        advanceMovement(to: time)
        requestMovement(id.scope)
    }

    private mutating func advanceMovement(to time: Double) {
        guard let activity = movement.activity, let placement = movement.placement,
              let desired = movement.desired, time.isFinite, time > activity.time else { return }
        let elapsed = min(time - activity.time, movementSettings.maximumStep)
        let candidate = Rect(x: desired.x + activity.velocity.x * elapsed,
                             y: desired.y + activity.velocity.y * elapsed,
                             width: desired.width, height: desired.height)
        guard let frame = candidate.clamped(to: placement.bounds) else { return }
        movement = MovementState(placement: placement, desired: frame,
            activity: MovementActivity(id: activity.id, velocity: activity.velocity, time: time), pending: movement.pending)
    }

    private mutating func requestMovement(_ scope: InputScope, superseding: Bool = false) {
        guard let placement = movement.placement, let target = movement.desired,
              superseding || (movement.pending == nil && target != placement.frame),
              let operation = allocateOperation() else { return }
        movement = MovementState(placement: placement, desired: target, activity: movement.activity,
                                 pending: PendingMovement(operation: operation, target: target))
        effects.append(.move(scope, placement.replacingFrame(target), operation))
    }

    mutating func moved(_ scope: InputScope, _ operation: OperationID, _ observed: Placement) {
        guard active(scope) != nil, let pending = movement.pending, pending.operation == operation,
              let previous = movement.placement, let desired = movement.desired,
              observed.layout == previous.layout else { return }
        guard observed.isValid, observed.screenID == previous.screenID, observed.bounds == previous.bounds,
              observed.frame.width == previous.frame.width, observed.frame.height == previous.frame.height else {
            movementFailed(operation, "Invalid native movement acknowledgment"); return
        }
        // Preserve displacement accumulated while this one native request was outstanding.
        let accumulated = Rect(x: observed.frame.x + (desired.x - pending.target.x),
                               y: observed.frame.y + (desired.y - pending.target.y),
                               width: desired.width, height: desired.height)
        movement = MovementState(placement: observed, desired: accumulated.clamped(to: observed.bounds),
                                 activity: movement.activity)
        requestMovement(scope)
    }

    mutating func movementFailed(_ operation: OperationID, _ message: String) {
        guard movement.pending?.operation == operation, let session = phase.session else { return }
        dismiss(session, .failed(SessionFailure(message: message)))
    }
}
