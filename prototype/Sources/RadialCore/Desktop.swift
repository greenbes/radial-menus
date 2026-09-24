import Foundation

/// Usable display rectangles in the same desktop coordinate system, in points.
public struct DisplayArea: Equatable, Sendable {
    public let id: String
    public let bounds: Rect
    public init(id: String, bounds: Rect) { self.id = id; self.bounds = bounds }
}

public struct Desktop: Equatable, Sendable {
    public let displays: [DisplayArea]

    public init(displays: [DisplayArea]) {
        self.displays = displays.sorted { $0.id < $1.id }
    }

    public var isValid: Bool {
        !displays.isEmpty && Set(displays.map(\.id)).count == displays.count &&
        displays.allSatisfy { !$0.id.isEmpty && $0.bounds.isFiniteArea } && bounds.isFiniteArea
    }

    /// The enclosing rectangle is useful for reporting, but includes any gaps.
    /// Use contains/move/place for visibility decisions.
    public var bounds: Rect {
        guard let first = displays.first else { return Rect(x: 0, y: 0, width: 0, height: 0) }
        let x = displays.map { $0.bounds.x }.min() ?? first.bounds.x
        let y = displays.map { $0.bounds.y }.min() ?? first.bounds.y
        let right = displays.map { $0.bounds.x + $0.bounds.width }.max() ?? x
        let top = displays.map { $0.bounds.y + $0.bounds.height }.max() ?? y
        return Rect(x: x, y: y, width: right - x, height: top - y)
    }

    public func contains(_ frame: Rect) -> Bool {
        guard isValid, frame.isFiniteArea else { return false }
        return spans(across: frame.y...(frame.y + frame.height), vertical: false).contains {
            $0.lowerBound <= frame.x && $0.upperBound >= frame.x + frame.width
        }
    }

    /// A descriptive display identity; crossing never changes the input scope.
    public func displayID(for frame: Rect) -> String? {
        displays.max { a, b in
            let aa = overlap(frame, a.bounds), bb = overlap(frame, b.bounds)
            return aa == bb ? a.id > b.id : aa < bb
        }.flatMap { overlap(frame, $0.bounds) > 0 ? $0.id : nil }
    }

    /// Sweep each axis through the connected visible span containing the frame.
    /// Horizontal then vertical motion slides along outer edges. Even a large
    /// step cannot jump a gap, and a shared display edge does not stop movement.
    public func move(_ frame: Rect, by delta: Vector) -> Rect? {
        guard contains(frame), delta.isFinite else { return nil }
        let horizontal = spans(across: frame.y...(frame.y + frame.height), vertical: false)
            .first { $0.lowerBound <= frame.x && $0.upperBound >= frame.x + frame.width }!
        let x = min(max(frame.x + delta.x, horizontal.lowerBound), horizontal.upperBound - frame.width)
        let vertical = spans(across: x...(x + frame.width), vertical: true)
            .first { $0.lowerBound <= frame.y && $0.upperBound >= frame.y + frame.height }!
        let y = min(max(frame.y + delta.y, vertical.lowerBound), vertical.upperBound - frame.height)
        return Rect(x: x, y: y, width: frame.width, height: frame.height)
    }

    /// Nearest complete placement for opening, resizing, or a display change.
    /// Visibility can change only when a frame edge meets a display edge; these
    /// candidates therefore include the nearest point of every valid region.
    public func place(_ frame: Rect) -> Rect? {
        guard isValid, frame.isFiniteArea else { return nil }
        if contains(frame) { return frame }
        let xs = Set([frame.x] + displays.flatMap {
            [$0.bounds.x, $0.bounds.x - frame.width,
             $0.bounds.x + $0.bounds.width, $0.bounds.x + $0.bounds.width - frame.width]
        }).filter(\.isFinite).sorted()
        let ys = Set([frame.y] + displays.flatMap {
            [$0.bounds.y, $0.bounds.y - frame.height,
             $0.bounds.y + $0.bounds.height, $0.bounds.y + $0.bounds.height - frame.height]
        }).filter(\.isFinite).sorted()
        var best: Rect?, distance = Double.infinity
        for x in xs {
            for y in ys {
                let candidate = Rect(x: x, y: y, width: frame.width, height: frame.height)
                let d = hypot(x - frame.x, y - frame.y)
                if d < distance, contains(candidate) { best = candidate; distance = d }
            }
        }
        return best
    }

    /// Intersect horizontal coverage across every strip of the frame's height.
    /// Swapping axes computes vertical coverage in exactly the same way.
    private func spans(across cross: ClosedRange<Double>, vertical: Bool) -> [ClosedRange<Double>] {
        let boxes = displays.map { vertical ? $0.bounds.transposed : $0.bounds }
        let cuts = Set([cross.lowerBound, cross.upperBound] + boxes.flatMap { [$0.y, $0.y + $0.height] })
            .filter { cross.contains($0) }.sorted()
        var result: [ClosedRange<Double>]?
        for (low, high) in zip(cuts, cuts.dropFirst()) {
            let covered = merge(boxes.filter { $0.y <= low && $0.y + $0.height >= high }
                .map { $0.x...($0.x + $0.width) })
            if let previous = result {
                result = previous.flatMap { a in covered.compactMap { b in
                    let start = max(a.lowerBound, b.lowerBound), end = min(a.upperBound, b.upperBound)
                    return start <= end ? start...end : nil
                } }
            } else { result = covered }
            if result?.isEmpty == true { return [] }
        }
        return result ?? []
    }

    private func merge(_ spans: [ClosedRange<Double>]) -> [ClosedRange<Double>] {
        var result: [ClosedRange<Double>] = []
        for span in spans.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = result.last, span.lowerBound <= last.upperBound {
                result[result.count - 1] = last.lowerBound...max(last.upperBound, span.upperBound)
            } else { result.append(span) }
        }
        return result
    }

    private func overlap(_ a: Rect, _ b: Rect) -> Double {
        max(0, min(a.x + a.width, b.x + b.width) - max(a.x, b.x)) *
        max(0, min(a.y + a.height, b.y + b.height) - max(a.y, b.y))
    }
}

extension Rect {
    var isFiniteArea: Bool {
        [x, y, width, height, x + width, y + height].allSatisfy(\.isFinite) && width > 0 && height > 0
    }
    fileprivate var transposed: Rect { Rect(x: y, y: x, width: height, height: width) }
}
