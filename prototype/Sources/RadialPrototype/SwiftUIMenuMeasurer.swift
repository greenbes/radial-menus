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
        try measure(presentation: MenuPresentation(menu: menu, canGoBack: canGoBack, style: style))
    }

    func measure(presentation: MenuPresentation) throws -> MenuMeasurements {
        let menu = presentation.menu, style = presentation.style, canGoBack = presentation.canGoBack
        let labelWidth: Double
        switch style {
        case .floatingLabels, .recenteredFloatingLabels: labelWidth = 10000 // Intrinsic size; wrapping is by words, not pixels.
        case .pie: labelWidth = wrappingWidth
        case .fullLabels, .iconLabels, .iconLabelsCards: labelWidth = 226 * fontSize / 17
        case .cards: labelWidth = 210 * fontSize / 17
        case .selectedMessage: labelWidth = 150 * fontSize / 17
        }
        let labels = menu.items.map { item in
            @MainActor func size(selected: Bool) -> RadialCore.Size {
                measureView(MenuItemLabel(item: item, selected: selected, fontSize: fontSize, style: style)
                    .fixedSize(horizontal: style.usesFloatingLabels, vertical: true), width: labelWidth)
            }
            return LabelMeasurement(itemID: item.id, normal: size(selected: false), selected: size(selected: true))
        }
        let choices = (style == .iconLabelsCards || menu.items.contains { $0.choices != nil }) ? measureChoices(menu) : nil
        if style.usesFloatingLabels {
            let maximumWidth = labels.map { max($0.normal.width, $0.selected.width) }.max()!
            let context = presentation.context.map { entry in
                ContextMeasurement(target: entry.target,
                    size: measureView(MenuContextLabel(entry: entry, fontSize: entry.fontSize(relativeTo: fontSize)), width: 10000))
            }
            return MenuMeasurements(fontSize: fontSize, wrappingWidth: maximumWidth, labels: labels,
                                    content: .empty, style: style, context: context, choices: choices)
        }
        let icons = style.usesIconRing ? menu.items.map { item in
                LabelMeasurement(itemID: item.id,
                    normal: measureView(MenuIconGlyph(icon: item.icon, selected: false, fontSize: fontSize), width: 10000),
                    selected: measureView(MenuIconGlyph(icon: item.icon, selected: true, fontSize: fontSize), width: 10000))
            } : []
        if style == .iconLabels {
            return MenuMeasurements(fontSize: fontSize, wrappingWidth: labelWidth, labels: labels,
                                    content: .empty, style: style, icons: icons, choices: choices)
        }
        if style.showsMessageCard {
            let width = 300 * fontSize / 17
            let messages = MenuMessage.all(in: menu).map { message in
                MessageMeasurement(itemID: message.itemID,
                    size: measureView(MenuMessageCard(message: message, fontSize: fontSize), width: width))
            }
            let back = (canGoBack || style == .iconLabelsCards) ? measureView(MenuBackLabel(fontSize: fontSize).fixedSize(), width: 10000) : nil
            return MenuMeasurements(fontSize: fontSize, wrappingWidth: labelWidth, labels: labels,
                                    content: .messages(wrappingWidth: width, states: messages, back: back), style: style,
                                    icons: icons, choices: choices)
        }
        let center = measureView(MenuCenterLabel(canGoBack: canGoBack, fontSize: fontSize).fixedSize(), width: 10000)
        return MenuMeasurements(fontSize: fontSize, wrappingWidth: labelWidth, labels: labels, content: .control(center), style: style, choices: choices)
    }

    private func measureChoices(_ menu: RadialCore.Menu) -> ChoiceListMeasurements {
        let width = 280 * fontSize / 17, rowWidth = width - 32
        return ChoiceListMeasurements(width: width, rowWidth: rowWidth,
            placeholder: measureView(MenuChoiceHeader(title: "Available choices", fontSize: fontSize), width: width),
            sections: menu.items.compactMap { item in
                guard let choices = item.choices else { return nil }
                return ChoiceSectionMeasurement(itemID: item.id,
                    header: measureView(MenuChoiceHeader(title: choices.title, fontSize: fontSize), width: width),
                    rows: choices.items.map { choice in
                        LabelMeasurement(itemID: choice.id,
                            normal: measureView(MenuChoiceRow(choice: choice, selected: false, fontSize: fontSize), width: rowWidth),
                            selected: measureView(MenuChoiceRow(choice: choice, selected: true, fontSize: fontSize), width: rowWidth))
                    })
            })
    }

    private func measureView<V: View>(_ view: V, width: Double) -> RadialCore.Size {
        let host = NSHostingController(rootView: view)
        let size = host.sizeThatFits(in: NSSize(width: width, height: 10000))
        return RadialCore.Size(width: ceil(size.width), height: ceil(size.height))
    }
}
