public func update(_ model: Model, _ event: Event) -> Transition {
    var change = Change(model)
    change.accept(event)
    return change.result
}

// Local mutable construction of a new value; never shared with the caller.
struct Change {
    let menu: Menu
    var phase: Phase
    var controllers: [ConnectionID: ControllerState]
    var running: Bool
    var nextSession: UInt64
    var nextOperation: UInt64
    var movement: MovementState
    let movementSettings: MovementSettings
    var effects: [Effect] = []
    var outputs: [Output] = []

    init(_ model: Model) {
        menu = model.menu; phase = model.phase; controllers = model.controllers; running = model.running
        nextSession = model.nextSession; nextOperation = model.nextOperation
        movement = model.movement; movementSettings = model.movementSettings
    }
    var result: Transition {
        Transition(model: Model(menu: menu, phase: phase, controllers: controllers, running: running,
                                nextSession: nextSession, nextOperation: nextOperation,
                                movement: movement, movementSettings: movementSettings),
                   effects: effects, outputs: outputs)
    }

    mutating func allocateOperation() -> OperationID? {
        guard nextOperation < UInt64.max else { exhaustIdentities(); return nil }
        let operation = OperationID(nextOperation)
        nextOperation += 1
        return operation
    }

    mutating func exhaustIdentities() {
        let failure = SessionFailure(message: "Identity counter exhausted")
        if let session = phase.session {
            outputs.append(.completed(session.scope.session, .failed(failure)))
            effects.append(.endInput(session.scope))
        }
        phase = .unavailable(failure, nil)
        resetMovement()
    }

    mutating func accept(_ event: Event) {
        switch event {
        case .start: break
        case .stop:
            running = false
            if let session = phase.session { cancel(session.scope, .applicationStopping) }
        case .open(let owner): open(owner)
        case .select(let scope, let item, let source): select(scope, item, source)
        case .step(let scope, let direction): step(scope, direction)
        case .activate(let scope, let item, let source):
            guard active(scope)?.menu.items.contains(where: { $0.id == item }) == true else { return }
            select(scope, item, source)
            confirm(scope)
        case .confirm(let scope): confirm(scope)
        case .back(let scope): back(scope)
        case .cancel(let scope, let reason): cancel(scope, reason)
        case .focusLost(let scope):
            if active(scope) != nil { cancel(scope, .focusLost) }
        case .layoutUnavailable(let scope): cancel(scope, .layoutUnavailable)
        case .contentReady(let scope):
            guard case .presenting(let session, let operation) = phase, session.scope == scope else { return }
            effects.append(.inspectPresentation(scope, operation))
        case .presented(let operation):
            guard case .presenting(let session, operation) = phase else { return }
            phase = .active(session)
            effects.append(.baseline(session.scope))
        case .dismissed(let operation):
            guard case .dismissing(let session, operation, let outcome) = phase else { return }
            phase = .idle
            outputs.append(.completed(session.scope.session, outcome.cleanedUp()))
        case .deadline(let operation):
            movementFailed(operation, "Window movement timed out")
            failed(operation, "Native operation timed out")
        case .operationFailed(let operation, let message):
            movementFailed(operation, message)
            failed(operation, message)
        case .recover:
            guard case .unavailable(let failure, nil) = phase, let operation = allocateOperation() else { return }
            phase = .unavailable(failure, operation)
            effects.append(.recover(operation))
        case .recovered(let operation):
            guard case .unavailable(_, operation?) = phase else { return }
            phase = .idle
        case .connected(let info, let frame):
            controllers[info.id] = ControllerState(info: info, frame: frame.isValid ? frame : nil)
            if case .active(let session) = phase { effects.append(.baseline(session.scope)) }
        case .disconnected(let connection):
            controllers.removeValue(forKey: connection)
            if let session = phase.session, session.owner == connection { cancel(session.scope, .controllerLost) }
        case .baseline(let connection, let scope, let frame): baseline(connection, scope, frame)
        case .controllerFrame(let connection, let scope, let frame, let continuous):
            controllerFrame(connection, scope, frame, continuous)
        case .inputLost(let connection): lostInput(connection)
        case .placementObserved(let scope, let placement): placementObserved(scope, placement)
        case .movementTick(let id, let time): movementTick(id, time)
        case .moved(let scope, let operation, let placement): moved(scope, operation, placement)
        }
    }

