import Foundation

public struct Vector: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
    public static let zero = Vector(x: 0, y: 0)
    public var magnitude: Double { hypot(x, y) }
    public var isFinite: Bool { x.isFinite && y.isFinite }
    public func distance(to other: Vector) -> Double { hypot(x - other.x, y - other.y) }
}

public struct Rect: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

public struct Sector: Equatable, Sendable {
    public let index: Int
    public let start: Double
    public let end: Double
    public let center: Double
}

public enum Geometry {
    public static func sectors(count: Int) -> [Sector] {
        guard (1...12).contains(count) else { return [] }
        let width = 2 * Double.pi / Double(count)
        return (0..<count).map { index in
            let center = Double(index) * width
            return Sector(index: index, start: (Double(index) - 0.5) * width,
                          end: (Double(index) + 0.5) * width, center: center)
        }
    }

    public static func sector(angle: Double, count: Int) -> Int? {
        guard angle.isFinite, (1...12).contains(count) else { return nil }
        if count == 1 { return 0 }
        let circle = 2 * Double.pi
        let width = circle / Double(count)
        var normalized = angle.truncatingRemainder(dividingBy: circle)
        if normalized < -width / 2 { normalized += circle }
        if normalized >= (Double(count) - 0.5) * width { return 0 }
        // Compare the same boundaries used for rendering. Adding a half-width
        // before division can round an exact boundary into the previous sector.
        return sectors(count: count).last(where: { normalized >= $0.start })?.index
    }

    /// Local points use x right, y down. Zero radians points up.
    public static func hit(_ point: Vector, inner: Double, outer: Double, count: Int) -> Int? {
        guard point.isFinite, inner.isFinite, outer.isFinite, inner >= 0, outer > inner,
              point.magnitude > inner, point.magnitude <= outer else { return nil }
        return sector(angle: atan2(point.x, -point.y), count: count)
    }

    public static func place(center: Vector, diameter: Double, in screen: Rect) -> Rect? {
        guard center.isFinite, [diameter, screen.x, screen.y, screen.width, screen.height].allSatisfy(\.isFinite),
              diameter > 0, screen.width >= diameter, screen.height >= diameter else { return nil }
        return Rect(x: min(max(center.x - diameter / 2, screen.x), screen.x + screen.width - diameter),
                    y: min(max(center.y - diameter / 2, screen.y), screen.y + screen.height - diameter),
                    width: diameter, height: diameter)
    }
}
