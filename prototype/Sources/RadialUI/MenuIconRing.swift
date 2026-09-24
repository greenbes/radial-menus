import SwiftUI
import RadialCore

/// The same glyph is used for native measurement and display.
public struct MenuIconGlyph: View {
    public let icon: ItemIcon
    public let selected: Bool
    public let fontSize: Double

    public init(icon: ItemIcon, selected: Bool, fontSize: Double) {
        self.icon = icon; self.selected = selected; self.fontSize = fontSize
    }

    public static func symbol(for icon: ItemIcon) -> String {
        switch icon {
        case .item: "circle.dotted"
        case .documents: "doc.on.doc"
        case .workspace: "rectangle.3.group"
        case .writing: "square.and.pencil"
        case .history: "clock.arrow.circlepath"
        case .capture: "viewfinder"
        case .commands: "square.grid.2x2"
        case .color: "paintpalette"
        case .terminal: "terminal"
        }
    }

    public var body: some View {
        Image(systemName: Self.symbol(for: icon))
            .font(.system(size: fontSize, weight: selected ? .semibold : .regular))
            .fixedSize()
    }
}

struct MenuIconRing: View {
    let ring: IconRing
    let items: [Item]
    let size: RadialCore.Size
    let center: Vector
    let fontSize: Double
    let selectedID: String?

    var body: some View {
        Canvas { context, _ in
            let origin = CGPoint(x: size.width / 2 + center.x, y: size.height / 2 + center.y)
            let circle = CGRect(x: origin.x - ring.radius, y: origin.y - ring.radius,
                                width: ring.radius * 2, height: ring.radius * 2)
            context.stroke(Path(ellipseIn: circle), with: .color(Color(nsColor: .windowBackgroundColor)), lineWidth: 2)
            for icon in ring.icons {
                let selected = selectedID == icon.itemID
                let outlineWidth = selected ? 3.0 : 1.0
                let center = CGPoint(x: origin.x + icon.center.x, y: origin.y + icon.center.y)
                let badge = CGRect(x: center.x - ring.badgeRadius, y: center.y - ring.badgeRadius,
                                   width: ring.badgeRadius * 2, height: ring.badgeRadius * 2)
                context.fill(Path(ellipseIn: badge), with: .color(selected
                    ? .accentColor : Color(nsColor: .windowBackgroundColor)))
                context.stroke(Path(ellipseIn: badge.insetBy(dx: outlineWidth / 2, dy: outlineWidth / 2)),
                               with: .color(selected ? .white : Color.primary.opacity(0.25)), lineWidth: outlineWidth)
                if let glyph = context.resolveSymbol(id: icon.itemID) { context.draw(glyph, at: center) }
            }
        } symbols: {
            ForEach(items, id: \.id) { item in
                MenuIconGlyph(icon: item.icon, selected: selectedID == item.id, fontSize: fontSize)
                    .foregroundStyle(selectedID == item.id ? .white : .primary)
                    .tag(item.id)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
