import Foundation
import GameController
import RadialCore
import RadialRuntime

/// All native input access and callbacks use the main serial queue.
@MainActor public final class ControllerAdapter: ControllerDriver {
    public var receive: EventReceiver?
    private struct Connection {
        let controller: GCController
        let info: ControllerInfo
        var sequence: UInt64
        var scope: InputScope?
    }
    private var connections: [ConnectionID: Connection] = [:]
    private var observers: [NSObjectProtocol] = []
    private var nextID: UInt64 = 1
    private var monitoring = false
    private var previousBackgroundMonitoring = false

    public init() {}
    public var hasNativeResources: Bool { monitoring || !observers.isEmpty || !connections.isEmpty }
    public var backgroundMonitoringRestored: Bool {
        !monitoring && GCController.shouldMonitorBackgroundEvents == previousBackgroundMonitoring
    }

    public func start() {
        guard !monitoring else { return }
        monitoring = true
        previousBackgroundMonitoring = GCController.shouldMonitorBackgroundEvents
        GCController.shouldMonitorBackgroundEvents = true
        observers.append(NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] notification in
            let identity = (notification.object as? GCController).map(ObjectIdentifier.init)
            MainActor.assumeIsolated {
                if let controller = GCController.controllers().first(where: { ObjectIdentifier($0) == identity }) {
                    self?.connect(controller)
                }
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect, object: nil, queue: .main
        ) { [weak self] notification in
            let identity = (notification.object as? GCController).map(ObjectIdentifier.init)
            MainActor.assumeIsolated {
                guard let self, let id = self.connections.first(where: {
                    ObjectIdentifier($0.value.controller) == identity
                })?.key else { return }
                self.connections[id]?.controller.input.inputStateAvailableHandler = nil
                self.connections.removeValue(forKey: id)
                self.receive?(.disconnected(id))
            }
        })
        for controller in GCController.controllers() { connect(controller) }
    }

    public func stop() {
        guard monitoring else { return }
        monitoring = false
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        for connection in connections.values { connection.controller.input.inputStateAvailableHandler = nil }
        let removed = connections.keys.sorted()
        connections.removeAll()
        GCController.shouldMonitorBackgroundEvents = previousBackgroundMonitoring
        for id in removed { receive?(.disconnected(id)) }
    }

    public func baseline(scope: InputScope) {
        for id in connections.keys.sorted() { establishBaseline(id, scope: scope) }
    }

    public func endInput(scope: InputScope) {
        for id in connections.keys.sorted() where connections[id]?.scope == scope {
            connections[id]?.scope = nil
        }
    }

    public func resetInput(connection: ConnectionID) { establishBaseline(connection, scope: nil) }

    private func connect(_ controller: GCController) {
        guard monitoring, !connections.values.contains(where: { $0.controller === controller }),
              nextID < UInt64.max else { return }
        let id = ConnectionID(nextID)
        nextID += 1
        let input = controller.input
        input.queue = .main
        input.inputStateQueueDepth = 64
        let hasStick = input.dpads[GCInputLeftThumbstick] != nil
        let hasConfirm = input.buttons[GCInputButtonA] != nil
        let hasBack = input.buttons[GCInputButtonB] != nil
        let hasMenu = input.buttons[GCInputButtonMenu] != nil
        let hasRightStick = input.dpads[GCInputRightThumbstick] != nil
        let detail = "Confirm: \(input.buttons[GCInputButtonA]?.localizedName ?? "missing"); "
            + "Back: \(input.buttons[GCInputButtonB]?.localizedName ?? "missing"); "
            + "Menu: \(hasMenu ? "available" : "use menu bar"); "
            + "Right stick: \(hasRightStick ? "moves menu" : "unavailable"); buffered input"
        let info = ControllerInfo(id: id, name: controller.vendorName ?? "Controller",
                                  supported: hasStick && hasConfirm && hasBack, detail: detail,
                                  supportsMovement: hasRightStick)
        connections[id] = Connection(controller: controller, info: info, sequence: 0, scope: nil)
        while input.nextInputState() != nil { /* Establish a current baseline. */ }
        let frame = Self.decode(input.capture(), sequence: 0, observedAt: ProcessInfo.processInfo.systemUptime)
        receive?(.connected(info, frame))
        input.inputStateAvailableHandler = { [weak self] _ in
            MainActor.assumeIsolated { self?.drain(id) }
        }
    }

    private func establishBaseline(_ id: ConnectionID, scope: InputScope?) {
        guard var connection = connections[id], connection.sequence < UInt64.max else { return }
        let input = connection.controller.input
        while input.nextInputState() != nil { /* These events precede the new menu baseline. */ }
        connection.sequence += 1
        connection.scope = scope
        connections[id] = connection
        receive?(.baseline(id, scope, Self.decode(input.capture(), sequence: connection.sequence,
                                                 observedAt: ProcessInfo.processInfo.systemUptime)))
    }

    private func drain(_ id: ConnectionID) {
        guard monitoring, let native = connections[id]?.controller.input else { return }
        // Yield between batches; unknown changes in the native queue invalidate history.
        for _ in 0..<64 {
            guard let state = native.nextInputState() else { return }
            guard var connection = connections[id], connection.sequence < UInt64.max else { return }
            connection.sequence += 1
            connections[id] = connection
            let elements: [any GCPhysicalInputElement] = [
                state.buttons[GCInputButtonA], state.buttons[GCInputButtonB],
                state.buttons[GCInputButtonMenu], state.dpads[GCInputLeftThumbstick],
                state.dpads[GCInputDirectionPad], state.dpads[GCInputRightThumbstick]
            ].compactMap { $0 }
            let continuous = !elements.contains { state.change(for: $0) == .unknownChange }
            receive?(.controllerFrame(id, connection.scope,
                                     Self.decode(state, sequence: connection.sequence,
                                                 observedAt: ProcessInfo.processInfo.systemUptime), continuous))
            // A synchronous result can change the input scope or remove this connection.
        }
        DispatchQueue.main.async { [weak self] in self?.drain(id) }
    }

    public static func decode(_ state: any GCDevicePhysicalInputState, sequence: UInt64,
                              observedAt: Double) -> ControllerFrame {
        var buttons = Set<ControllerButton>()
        if state.buttons[GCInputButtonA]?.pressedInput.isPressed == true { buttons.insert(.confirm) }
        if state.buttons[GCInputButtonB]?.pressedInput.isPressed == true { buttons.insert(.back) }
        if state.buttons[GCInputButtonMenu]?.pressedInput.isPressed == true { buttons.insert(.menu) }
        if state.dpads[GCInputDirectionPad]?.left.isPressed == true { buttons.insert(.previous) }
        if state.dpads[GCInputDirectionPad]?.right.isPressed == true { buttons.insert(.next) }
        if state.dpads[GCInputDirectionPad]?.up.isPressed == true { buttons.insert(.previous) }
        if state.dpads[GCInputDirectionPad]?.down.isPressed == true { buttons.insert(.next) }
        let stick = state.dpads[GCInputLeftThumbstick]
        let right = state.dpads[GCInputRightThumbstick]
        return ControllerFrame(sequence: sequence, timestamp: state.lastEventTimestamp,
            stick: Vector(x: Double(stick?.xAxis.value ?? 0), y: Double(stick?.yAxis.value ?? 0)), buttons: buttons,
            rightStick: Vector(x: Double(right?.xAxis.value ?? 0), y: Double(right?.yAxis.value ?? 0)),
            observedAt: observedAt)
    }
}
