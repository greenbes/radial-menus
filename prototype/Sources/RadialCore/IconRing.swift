import Foundation

/// Decorative icon positions, separate from the outer label activation targets.
public struct IconRing: Equatable, Sendable {
    public struct Icon: Equatable, Sendable {
        public let itemID: String
        public let center: Vector
    }

    public let radius: Double
    public let badgeRadius: Double
    public let icons: [Icon]

    static func make(menu: Menu, measurements: [LabelMeasurement], fontSize: Double, gap: Double) throws -> Self {
        guard measurements.count == menu.items.count,
              Set(measurements.map(\.itemID)) == Set(menu.items.map(\.id)),
              measurements.allSatisfy({ $0.normal.isValid && $0.selected.isValid }) else {
            throw LayoutFailure.invalidMeasurements
        }
        let scale = fontSize / 17
        let badgeRadius = measurements.reduce(18 * scale) {
            max($0, hypot($1.normal.width, $1.normal.height) / 2 + 6 * scale,
                hypot($1.selected.width, $1.selected.height) / 2 + 6 * scale)
        }
        // Adjacent badge centers are a chord apart. Reserve a full gap between
        // their circles even at twelve items or with larger native glyphs.
        let separation = menu.items.count > 1 ? (badgeRadius + gap / 2) / sin(.pi / Double(menu.items.count)) : 0
        let radius = max(74 * scale, separation)
        return Self(radius: radius, badgeRadius: badgeRadius,
                    icons: zip(menu.items, Geometry.sectors(count: menu.items.count)).map { item, sector in
                        Icon(itemID: item.id, center: Vector(x: sin(sector.center) * radius, y: -cos(sector.center) * radius))
                    })
    }
}
