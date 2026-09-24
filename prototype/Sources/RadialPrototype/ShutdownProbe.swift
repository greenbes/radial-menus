import AppKit
import RadialCore
import RadialMac
import RadialRuntime

/// An explicit test mode: native operations run normally, but selected replies
/// are held so termination can be requested at an otherwise brief boundary.
@MainActor final class ShutdownProbe: WindowDriver {
    enum Stage: String, CaseIterable {
        case idle, preparing, opening, active, moving, dismissing, recovering
        case missingRelease = "missing-release"
    }

    var receive: EventReceiver?
    let stage: Stage
    private let panel: PanelAdapter
    private var held: [Event] = []

    init(stage: Stage, panel: PanelAdapter) {
        self.stage = stage
        self.panel = panel
        panel.receive = { [weak self] in self?.observe($0) }
    }

    func prepare(scope: InputScope, presentation: MenuPresentation, operation: OperationID) {
        panel.prepare(scope: scope, presentation: presentation, operation: operation)
    }
    func present(scope: InputScope, layout: MenuLayout, placement: Placement, operation: OperationID) {
        panel.present(scope: scope, layout: layout, placement: placement, operation: operation)
    }
    func inspectPresentation(scope: InputScope, operation: OperationID) {
        panel.inspectPresentation(scope: scope, operation: operation)
    }
    func dismiss(scope: InputScope, operation: OperationID) { panel.dismiss(scope: scope, operation: operation) }
    func recover(operation: OperationID) { panel.recover(operation: operation) }
    func move(scope: InputScope, placement: Placement, operation: OperationID) {
        panel.move(scope: scope, placement: placement, operation: operation)
    }
    func releaseResources(operation: OperationID) { panel.releaseResources(operation: operation) }

    private func observe(_ event: Event) {
        switch (stage, event) {
        case (.preparing, .prepared), (.opening, .presented), (.dismissing, .dismissed),
             (.recovering, .dismissed), (.recovering, .recovered),
             (.missingRelease, .resourcesReleased): held.append(event)
        default: receive?(event)
        }
    }

    func run(store: Store, log: EventLog, quit: @MainActor () -> Void) async {
        let probe = NativeSmoke(store: store, panel: panel)
        do {
            if stage != .idle && stage != .missingRelease {
                store.send(.open(nil))
                if stage == .opening || stage == .preparing {
                    try await probe.wait("held presentation") { !self.held.isEmpty }
                } else {
                    try await probe.wait("active shutdown fixture") { store.model.phase.isActive }
                }
            }
            switch stage {
            case .moving:
                let scope = try probe.scope()
                let connection = ConnectionID(UInt64.max - 2)
                let now = ProcessInfo.processInfo.systemUptime
                func frame(_ sequence: UInt64, _ right: Vector = .zero) -> ControllerFrame {
                    ControllerFrame(sequence: sequence, timestamp: now, stick: .zero, buttons: [],
                                    rightStick: right, observedAt: ProcessInfo.processInfo.systemUptime)
                }
                store.send(.connected(ControllerInfo(id: connection, name: "Shutdown fixture",
                    supported: true, supportsMovement: true), frame(0)))
                store.send(.baseline(connection, scope, frame(1)))
                guard let placement = store.model.movement.placement else { throw ProbeFailure("No placement") }
                let direction = placement.frame.x > placement.bounds.x ? -1.0 : 1.0
                let initial = panel.frame
                store.send(.controllerFrame(connection, scope, frame(2, Vector(x: direction, y: 0)), true))
                try await probe.wait("native movement before termination") { self.panel.frame != initial }
            case .dismissing:
                store.send(.activate(try probe.scope(), "blue", .accessibility))
                try await probe.wait("held dismissal") { !self.held.isEmpty }
            case .recovering:
                store.send(.cancel(try probe.scope(), .user))
                try await probe.wait("held failed cleanup") { !self.held.isEmpty }
                guard let operation = store.model.phase.operation else { throw ProbeFailure("No dismissal") }
                store.send(.operationFailed(operation, "Injected cleanup failure for recovery test"))
                store.send(.recover)
                guard case .unavailable(_, .some) = store.model.phase else { throw ProbeFailure("Not recovering") }
            default: break
            }
            log.recordProbe([
                "stage": stage.rawValue, "phase": store.model.phase.name,
                "moving": store.model.movement.activity != nil, "panelVisible": panel.isVisible,
                "heldAcknowledgments": held.count,
                "injection": "Selected acknowledgments are held; recovery also injects a cleanup failure"
            ])
            if stage != .missingRelease {
                Task { @MainActor [self] in
                    try? await Task.sleep(for: .milliseconds(50))
                    let acknowledgments = held
                    held.removeAll()
                    for event in acknowledgments { receive?(event) }
                }
            }
        } catch {
            log.recordProbe(["stage": stage.rawValue, "error": String(describing: error)])
        }
        // Exercise applicationShouldTerminate, terminateLater, and the final reply.
        quit()
    }
}
