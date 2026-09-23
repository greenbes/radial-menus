public struct SessionID: Hashable, Sendable {
    public let value: UInt64
    public init(_ value: UInt64) { self.value = value }
}
public struct OperationID: Hashable, Sendable, Comparable {
    public let value: UInt64
    public init(_ value: UInt64) { self.value = value }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.value < rhs.value }
}
public struct ConnectionID: Hashable, Sendable, Comparable {
    public let value: UInt64
    public init(_ value: UInt64) { self.value = value }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.value < rhs.value }
}
public struct InputScope: Hashable, Sendable {
    public let session: SessionID
    public let revision: UInt64
    public init(session: SessionID, revision: UInt64) { self.session = session; self.revision = revision }
}
public enum SelectionSource: Equatable, Sendable { case stick, keyboard, pointer, accessibility }
public struct Selection: Equatable, Sendable { public let itemID: String; public let source: SelectionSource }
public struct Choice: Equatable, Sendable {
    public let menuPath: [String]
    public let itemID: String
    public let value: String
    public init(menuPath: [String], itemID: String, value: String) {
        self.menuPath = menuPath; self.itemID = itemID; self.value = value
    }
}
public enum CancellationReason: String, Equatable, Sendable {
    case user, controllerLost, inputLost, focusLost, applicationStopping, layoutUnavailable
}
public struct SessionFailure: Equatable, Sendable {
    public let message: String
    public let committedChoice: Choice?
    public let cleanupConfirmed: Bool
    public init(message: String, committedChoice: Choice? = nil, cleanupConfirmed: Bool = false) {
        self.message = message; self.committedChoice = committedChoice; self.cleanupConfirmed = cleanupConfirmed
    }
}
public enum Outcome: Equatable, Sendable {
    case selected(Choice), cancelled(CancellationReason), failed(SessionFailure)
    var choice: Choice? { if case .selected(let choice) = self { choice } else { nil } }
    func cleanedUp() -> Outcome {
        guard case .failed(let failure) = self else { return self }
        return .failed(SessionFailure(message: failure.message, committedChoice: failure.committedChoice,
                                      cleanupConfirmed: true))
    }
}
public enum Rejection: String, Equatable, Sendable { case busy, unavailable, stopped, unsupportedController }
public enum Output: Equatable, Sendable { case rejected(Rejection), completed(SessionID, Outcome) }

public struct Session: Equatable, Sendable {
    public let scope: InputScope
    public let path: [Menu]
    public let selection: Selection?
    public let owner: ConnectionID?
    public var menu: Menu { path[path.count - 1] }
    func selecting(_ value: Selection?) -> Self { Self(scope: scope, path: path, selection: value, owner: owner) }
    func owned(by owner: ConnectionID) -> Self { Self(scope: scope, path: path, selection: selection, owner: owner) }
}

public enum Phase: Equatable, Sendable {
    case idle
    case presenting(Session, OperationID)
    case active(Session)
    case dismissing(Session, OperationID, Outcome)
    case unavailable(SessionFailure, OperationID?)

    public var session: Session? {
        switch self {
        case .presenting(let session, _), .active(let session), .dismissing(let session, _, _): session
        default: nil
        }
    }
    public var isActive: Bool { if case .active = self { true } else { false } }
    public var name: String {
        switch self {
        case .idle: "Idle"
        case .presenting: "Presenting"
        case .active: "Active"
        case .dismissing: "Dismissing"
        case .unavailable: "Unavailable"
        }
    }
    public var operation: OperationID? {
        switch self {
        case .presenting(_, let operation), .dismissing(_, let operation, _): operation
        case .unavailable(_, let operation): operation
        default: nil
        }
    }
}

public struct Model: Equatable, Sendable {
    public let menu: Menu
    public let phase: Phase
    public let controllers: [ConnectionID: ControllerState]
    public let running: Bool
    public let movement: MovementState
    public let movementSettings: MovementSettings
    public let pointer: PointerState
    public let pointerSettings: PointerSettings
    let nextSession: UInt64
    let nextOperation: UInt64

