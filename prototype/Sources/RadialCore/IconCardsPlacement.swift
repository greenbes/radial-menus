import Foundation

enum IconCardsPlacement {
    static func make(menu: Menu, measurements: MenuMeasurements, sizes: [Size], card: Size,
                     settings: LayoutSettings) throws -> MenuLayout {
        let ring = try IconRing.make(menu: menu, measurements: measurements.icons,
                                     fontSize: measurements.fontSize, gap: settings.contentPadding)
        let sectors = Geometry.sectors(count: sizes.count), gap = settings.contentPadding
        let inner = ring.radius + ring.badgeRadius
        let directions = sectors.map { Vector(x: sin($0.center), y: -0.64 * cos($0.center)) }
        var radius = settings.minimumLabelRadius
        for (direction, size) in zip(directions, sizes) {
            let x = abs(direction.x), y = abs(direction.y)
            radius = max(radius, min(x > 1e-10 ? (inner + gap + size.width / 2) / x : .infinity,
                                     y > 1e-10 ? (inner + gap + size.height / 2) / y : .infinity))
        }
        for i in sizes.indices {
            for j in sizes.indices where j > i {
                let dx = abs(directions[i].x - directions[j].x), dy = abs(directions[i].y - directions[j].y)
                radius = max(radius, min(dx > 1e-10 ? ((sizes[i].width + sizes[j].width) / 2 + gap) / dx : .infinity,
                                         dy > 1e-10 ? ((sizes[i].height + sizes[j].height) / 2 + gap) / dy : .infinity))
            }
        }
        let labels = zip(menu.items.indices, sizes).map { i, size in
            LabelLayout(itemID: menu.items[i].id, bounds: Rect(x: directions[i].x * radius - size.width / 2,
                y: directions[i].y * radius - size.height / 2, width: size.width, height: size.height), cornerRadius: 10)
        }
        let bottom = labels.map { $0.bounds.y + $0.bounds.height }.max()!
        let message = Rect(x: -card.width / 2, y: max(bottom, inner) + gap * 2.5, width: card.width, height: card.height)
        let back = measurements.messageBackSize.map {
            Rect(x: -$0.width / 2, y: message.y + message.height + gap, width: $0.width, height: $0.height)
        }
        let all = labels.map(\.bounds) + [message] + [back].compactMap { $0 }
        let extentX = all.reduce(inner) { max($0, abs($1.x), abs($1.x + $1.width)) }
        let top = min(-inner, all.map(\.y).min()!), lower = max(inner, all.map { $0.y + $0.height }.max()!)
        let dy = -(top + lower) / 2
        func shift(_ r: Rect) -> Rect { Rect(x: r.x, y: r.y + dy, width: r.width, height: r.height) }
        let size = Size(width: ceil(2 * (extentX + settings.windowPadding)), height: ceil(lower - top + 2 * settings.windowPadding))
        guard size.isValid, radius.isFinite else { throw LayoutFailure.invalidMeasurements }
        return MenuLayout(style: .iconLabelsCards, centerBounds: shift(message), messageBackBounds: back.map(shift),
            fontSize: measurements.fontSize, wrappingWidth: measurements.wrappingWidth,
            innerRadius: inner, outerRadius: hypot(extentX, max(abs(top), abs(lower))), labelRadius: radius,
            diameter: max(size.width, size.height), size: size, centerRadius: 0, sectors: sectors,
            labels: labels.map { LabelLayout(itemID: $0.itemID, bounds: shift($0.bounds), cornerRadius: $0.cornerRadius) },
            directionGuide: nil, iconRing: ring, contextArcs: [], ringCenter: Vector(x: 0, y: dy), choicePanel: nil)
    }
}
