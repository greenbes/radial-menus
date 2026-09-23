import Foundation
import RadialCore

/// Structured observations for checking a physical interaction against its result.
enum TransitionRecording {
    static func value(event: Event, transition: Transition) -> [String: Any] {
        let model = transition.model
        var record: [String: Any] = [
            "kind": "transition", "uptime": ProcessInfo.processInfo.systemUptime,
            "event": String(describing: event).split(separator: "(", maxSplits: 1).first.map(String.init) ?? "unknown",
            "phase": model.phase.name,
            "moving": model.movement.activity != nil,
            "outputs": transition.outputs.map(output)
        ]
        if let session = model.phase.session {
            record["session"] = session.scope.session.value
            record["revision"] = session.scope.revision
            record["menu"] = session.menu.id
            record["owner"] = session.owner?.value
            record["selected"] = session.selection?.itemID
            record["selectionSource"] = session.selection.map { String(describing: $0.source) }
        }
        if let placement = model.movement.placement {
            record["frame"] = rect(placement.frame)
            record["bounds"] = rect(placement.bounds)
            record["screen"] = placement.screenID
            record["layout"] = placement.layout
        }
        switch event {
        case .connected(let info, _):
            record["connection"] = info.id.value
            record["controller"] = info.name
            record["supportsMovement"] = info.supportsMovement
        case .controllerFrame(let connection, _, let frame, let continuous):
            record["connection"] = connection.value
            record["sequence"] = frame.sequence
            record["observedAt"] = frame.observedAt
            record["continuous"] = continuous
            record["leftStick"] = [frame.stick.x, frame.stick.y]
            record["rightStick"] = [frame.rightStick.x, frame.rightStick.y]
            record["buttons"] = frame.buttons.map { String(describing: $0) }.sorted()
        case .moved(_, let operation, _): record["operation"] = operation.value
        case .pointerBaseline(let scope, let sample), .pointerMoved(let scope, let sample):
            record["inputSession"] = scope.session.value
            record["inputRevision"] = scope.revision
            record["pointerSequence"] = sample.sequence
            record["pointerTimestamp"] = sample.timestamp
            record["pointerLayout"] = sample.layout
            record["screenPointer"] = [sample.screenPosition.x, sample.screenPosition.y]
            record["menuPointer"] = [sample.menuPosition.x, sample.menuPosition.y]
        default: break
        }
        return record
    }

    private static func rect(_ rect: Rect) -> [Double] { [rect.x, rect.y, rect.width, rect.height] }

    private static func output(_ value: Output) -> [String: Any] {
        switch value {
        case .rejected(let reason): ["type": "rejected", "reason": reason.rawValue]
        case .completed(let session, let outcome):
            switch outcome {
            case .selected(let choice):
                ["type": "selected", "session": session.value, "item": choice.itemID,
                 "value": choice.value, "menuPath": choice.menuPath]
            case .cancelled(let reason):
                ["type": "cancelled", "session": session.value, "reason": reason.rawValue]
            case .failed(let failure):
                ["type": "failed", "session": session.value, "message": failure.message,
                 "cleanupConfirmed": failure.cleanupConfirmed]
            }
        }
    }
}