    public init(menu: Menu, movementSettings: MovementSettings = .standard,
                pointerSettings: PointerSettings = .standard) {
        self.init(menu: menu, phase: .idle, controllers: [:], running: true, nextSession: 1, nextOperation: 1,
                  movementSettings: movementSettings, pointerSettings: pointerSettings)
    }
    public var canOpen: Bool { if case .idle = phase { running } else { false } }
    public var canRecover: Bool { if case .unavailable(_, nil) = phase { true } else { false } }
    init(menu: Menu, phase: Phase, controllers: [ConnectionID: ControllerState], running: Bool,
         nextSession: UInt64, nextOperation: UInt64, movement: MovementState = MovementState(),
         movementSettings: MovementSettings = .standard, pointer: PointerState = PointerState(),
         pointerSettings: PointerSettings = .standard) {
        self.menu = menu; self.phase = phase; self.controllers = controllers; self.running = running
        self.nextSession = nextSession; self.nextOperation = nextOperation
        self.movement = movement; self.movementSettings = movementSettings
        self.pointer = pointer; self.pointerSettings = pointerSettings
    }
}

public enum Event: Equatable, Sendable {
    case start, stop, open(ConnectionID?), recover
    case select(InputScope, String?, SelectionSource), step(InputScope, Int)
    case activate(InputScope, String, SelectionSource), confirm(InputScope), back(InputScope)
    case cancel(InputScope, CancellationReason), focusLost(InputScope), layoutUnavailable(InputScope)
    case contentReady(InputScope), presented(OperationID), dismissed(OperationID), recovered(OperationID)
    case operationFailed(OperationID, String), deadline(OperationID)
    case connected(ControllerInfo, ControllerFrame), disconnected(ConnectionID)
    case baseline(ConnectionID, InputScope?, ControllerFrame)
    case controllerFrame(ConnectionID, InputScope?, ControllerFrame, Bool)
    case inputLost(ConnectionID)
    case placementObserved(InputScope, Placement)
    case movementTick(MovementID, Double), moved(InputScope, OperationID, Placement)
    case pointerBaseline(InputScope, PointerSample), pointerMoved(InputScope, PointerSample)
}
public enum Effect: Equatable, Sendable {
    case present(InputScope, OperationID), inspectPresentation(InputScope, OperationID)
    case dismiss(InputScope, OperationID), recover(OperationID)
    case baseline(InputScope), endInput(InputScope), resetInput(ConnectionID)
    case move(InputScope, Placement, OperationID)
}
public enum Subscription: Hashable, Sendable { case controllers, deadline(OperationID), movement(MovementID) }
public struct Transition: Equatable, Sendable {
    public let model: Model
    public let effects: [Effect]
    public let outputs: [Output]
}

public struct RenderModel: Equatable, Sendable {
    public let scope: InputScope?
    public let title: String
    public let items: [Item]
    public let sectors: [Sector]
    public let selectedID: String?
    public let acceptsInput: Bool
    public let canGoBack: Bool
}

public func render(_ model: Model) -> RenderModel {
    let session = model.phase.session
    let items = session?.menu.items ?? []
    return RenderModel(scope: session?.scope, title: session?.menu.title ?? "Radial Menu",
                       items: items, sectors: Geometry.sectors(count: items.count),
                       selectedID: session?.selection?.itemID, acceptsInput: model.phase.isActive,
                       canGoBack: (session?.path.count ?? 0) > 1)
}

public func subscriptions(_ model: Model) -> Set<Subscription> {
    var result: Set<Subscription> = model.running ? [.controllers] : []
    if let operation = model.phase.operation { result.insert(.deadline(operation)) }
    if model.running, model.phase.isActive {
        if let activity = model.movement.activity { result.insert(.movement(activity.id)) }
        if let pending = model.movement.pending { result.insert(.deadline(pending.operation)) }
    }
    return result
}
