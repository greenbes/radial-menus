import SwiftUI
import RadialCore

/// Shared by rendering and native text measurement.
public struct MenuItemLabel: View {
    public let item: Item
    public let selected: Bool
    public let fontSize: Double
    public let style: RadialCore.MenuStyle

    public init(item: Item, selected: Bool, fontSize: Double, style: RadialCore.MenuStyle = .pie) {
        self.item = item; self.selected = selected; self.fontSize = fontSize; self.style = style
    }

    public var body: some View {
        if style == .cards {
            MenuItemCard(item: item, selected: selected, fontSize: fontSize)
        } else if style.usesFloatingLabels {
            HStack(spacing: fontSize * 0.5) {
                MenuIconGlyph(icon: item.icon, selected: selected, fontSize: fontSize)
                    .accessibilityHidden(true)
                Text(TitleLines.wrap(item.title).joined(separator: "\n"))
                    .font(.system(size: fontSize, weight: selected ? .bold : .medium))
                    .fixedSize()
                if isSubmenu {
                    Image(systemName: "chevron.right")
                        .font(.system(size: fontSize * 0.8, weight: .semibold))
                        .accessibilityHidden(true)
                }
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, fontSize * 0.8)
            .padding(.vertical, fontSize * 0.6)
            .fixedSize()
        } else if style == .fullLabels || style.usesIconRing {
            HStack(spacing: fontSize * 0.5) {
                Text(item.title)
                    .font(.system(size: fontSize, weight: selected ? .bold : .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !style.usesIconRing || isSubmenu {
                    Image(systemName: selected && !style.usesIconRing ? "checkmark" : "chevron.right")
                        .font(.system(size: fontSize * 0.8, weight: .semibold))
                        .frame(width: fontSize)
                        .opacity(selected || isSubmenu ? 1 : 0)
                        .accessibilityHidden(true)
                }
            }
            .multilineTextAlignment(.leading)
            .padding(fontSize * 0.7)
        } else {
            VStack(spacing: 4) {
                Text(item.label).font(.system(size: fontSize, weight: selected ? .bold : .medium))
                if case .menu = item.destination {
                    Image(systemName: "chevron.right").font(.system(size: fontSize * 0.7))
                }
            }
            .multilineTextAlignment(.center)
            .padding(style == .selectedMessage ? fontSize * 0.6 : 0)
        }
    }

    private var isSubmenu: Bool {
        if case .menu = item.destination { true } else { false }
    }
}

/// The complete card is measured for every item and for the neutral state.
public struct MenuMessageCard: View {
    public let message: MenuMessage
    public let fontSize: Double
    public let height: Double?

    public init(message: MenuMessage, fontSize: Double, height: Double? = nil) {
        self.message = message; self.fontSize = fontSize
        self.height = height
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: fontSize * 0.65) {
            Text(message.title).font(.system(size: fontSize * 1.15, weight: .semibold))
            if !message.detail.isEmpty {
                Text(message.detail).font(.system(size: fontSize * 0.85)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height.map { $0 - 2 * fontSize }, alignment: .topLeading)
        .padding(fontSize)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Shared by measurement and the standalone button below the message card.
public struct MenuBackLabel: View {
    public let fontSize: Double
    public init(fontSize: Double) { self.fontSize = fontSize }

    public var body: some View {
        Label("Back", systemImage: "arrow.left")
            .labelStyle(.titleAndIcon)
            .font(.system(size: fontSize * 0.75))
            .padding(.horizontal, fontSize * 0.7).padding(.vertical, fontSize * 0.4)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
    }
}

public struct MenuCenterLabel: View {
    public let canGoBack: Bool
    public let fontSize: Double

    public init(canGoBack: Bool, fontSize: Double) {
        self.canGoBack = canGoBack; self.fontSize = fontSize
    }

    public var body: some View {
        VStack(spacing: 5) {
            Image(systemName: canGoBack ? "arrow.left" : "xmark").font(.system(size: fontSize))
            Text(canGoBack ? "Back" : "Cancel").font(.system(size: fontSize * 0.7))
        }
    }
}
