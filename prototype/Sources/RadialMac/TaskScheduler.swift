import Foundation
import RadialCore
import RadialRuntime

@MainActor public final class TaskScheduler: DeadlineScheduler {
    private var tasks: [OperationID: Task<Void, Never>] = [:]
    public init() {}
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
}
