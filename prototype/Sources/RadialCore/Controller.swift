import Foundation

public enum ControllerButton: Hashable, Sendable { case menu, confirm, back, previous, next }
public struct ControllerInfo: Equatable, Sendable {
    public let id: ConnectionID
    public let name: String
    public let supported: Bool
    public let detail: String
    public let supportsMovement: Bool
    public init(id: ConnectionID, name: String, supported: Bool, detail: String = "", supportsMovement: Bool = false) {
        self.id = id; self.name = name; self.supported = supported; self.detail = detail
        self.supportsMovement = supportsMovement
    }
}
public struct ControllerFrame: Equatable, Sendable {
    public let sequence: UInt64
    public let timestamp: Double
    public let stick: Vector
    public let buttons: Set<ControllerButton>
    public let rightStick: Vector
    /// Adapter receipt time, using the same monotonic clock as movement ticks.
    public let observedAt: Double
    public init(sequence: UInt64, timestamp: Double, stick: Vector, buttons: Set<ControllerButton>,
                rightStick: Vector = .zero, observedAt: Double) {
        self.sequence = sequence; self.timestamp = timestamp; self.stick = stick; self.buttons = buttons
        self.rightStick = rightStick; self.observedAt = observedAt
    }
    public var isValid: Bool {
        timestamp.isFinite && timestamp >= 0 && observedAt.isFinite && observedAt >= 0 &&
            stick.isFinite && abs(stick.x) <= 1 && abs(stick.y) <= 1 &&
            rightStick.isFinite && abs(rightStick.x) <= 1 && abs(rightStick.y) <= 1
    }
}
public struct ControllerState: Equatable, Sendable {
    public let info: ControllerInfo
    public let frame: ControllerFrame?
    public let baselineScope: InputScope?
    public let analogArmed: Bool
    public let analogActive: Bool
    public let anchor: Vector
    public let movementArmed: Bool
    init(info: ControllerInfo, frame: ControllerFrame?, baselineScope: InputScope? = nil,
         analogArmed: Bool = false, analogActive: Bool = false, anchor: Vector = .zero, movementArmed: Bool = false) {
        self.info = info; self.frame = frame; self.baselineScope = baselineScope
        self.analogArmed = analogArmed; self.analogActive = analogActive; self.anchor = anchor
        self.movementArmed = movementArmed
    }
}

extension Change {
    mutating func baseline(_ connection: ConnectionID, _ scope: InputScope?, _ frame: ControllerFrame) {
        guard let old = controllers[connection], frame.isValid,
              old.frame.map({ frame.sequence > $0.sequence }) ?? true else { return }
        if let scope, active(scope) == nil { return }
        if let scope, movement.activity?.id.connection == connection {
            movementInput(connection, scope, frame, armed: false)
        }
        controllers[connection] = ControllerState(info: old.info, frame: frame, baselineScope: scope,
            analogArmed: frame.stick.magnitude <= 0.2, anchor: frame.stick,
            movementArmed: frame.rightStick.magnitude <= movementSettings.deadZone)
    }

    mutating func lostInput(_ connection: ConnectionID) {
        guard let old = controllers[connection] else { return }
        controllers[connection] = ControllerState(info: old.info, frame: nil)
        effects.append(.resetInput(connection))
        if let session = phase.session, session.owner == connection { cancel(session.scope, .inputLost) }
    }

    mutating func controllerFrame(_ connection: ConnectionID, _ scope: InputScope?,
                                  _ frame: ControllerFrame, _ continuous: Bool) {
        guard let old = controllers[connection] else { return }
        if let previous = old.frame, frame.sequence <= previous.sequence { return }
        guard continuous, frame.isValid else { lostInput(connection); return }
        if let previous = old.frame, frame.timestamp < previous.timestamp || frame.observedAt < previous.observedAt {
            lostInput(connection); return
        }
        guard let previous = old.frame else {
            controllers[connection] = ControllerState(info: old.info, frame: frame)
            return
        }
        let edges = frame.buttons.subtracting(previous.buttons)
        var armed = old.analogArmed
        var analogActive = old.analogActive
        var anchor = old.anchor
        let magnitude = frame.stick.magnitude
        if magnitude <= 0.2 { armed = true; analogActive = false }
        else if armed && magnitude > (old.analogActive ? 0.2 : 0.3) { analogActive = true }
        let moved = analogActive && (!old.analogActive || frame.stick.distance(to: old.anchor) >= 0.05)
        if moved || !analogActive { anchor = frame.stick }
        let movementArmed = old.movementArmed || frame.rightStick.magnitude <= movementSettings.deadZone
        controllers[connection] = ControllerState(info: old.info, frame: frame,
            baselineScope: old.baselineScope, analogArmed: armed, analogActive: analogActive, anchor: anchor,
            movementArmed: movementArmed)
        guard old.info.supported else { return }

        if case .idle = phase {
            if edges.contains(.menu) && !edges.contains(.back) { open(connection) }
            return
        }
        guard let session = phase.session, session.owner == nil || session.owner == connection else { return }
        // Cancelling an opening menu remains possible, but cannot confirm it.
        if phase.isPreparingOrPresenting {
            if edges.contains(.menu), scope == nil || scope == session.scope { cancel(session.scope, .user) }
            return
        }
        guard phase.isActive, scope == session.scope, old.baselineScope == session.scope else { return }
        let rightActive = old.info.supportsMovement && movementArmed &&
            frame.rightStick.magnitude > movementSettings.deadZone
        let relevant = !edges.isEmpty || moved || rightActive
        if session.owner == nil && relevant { phase = .active(session.owned(by: connection)) }
        if edges.contains(.back) { back(session.scope); return }
        if edges.contains(.menu) { cancel(session.scope, .user); return }
        if edges.contains(.next) != edges.contains(.previous) {
            step(session.scope, edges.contains(.next) ? 1 : -1)
        } else if session.browsingChoices {
            // One row per vertical tilt; neutral release rearms the next step.
            if moved && !old.analogActive && abs(frame.stick.y) > 0.3 {
                stepChoice(session.scope, frame.stick.y > 0 ? -1 : 1)
            }
        } else if moved, let index = Geometry.sector(angle: atan2(frame.stick.x, frame.stick.y),
                                                    count: session.menu.items.count) {
            select(session.scope, session.menu.items[index].id, .stick)
        } else if old.analogActive && !analogActive {
            select(session.scope, nil, .stick)
        }
        if edges.contains(.confirm) { confirm(session.scope) }
        if old.info.supportsMovement {
            movementInput(connection, session.scope, frame, armed: movementArmed)
        }
    }
}
