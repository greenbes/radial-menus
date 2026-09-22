import Foundation

public struct Item: Equatable, Sendable {
    public enum Destination: Equatable, Sendable { case value(String), menu(Menu) }
    public let id: String
    public let label: String
    public let destination: Destination

    public init(id: String, label: String, value: String) {
        self.id = id; self.label = label; self.destination = .value(value)
    }

    public init(id: String, label: String, menu: Menu) {
        self.id = id; self.label = label; self.destination = .menu(menu)
    }
}

public struct Menu: Equatable, Sendable {
    public let id: String
    public let title: String
    public let items: [Item]

    public init(id: String, title: String, items: [Item]) throws {
        self.id = id; self.title = title; self.items = items
        var menuIDs = Set<String>()
        var itemIDs = Set<String>()
        var total = 0
        try Self.validate(self, depth: 1, menus: &menuIDs, items: &itemIDs, total: &total)
    }

    private static func validate(_ menu: Menu, depth: Int, menus: inout Set<String>,
                                 items: inout Set<String>, total: inout Int) throws {
        guard depth <= 8, (1...12).contains(menu.items.count),
              !menu.id.isEmpty, !menu.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              menu.title.count <= 32, menus.insert(menu.id).inserted else {
            throw ValidationError.invalidMenu(menu.id)
        }
        for item in menu.items {
            total += 1
            guard total <= 256, !item.id.isEmpty, items.insert(item.id).inserted,
                  !item.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  item.label.count <= 24 else { throw ValidationError.invalidItem(item.id) }
            if case .menu(let child) = item.destination {
                try validate(child, depth: depth + 1, menus: &menus, items: &items, total: &total)
            }
        }
    }
}

public enum ValidationError: Error, Equatable { case invalidMenu(String), invalidItem(String) }

public enum SampleMenu {
    public static let definition: Menu = {
        do {
            let colors = try Menu(id: "colors", title: "More colors", items: [
                Item(id: "amber", label: "Amber", value: "amber"),
                Item(id: "violet", label: "Violet", value: "violet")
            ])
            return try Menu(id: "root", title: "Choose a color", items: [
                Item(id: "red", label: "Red", value: "red"),
                Item(id: "blue", label: "Blue", value: "blue"),
                Item(id: "green", label: "Green", value: "green"),
                Item(id: "more", label: "More colors", menu: colors)
            ])
        } catch { preconditionFailure("Invalid built-in fixture: \(error)") }
    }()
}
