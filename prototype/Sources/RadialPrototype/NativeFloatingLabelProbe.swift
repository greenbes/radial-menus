import AppKit
import RadialCore
import RadialRuntime
import RadialMac

/// Pixels from the actual hosted menu, including every selection state.
@MainActor enum NativeFloatingLabelProbe {
    static func capture(store: Store, panel: PanelAdapter) throws -> [String: Any] {
        guard let layout = store.view.layout, let content = panel.content,
              let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) else {
            throw ProbeFailure("Missing floating label rendering")
        }
        content.layoutSubtreeIfNeeded()
        content.cacheDisplay(in: content.bounds, to: bitmap)
        func pixel(x: Double, y: Double) throws -> [Double] {
            let px = Int((x + layout.size.width / 2) * Double(bitmap.pixelsWide) / layout.size.width)
            let py = Int((y + layout.size.height / 2) * Double(bitmap.pixelsHigh) / layout.size.height)
            guard let color = bitmap.colorAt(x: px, y: py)?.usingColorSpace(.deviceRGB) else {
                throw ProbeFailure("Missing floating label pixel")
            }
            return [color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent]
        }
        let gapAlpha = try layout.labels.indices.map { index -> Double in
            let angle = (Double(index) + 0.5) * 2 * .pi / Double(layout.labels.count)
            return try pixel(x: sin(angle) * layout.labelRadius, y: -cos(angle) * layout.labelRadius)[3]
        }
        let labels = try layout.labels.map { label -> [String: Any] in
            let r = label.bounds
            return ["id": label.itemID,
                    "fill": try pixel(x: r.x + 7, y: r.y + r.height / 2),
                    "outline": try pixel(x: r.x + 1.5, y: r.y + r.height / 2)]
        }
        return ["selectedID": store.view.selectedID as Any? ?? NSNull(),
                "centerAlpha": try pixel(x: 0, y: 0)[3], "gapAlpha": gapAlpha, "labels": labels]
    }
}
