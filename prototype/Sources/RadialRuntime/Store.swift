import Observation
import RadialCore

@Observable @MainActor public final class Store {
    public private(set) var model: Model
    public private(set) var view: RenderModel
    public private(set) var outputs: [Output] = []
    public private(set) var trace: [String] = []
    @ObservationIgnored public var onOutput: ((Output) -> Void)?
    @ObservationIgnored public var onTransition: ((Event, Transition) -> Void)?
    @ObservationIgnored private let window: any WindowDriver
    @ObservationIgnored private let controller: any ControllerDriver
    @ObservationIgnored private let scheduler: any DeadlineScheduler
    @ObservationIgnored private let movementClock: any MovementScheduler
    @ObservationIgnored private var pending: [Event] = []
    @ObservationIgnored private var lostConnections: Set<ConnectionID> = []
    @ObservationIgnored private var draining = false
    @ObservationIgnored private var activeSubscriptions: Set<Subscription> = []
    @ObservationIgnored private let inputCapacity: Int

    public init(menu: Menu, window: any WindowDriver, controller: any ControllerDriver,
                scheduler: any DeadlineScheduler, movementClock: any MovementScheduler, inputCapacity: Int = 256) {
        precondition(inputCapacity > 0)
        let initial = Model(menu: menu)
        self.model = initial
        self.view = render(initial)
        self.window = window; self.controller = controller; self.scheduler = scheduler
        self.movementClock = movementClock
        self.inputCapacity = inputCapacity
        window.receive = { [weak self] in self?.send($0) }
        controller.receive = { [weak self] in self?.send($0) }
    }

    public func send(_ event: Event) { send([event]) }

    public func send(_ events: [Event]) {
        for event in events {
            if case .controllerFrame(let connection, _, _, _) = event {
                if lostConnections.contains(connection) { continue }
                let queuedInputs = pending.filter { if case .controllerFrame = $0 { true } else { false } }.count
                if queuedInputs >= inputCapacity {
                    pending.removeAll { if case .controllerFrame(connection, _, _, _) = $0 { true } else { false } }
                    lostConnections.insert(connection)
                    continue
                }
            }
            pending.append(event)
        }
        guard !draining else { return }
        draining = true
        defer { draining = false }
        while !pending.isEmpty || !lostConnections.isEmpty {
            let event: Event
            if let connection = lostConnections.sorted().first {
                lostConnections.remove(connection)
                event = .inputLost(connection)
            } else { event = pending.removeFirst() }
            let before = model.phase.name
            let transition = update(model, event)
            model = transition.model
            view = render(model)
            record("\(Self.name(event)): \(before) → \(model.phase.name)")
            onTransition?(event, transition)
            reconcile()
            for effect in transition.effects { dispatch(effect) }
            for output in transition.outputs {
                outputs.append(output)
                if outputs.count > 32 { outputs.removeFirst(outputs.count - 32) }
                onOutput?(output)
            }
        }
    }

    private func reconcile() {
        let required = subscriptions(model)
        let removed = activeSubscriptions.subtracting(required)
        let added = required.subtracting(activeSubscriptions)
        // Commit ownership before a synchronous resource callback can enqueue an event.
        activeSubscriptions = required
        for subscription in removed {
            switch subscription {
            case .controllers: controller.stop()
            case .deadline(let operation): scheduler.cancel(operation: operation)
            case .movement(let id): movementClock.stopMovement(id: id)
            }
        }
        for subscription in added {
            switch subscription {
            case .controllers: controller.start()
            case .deadline(let operation):
                scheduler.schedule(operation: operation, after: 3) { [weak self] in self?.send($0) }
            case .movement(let id):
                movementClock.startMovement(id: id) { [weak self] in self?.send($0) }
            }
        }
    }

    private func dispatch(_ effect: Effect) {
        switch effect {
        case .present(let scope, let operation): window.present(scope: scope, operation: operation)
        case .inspectPresentation(let scope, let operation): window.inspectPresentation(scope: scope, operation: operation)
        case .dismiss(let scope, let operation): window.dismiss(scope: scope, operation: operation)
        case .recover(let operation): window.recover(operation: operation)
        case .baseline(let scope): controller.baseline(scope: scope)
        case .endInput(let scope): controller.endInput(scope: scope)
        case .resetInput(let connection): controller.resetInput(connection: connection)
        case .move(let scope, let placement, let operation): window.move(scope: scope, placement: placement, operation: operation)
        }
    }

    private func record(_ message: String) {
        trace.append(message)
        if trace.count > 256 { trace.removeFirst(trace.count - 256) }
    }

    private static func name(_ event: Event) -> String {
        // Avoid writing complete menus, values, or raw controller samples to diagnostics.
        switch event {
        case .controllerFrame(let connection, _, let frame, _): "Input \(connection.value):\(frame.sequence)"
        case .baseline(let connection, _, _): "Baseline \(connection.value)"
        case .connected(let info, _): "Connected \(info.id.value)"
        default: String(describing: event).prefix(120).description
        }
    }
}
