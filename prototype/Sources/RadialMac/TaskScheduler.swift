import Foundation
import RadialCore
import RadialRuntime

@MainActor public final class TaskScheduler: DeadlineScheduler, MovementScheduler {
    private var tasks: [OperationID: Task<Void, Never>] = [:]
    private var movementTasks: [MovementID: Task<Void, Never>] = [:]
    public init() {}
    public var activeDeadlineCount: Int { tasks.count }
    public var activeMovementCount: Int { movementTasks.count }
    public func schedule(operation: OperationID, after seconds: Double, receive: @escaping EventReceiver) {
        cancel(operation: operation)
        tasks[operation] = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            guard !Task.isCancelled else { return }
            self?.tasks.removeValue(forKey: operation)
            receive(.deadline(operation))
        }
    }
    public func cancel(operation: OperationID) { tasks.removeValue(forKey: operation)?.cancel() }

    public func startMovement(id: MovementID, receive: @escaping EventReceiver) {
        guard movementTasks[id] == nil else { return }
        movementTasks[id] = Task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1.0 / 60.0)) } catch { return }
                guard !Task.isCancelled else { return }
                receive(.movementTick(id, ProcessInfo.processInfo.systemUptime))
            }
        }
    }

    public func stopMovement(id: MovementID) { movementTasks.removeValue(forKey: id)?.cancel() }
}
