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

    func measure(menu: RadialCore.Menu, canGoBack: Bool, style: RadialCore.MenuStyle) throws -> MenuMeasurements {
        let labelWidth: Double
        switch style {
        case .pie: labelWidth = wrappingWidth
        case .fullLabels, .iconLabels: labelWidth = 226 * fontSize / 17
        case .cards: labelWidth = 210 * fontSize / 17
        case .selectedMessage: labelWidth = 150 * fontSize / 17
        }
        let labels = menu.items.map { item in
            @MainActor func size(selected: Bool) -> RadialCore.Size {
                measureView(MenuItemLabel(item: item, selected: selected, fontSize: fontSize, style: style)
                    .fixedSize(horizontal: false, vertical: true), width: labelWidth)
            }
            return LabelMeasurement(itemID: item.id, normal: size(selected: false), selected: size(selected: true))
        }
        if style == .iconLabels {
            let icons = menu.items.map { item in
                LabelMeasurement(itemID: item.id,
                    normal: measureView(MenuIconGlyph(icon: item.icon, selected: false, fontSize: fontSize), width: 10000),
                    selected: measureView(MenuIconGlyph(icon: item.icon, selected: true, fontSize: fontSize), width: 10000))
            }
            return MenuMeasurements(fontSize: fontSize, wrappingWidth: labelWidth, labels: labels,
                                    content: .empty, style: style, icons: icons)
        }
        if style == .selectedMessage {
            let width = 300 * fontSize / 17
            let messages = MenuMessage.all(in: menu).map { message in
                MessageMeasurement(itemID: message.itemID,
                    size: measureView(MenuMessageCard(message: message, canGoBack: canGoBack, fontSize: fontSize), width: width))
            }
            return MenuMeasurements(fontSize: fontSize, wrappingWidth: labelWidth, labels: labels,
                                    content: .messages(wrappingWidth: width, states: messages), style: style)
        }
        let center = measureView(MenuCenterLabel(canGoBack: canGoBack, fontSize: fontSize).fixedSize(), width: 10000)
        return MenuMeasurements(fontSize: fontSize, wrappingWidth: labelWidth, labels: labels, center: center, style: style)
    }

    private func measureView<V: View>(_ view: V, width: Double) -> RadialCore.Size {
        let host = NSHostingController(rootView: view)
        let size = host.sizeThatFits(in: NSSize(width: width, height: 10000))
        return RadialCore.Size(width: ceil(size.width), height: ceil(size.height))
    }
}
