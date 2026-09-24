import AppKit
import SwiftUI
import RadialCore
import RadialRuntime
import RadialMac
import RadialUI

/// Records actual pixels and native glyph sizes. The Python verifier checks
/// these observations independently of SwiftUI's chosen colors and geometry.
@MainActor enum NativeIconRingProbe {
    static func capture(store: Store, panel: PanelAdapter) throws -> [String: Any] {
        guard let layout = store.view.layout, let ring = layout.iconRing, let content = panel.content,
              let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) else {
            throw ProbeFailure("Missing icon ring rendering")
        }
        content.layoutSubtreeIfNeeded()
        content.cacheDisplay(in: content.bounds, to: bitmap)
        func pixel(_ point: Vector) throws -> [Double] {
            let x = Int((point.x + layout.diameter / 2) * Double(bitmap.pixelsWide) / layout.diameter)
            let y = Int((point.y + layout.diameter / 2) * Double(bitmap.pixelsHigh) / layout.diameter)
            guard x >= 0, y >= 0, x < bitmap.pixelsWide, y < bitmap.pixelsHigh,
                  let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                throw ProbeFailure("Missing icon ring pixel")
            }
            return [color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent]
        }
        let icons = try zip(store.view.items, ring.icons).enumerated().map { index, pair -> [String: Any] in
            let (item, icon) = pair
            let symbol = MenuIconGlyph.symbol(for: item.icon)
            guard NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil else {
                throw ProbeFailure("Unavailable system symbol: \(symbol)")
            }
            let measured = [false, true].map { selected -> [Double] in
                let host = NSHostingController(rootView: MenuIconGlyph(icon: item.icon, selected: selected, fontSize: layout.fontSize))
                let size = host.sizeThatFits(in: NSSize(width: 10000, height: 10000))
                return [size.width, size.height]
            }
            let label = layout.labels[index].bounds
            let direction = Vector(x: icon.center.x / ring.radius, y: icon.center.y / ring.radius)
            let inwardDistance = min(direction.x == 0 ? .infinity : label.width / (2 * abs(direction.x)),
                                     direction.y == 0 ? .infinity : label.height / (2 * abs(direction.y)))
            let gapRadius = (ring.radius + ring.badgeRadius + layout.labelRadius - inwardDistance) / 2
            // Sample between the measured glyph and the inset outline. A point
            // near the badge edge can contain antialiased border pixels.
            let glyphHalfWidth = measured.map { $0[0] }.max()! / 2
            let fillOffset = glyphHalfWidth + (ring.badgeRadius - glyphHalfWidth) / 4
            return ["id": item.id, "symbol": symbol, "center": [icon.center.x, icon.center.y],
                    "normal": measured[0], "selected": measured[1],
                    "iconFill": try pixel(Vector(x: icon.center.x + fillOffset, y: icon.center.y)),
                    "labelFill": try pixel(Vector(x: label.x + 6, y: label.y + label.height / 2)),
                    "gapPixel": try pixel(Vector(x: direction.x * gapRadius, y: direction.y * gapRadius))]
        }
        return ["selectedID": store.view.selectedID as Any? ?? NSNull(),
                "radius": ring.radius, "badgeRadius": ring.badgeRadius,
                "centerPixel": try pixel(.zero), "icons": icons]
    }
}
