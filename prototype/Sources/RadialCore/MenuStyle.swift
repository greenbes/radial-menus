/// Presentation is chosen independently of a menu's content and destinations.
public enum MenuStyle: String, CaseIterable, Equatable, Sendable {
    case pie, fullLabels, iconLabels, floatingLabels, recenteredFloatingLabels, cards, selectedMessage, iconLabelsCards

    public var title: String {
        switch self {
        case .pie: "Pie wedges"
        case .fullLabels: "Full labels"
        case .iconLabels: "Full labels with icons"
        case .floatingLabels: "Floating labels"
        case .recenteredFloatingLabels: "Floating labels — recenter submenus"
        case .cards: "Cards"
        case .selectedMessage: "Selected message"
        case .iconLabelsCards: "Labels with icons and cards"
        }
    }

    public var usesDirectionGuide: Bool { self == .fullLabels || self == .cards }
    public var usesFloatingLabels: Bool { self == .floatingLabels || self == .recenteredFloatingLabels }
    public var usesIconRing: Bool { self == .iconLabels || self == .iconLabelsCards }
    public var showsMessageCard: Bool { self == .selectedMessage || self == .iconLabelsCards }
    public var showsFullTitles: Bool { usesDirectionGuide || usesIconRing || usesFloatingLabels }
    public var hasEmptyCenter: Bool { usesIconRing || usesFloatingLabels }
}

/// The same value supplies native measurement and rendering, including the
/// neutral state before an item is selected. It contains no view or action.
public struct MenuMessage: Equatable, Sendable {
    public let itemID: String?
    public let title: String
    public let detail: String

    public static func make(title: String, items: [Item], selectedID: String?) -> Self {
        guard let item = items.first(where: { $0.id == selectedID }) else {
            return Self(itemID: nil, title: title,
                        detail: "Use the left stick, arrow keys, or pointer to explore the menu.")
        }
        return Self(itemID: item.id, title: item.title, detail: item.detail)
    }

    public static func all(in menu: Menu) -> [Self] {
        ([nil] + menu.items.map { Optional($0.id) }).map {
            make(title: menu.title, items: menu.items, selectedID: $0)
        }
    }
}
