import Foundation

/// Rounded item boundaries touch a common circle at their controller direction.
/// Rendering decides whether the layout circle is visible.
enum TangentPlacement {
    struct Result {
        let radius: Double
        let labels: [LabelLayout]
        let size: Size
        let outerRadius: Double
    }

    static func make(items: [Item], sizes: [Size], cornerRadius: Double,
                     minimumRadius: Double, settings: LayoutSettings) -> Result {
        let directions = Geometry.sectors(count: items.count).map {
            Vector(x: snapped(sin($0.center)), y: snapped(-cos($0.center)))
        }
        let corners = sizes.map { min(cornerRadius, $0.width / 2, $0.height / 2) }
        let offsets = sizes.indices.map { index -> Vector in
            let d = directions[index], s = sizes[index], r = corners[index]
            // The inward rounded corner has normal -d. Its boundary is r
            // beyond the inset rectangle, so this offset puts it on R * d.
            return Vector(x: sign(d.x) * (s.width / 2 - r) + r * d.x,
                          y: sign(d.y) * (s.height / 2 - r) + r * d.y)
        }
        var radius = minimumRadius
        for a in sizes.indices {
            for b in sizes.indices where b > a {
                let horizontal = separationRadius(delta: directions[a].x - directions[b].x,
                    offset: offsets[a].x - offsets[b].x, extent: (sizes[a].width + sizes[b].width) / 2 + settings.contentPadding)
                let vertical = separationRadius(delta: directions[a].y - directions[b].y,
                    offset: offsets[a].y - offsets[b].y, extent: (sizes[a].height + sizes[b].height) / 2 + settings.contentPadding)
                // Separating either axis separates the complete item boxes.
                radius = max(radius, min(horizontal, vertical))
            }
        }
        let labels = items.indices.map { index in
            let d = directions[index], offset = offsets[index], size = sizes[index]
            return LabelLayout(itemID: items[index].id,
                bounds: Rect(x: radius * d.x + offset.x - size.width / 2,
                             y: radius * d.y + offset.y - size.height / 2, width: size.width, height: size.height),
                cornerRadius: corners[index])
        }
        let halfWidth = labels.reduce(radius) { max($0, abs($1.bounds.x), abs($1.bounds.x + $1.bounds.width)) }
        let halfHeight = labels.reduce(radius) { max($0, abs($1.bounds.y), abs($1.bounds.y + $1.bounds.height)) }
        let outer = labels.reduce(radius) { value, label in
            let r = label.bounds
            return max(value, hypot(max(abs(r.x), abs(r.x + r.width)), max(abs(r.y), abs(r.y + r.height))))
        }
        return Result(radius: radius, labels: labels,
            size: Size(width: ceil(2 * (halfWidth + settings.windowPadding)),
                       height: ceil(2 * (halfHeight + settings.windowPadding))),
            outerRadius: ceil(outer + settings.contentPadding))
    }

    static func contains(_ point: Vector, label: LabelLayout) -> Bool {
        let r = label.bounds, corner = label.cornerRadius
        let dx = max(abs(point.x - r.x - r.width / 2) - (r.width / 2 - corner), 0)
        let dy = max(abs(point.y - r.y - r.height / 2) - (r.height / 2 - corner), 0)
        return hypot(dx, dy) <= corner
    }

    private static func separationRadius(delta: Double, offset: Double, extent: Double) -> Double {
        if abs(delta) < 1e-12 { return abs(offset) >= extent ? 0 : .infinity }
        return max(0, (extent - sign(delta) * offset) / abs(delta))
    }

    // Remove floating-point residue at exact cardinal directions.
    private static func snapped(_ value: Double) -> Double { abs(value) < 1e-12 ? 0 : value }
    private static func sign(_ value: Double) -> Double { value == 0 ? 0 : value > 0 ? 1 : -1 }
}
