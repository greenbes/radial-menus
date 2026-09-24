import Foundation

/// Decorative geometry only. Item activation uses the measured label bounds.
public struct DirectionGuide: Equatable, Sendable {
    public struct Connection: Equatable, Sendable {
        public let itemID: String
        public let marker: Vector
        public let labelEdge: Vector
    }

    public let radius: Double
    public let markerRadius: Double
    public let connections: [Connection]

    static func make(radius: Double, markerRadius: Double, sectors: [Sector], labels: [LabelLayout]) -> Self {
        let connections = zip(sectors, labels).map { sector, label in
            let dx = sin(sector.center), dy = -cos(sector.center)
            let r = label.bounds
            // Intersect the inward ray from the label's center with its box.
            let distance = min(dx == 0 ? .infinity : r.width / (2 * abs(dx)),
                               dy == 0 ? .infinity : r.height / (2 * abs(dy)))
            return Connection(itemID: label.itemID, marker: Vector(x: dx * radius, y: dy * radius),
                              labelEdge: Vector(x: r.x + r.width / 2 - dx * distance,
                                                y: r.y + r.height / 2 - dy * distance))
        }
        return Self(radius: radius, markerRadius: markerRadius, connections: connections)
    }
}
