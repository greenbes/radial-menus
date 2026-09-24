import Foundation

public struct ContextMeasurement: Equatable, Sendable {
    public let target: ContextID
    public let size: Size
    public init(target: ContextID, size: Size) { self.target = target; self.size = size }
}

public struct ContextLabelLayout: Equatable, Sendable {
    public let target: ContextID
    public let bounds: Rect
    public let cornerRadius: Double
}

/// All label centers in a level lie on this circle, centered on the active menu.
/// Older levels have greater radii and shorter arcs.
public struct ContextArcLayout: Equatable, Sendable {
    public let distance: Int
    public let radius: Double
    public let startAngle: Double
    public let endAngle: Double
    public let labels: [ContextLabelLayout]
    public var length: Double { radius * (endAngle - startAngle) }
}

/// Past levels form concentric arcs to the left of the active choices. Complete
/// radial bands remain disjoint, so levels cannot interleave or obscure controls.
enum ContextPlacement {
    struct Result {
        let arcs: [ContextArcLayout]
        let size: Size
        var labels: [ContextLabelLayout] { arcs.flatMap(\.labels) }
    }

    static func make(entries: [ContextEntry], measurements: [ContextMeasurement], active: [LabelLayout],
                     activeSize: Size, available: Size, padding: Double, fontSize: Double) throws -> Result {
        guard available.isValid, measurements.count == entries.count,
              Set(measurements.map(\.target)) == Set(entries.map(\.target)),
              Set(measurements.map(\.target)).count == measurements.count,
              measurements.allSatisfy({ $0.size.isValid }),
              entries.allSatisfy({ (1...7).contains($0.distance) }) else {
            throw LayoutFailure.invalidMeasurements
        }
        guard !entries.isEmpty else { return Result(arcs: [], size: activeSize) }
        let levels = Dictionary(grouping: entries, by: \.distance)
        let distances = levels.keys.sorted()
        guard distances == Array(1...distances.count), levels.values.allSatisfy({ $0.filter(\.isAncestor).count == 1 }) else {
            throw LayoutFailure.invalidMeasurements
        }
        let sizes = Dictionary(uniqueKeysWithValues: measurements.map { ($0.target, $0.size) })
        let maximumSpan = Double.pi / 2
        let gap = 12 * fontSize / 17
        var parentLength = 480 * fontSize / 17
        for distance in distances {
            let level = levels[distance]!, count = level.count
            guard count > 1 else { continue }
            let heights = level.map { sizes[$0.target]!.height }
            let step = zip(heights, heights.dropFirst()).map { ($0 + $1) / 2 + gap }.max()!
            // On the left-hand arc, dy/d(angle) has magnitude at least
            // radius * cos(maximumSpan / 2). This bound separates each pair
            // vertically, including labels with different numbers of lines.
            let required = Double(count - 1) * step / cos(maximumSpan / 2)
            parentLength = max(parentLength, required / pow(0.8, Double(distance - 1)))
        }
        var outer = active.map { extent($0.bounds) }.max() ?? 0
        var arcs: [ContextArcLayout] = []
        for distance in distances {
            let level = levels[distance]!
            let halfDiagonal = level.map { sizes[$0.target]! }.map { hypot($0.width, $0.height) / 2 }.max()!
            let length = parentLength * pow(0.8, Double(distance - 1))
            let radius = max(length / maximumSpan, outer + halfDiagonal + gap)
            let span = length / radius
            let labels = level.enumerated().map { index, entry in
                let size = sizes[entry.target]!
                let offset = level.count == 1 ? 0 : span / 2 - Double(index) * span / Double(level.count - 1)
                let angle = Double.pi + offset
                return ContextLabelLayout(target: entry.target,
                    bounds: Rect(x: radius * cos(angle) - size.width / 2,
                                 y: radius * sin(angle) - size.height / 2, width: size.width, height: size.height),
                    cornerRadius: min(4 * entry.scale * fontSize / 17, size.width / 2, size.height / 2))
            }
            arcs.append(ContextArcLayout(distance: distance, radius: radius,
                startAngle: .pi - span / 2, endAngle: .pi + span / 2, labels: labels))
            outer = labels.map { extent($0.bounds) }.max()!
        }
        let boxes = arcs.flatMap(\.labels).map(\.bounds)
        let halfWidth = boxes.reduce(activeSize.width / 2 - padding) { max($0, abs($1.x), abs($1.x + $1.width)) }
        let halfHeight = boxes.reduce(activeSize.height / 2 - padding) { max($0, abs($1.y), abs($1.y + $1.height)) }
        let size = Size(width: ceil(2 * (halfWidth + padding)), height: ceil(2 * (halfHeight + padding)))
        guard size.isValid, size.width <= available.width, size.height <= available.height else { throw LayoutFailure.doesNotFit }
        return Result(arcs: arcs, size: size)
    }

    private static func extent(_ box: Rect) -> Double {
        hypot(max(abs(box.x), abs(box.x + box.width)), max(abs(box.y), abs(box.y + box.height)))
    }
}
