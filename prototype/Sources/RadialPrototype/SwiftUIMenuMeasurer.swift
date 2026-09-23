import AppKit
import SwiftUI
import RadialCore
import RadialRuntime
import RadialUI

/// Native typography belongs at the boundary. The core receives copied sizes.
@MainActor struct SwiftUIMenuMeasurer: MenuMeasurer {
    let fontSize: Double
    let wrappingWidth: Double

    init(fontSize: Double = 17, wrappingWidth: Double? = nil) {
        self.fontSize = fontSize; self.wrappingWidth = wrappingWidth ?? 96 * fontSize / 17
    }

    func measure(menu: RadialCore.Menu, canGoBack: Bool) throws -> MenuMeasurements {
        let labels = menu.items.map { item in
            @MainActor func size(selected: Bool) -> RadialCore.Size {
                measureView(MenuItemLabel(item: item, selected: selected, fontSize: fontSize)
                    .fixedSize(horizontal: false, vertical: true), width: wrappingWidth)
            }
            return LabelMeasurement(itemID: item.id, normal: size(selected: false), selected: size(selected: true))
        }
        let center = measureView(MenuCenterLabel(canGoBack: canGoBack, fontSize: fontSize).fixedSize(), width: 10000)
        return MenuMeasurements(fontSize: fontSize, wrappingWidth: wrappingWidth, labels: labels, center: center)
    }

    private func measureView<V: View>(_ view: V, width: Double) -> RadialCore.Size {
        let host = NSHostingController(rootView: view)
        let size = host.sizeThatFits(in: NSSize(width: width, height: 10000))
        return RadialCore.Size(width: ceil(size.width), height: ceil(size.height))
    }
}
