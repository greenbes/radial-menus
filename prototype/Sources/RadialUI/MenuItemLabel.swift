import SwiftUI
import RadialCore

/// Shared by rendering and native text measurement.
public struct MenuItemLabel: View {
    public let item: Item
    public let selected: Bool
    public let fontSize: Double

    public init(item: Item, selected: Bool, fontSize: Double) {
        self.item = item; self.selected = selected; self.fontSize = fontSize
    }

    public var body: some View {
        VStack(spacing: 4) {
            Text(item.label).font(.system(size: fontSize, weight: selected ? .bold : .medium))
            if case .menu = item.destination {
                Image(systemName: "chevron.right").font(.system(size: fontSize * 0.7))
            }
        }
        .multilineTextAlignment(.center)
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