    func active(_ scope: InputScope) -> Session? {
        guard case .active(let session) = phase, session.scope == scope else { return nil }
        return session
    }

    mutating func open(_ owner: ConnectionID?) {
        guard running else { outputs.append(.rejected(.stopped)); return }
        if case .unavailable = phase { outputs.append(.rejected(.unavailable)); return }
        guard case .idle = phase else { outputs.append(.rejected(.busy)); return }
        if let owner, controllers[owner]?.info.supported != true {
            outputs.append(.rejected(.unsupportedController)); return
        }
        guard nextSession < UInt64.max else { exhaustIdentities(); outputs.append(.rejected(.unavailable)); return }
        guard let operation = allocateOperation() else { outputs.append(.rejected(.unavailable)); return }
        let scope = InputScope(session: SessionID(nextSession), revision: 1)
        nextSession += 1
        let session = Session(scope: scope, path: [menu], selection: nil, owner: owner)
        resetMovement()
        phase = .presenting(session, operation)
        effects.append(.present(scope, operation))
    }

    mutating func select(_ scope: InputScope, _ item: String?, _ source: SelectionSource) {
        guard let session = active(scope) else { return }
        if let item, !session.menu.items.contains(where: { $0.id == item }) { return }
        if item == nil, session.selection?.source != source { return }
        phase = .active(session.selecting(item.map { Selection(itemID: $0, source: source) }))
    }

    mutating func step(_ scope: InputScope, _ direction: Int) {
        guard let session = active(scope), direction == 1 || direction == -1 else { return }
        let count = session.menu.items.count
        let previous = session.menu.items.firstIndex { $0.id == session.selection?.itemID }
        let index = previous.map { ($0 + direction + count) % count } ?? (direction == 1 ? 0 : count - 1)
        select(scope, session.menu.items[index].id, .keyboard)
    }

    mutating func confirm(_ scope: InputScope) {
        guard let session = active(scope),
              let item = session.menu.items.first(where: { $0.id == session.selection?.itemID }) else { return }
        switch item.destination {
        case .menu(let child): navigate(session, path: session.path + [child])
        case .value(let value):
            dismiss(session, .selected(Choice(menuPath: session.path.map(\.id), itemID: item.id, value: value)))
        }
    }

    mutating func back(_ scope: InputScope) {
        guard let session = active(scope) else { return }
        if session.path.count > 1 { navigate(session, path: Array(session.path.dropLast())) }
        else { dismiss(session, .cancelled(.user)) }
    }

    mutating func navigate(_ session: Session, path: [Menu]) {
        guard session.scope.revision < UInt64.max else { exhaustIdentities(); return }
        guard let operation = allocateOperation() else { return }
        resetMovement(keepingPlacement: true)
        let scope = InputScope(session: session.scope.session, revision: session.scope.revision + 1)
        phase = .presenting(Session(scope: scope, path: path, selection: nil, owner: session.owner), operation)
        effects += [.endInput(session.scope), .present(scope, operation)]
    }

    mutating func cancel(_ scope: InputScope, _ reason: CancellationReason) {
        guard let session = phase.session, session.scope == scope else { return }
        switch phase {
        case .active, .presenting: dismiss(session, .cancelled(reason))
        default: break
        }
    }

    mutating func dismiss(_ session: Session, _ outcome: Outcome) {
        guard let operation = allocateOperation() else { return }
        resetMovement()
        phase = .dismissing(session, operation, outcome)
        effects += [.endInput(session.scope), .dismiss(session.scope, operation)]
    }

    mutating func failed(_ operation: OperationID, _ message: String) {
        guard phase.operation == operation else { return }
        switch phase {
        case .presenting(let session, _):
            dismiss(session, .failed(SessionFailure(message: message)))
        case .dismissing(let session, _, let outcome):
            let failure = SessionFailure(message: message, committedChoice: outcome.choice)
            phase = .unavailable(failure, nil)
            outputs.append(.completed(session.scope.session, .failed(failure)))
        case .unavailable(let failure, _):
            phase = .unavailable(SessionFailure(message: message, committedChoice: failure.committedChoice), nil)
        default: break
        }
    }
}
