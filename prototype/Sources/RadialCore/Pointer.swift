public struct PointerSettings: Equatable, Sendable {
    public let movementThreshold: Double

    public init(movementThreshold: Double) throws {
        guard movementThreshold.isFinite, movementThreshold > 0 else { throw InvalidSettings() }
        self.movementThreshold = movementThreshold
    }

    public struct InvalidSettings: Error {}
    public static let standard: Self = {
        do { return try Self(movementThreshold: 2) }
        catch { preconditionFailure("Invalid built-in pointer settings") }
    }()
}

public struct PointerSample: Equatable, Sendable {
    public let sequence: UInt64
    public let timestamp: Double
    public let layout: UInt64
    /// Desktop coordinates, x right and y up, independent of the menu frame.
    public let screenPosition: Vector
    /// Coordinates relative to the menu center, x right and y down.
    public let menuPosition: Vector

    public init(sequence: UInt64, timestamp: Double, layout: UInt64,
                screenPosition: Vector, menuPosition: Vector) {
        self.sequence = sequence; self.timestamp = timestamp; self.layout = layout
        self.screenPosition = screenPosition; self.menuPosition = menuPosition
    }

    var isValid: Bool {
        sequence > 0 && timestamp.isFinite && timestamp >= 0 && layout > 0 &&
            screenPosition.isFinite && menuPosition.isFinite
    }
}

public struct PointerState: Equatable, Sendable {
    public let latest: PointerSample?
    public let anchor: Vector?
    init(latest: PointerSample? = nil, anchor: Vector? = nil) {
        self.latest = latest; self.anchor = anchor
    }
}

extension Change {
    mutating func pointerBaseline(_ scope: InputScope, _ sample: PointerSample) {
        guard phase.session?.scope == scope, acceptsPointer(sample) else { return }
        switch phase { case .active, .presenting: break; default: return }
        pointer = PointerState(latest: sample, anchor: sample.screenPosition)
    }

    mutating func pointerMoved(_ scope: InputScope, _ sample: PointerSample) {
        guard let session = active(scope), acceptsPointer(sample), let anchor = pointer.anchor else { return }
        let moved = sample.screenPosition.distance(to: anchor) >= pointerSettings.movementThreshold
        pointer = PointerState(latest: sample, anchor: moved ? sample.screenPosition : anchor)
        guard moved else { return }
        let index = session.layout?.hit(sample.menuPosition)
        let item = index.map { session.menu.items[$0].id }
        select(scope, item, .pointer)
    }

    private func acceptsPointer(_ sample: PointerSample) -> Bool {
        guard sample.isValid, sample.layout == movement.placement?.layout else { return false }
        guard let previous = pointer.latest else { return true }
        return sample.sequence > previous.sequence && sample.timestamp >= previous.timestamp
    }
}
