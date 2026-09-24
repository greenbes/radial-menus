import Foundation

/// Cards may extend across a sector boundary, but must not touch another card
/// or obscure another item's connecting line. All centers share one radius.
enum CardSpacing {
    static func minimumRadius(sizes: [Size], sectors: [Sector], gap: Double) -> Double {
        let directions = sectors.map { Vector(x: sin($0.center), y: -cos($0.center)) }
        var radius = 0.0
        for index in sizes.indices {
            let size = sizes[index], direction = directions[index]
            for other in sizes.indices where other != index {
                let target = directions[other]
                if other > index {
                    // Rectangles are disjoint when separated on either axis.
                    let horizontal = requiredRadius(extent: (size.width + sizes[other].width) / 2,
                                                    separation: abs(direction.x - target.x), gap: gap)
                    let vertical = requiredRadius(extent: (size.height + sizes[other].height) / 2,
                                                  separation: abs(direction.y - target.y), gap: gap)
                    radius = max(radius, min(horizontal, vertical))
                }
                // Separate this card from the entire segment between the origin
                // and another card's center. Its actual connection is shorter.
                // For a rectangle and a segment, the separating axes are x, y,
                // and the segment's normal. All separations scale with radius.
                let horizontal = requiredRadius(extent: size.width / 2,
                    separation: distanceOutsideInterval(direction.x, endpoint: target.x), gap: gap)
                let vertical = requiredRadius(extent: size.height / 2,
                    separation: distanceOutsideInterval(direction.y, endpoint: target.y), gap: gap)
                let normal = Vector(x: -target.y, y: target.x)
                let perpendicular = requiredRadius(
                    extent: (size.width * abs(normal.x) + size.height * abs(normal.y)) / 2,
                    separation: abs(direction.x * normal.x + direction.y * normal.y), gap: gap)
                radius = max(radius, min(horizontal, vertical, perpendicular))
            }
        }
        return radius
    }

    private static func requiredRadius(extent: Double, separation: Double, gap: Double) -> Double {
        separation > 1e-12 ? (extent + gap) / separation : .infinity
    }

    private static func distanceOutsideInterval(_ value: Double, endpoint: Double) -> Double {
        max(0, min(0, endpoint) - value, value - max(0, endpoint))
    }
}
