import RadialCore

struct LayoutFixture {
    let name: String
    let menu: Menu
    let fontSize: Double

    init(name: String, menu: Menu, fontSize: Double = 17) {
        self.name = name; self.menu = menu; self.fontSize = fontSize
    }

    static func all() throws -> [Self] {
        let labels = [
            ("short", ["Red", "Blue", "Green", "Amber", "Violet", "Indigo", "Orange", "Pink", "Black", "White", "Gray", "Cyan"]),
            ("long", ["Open recent documents", "Switch active workspace", "Show application windows"]),
            ("wide", [String(repeating: "W", count: 24)]),
            ("multiline", ["North\nNorth\nNorth\nNorth"]),
            ("unicode", [String(repeating: "界", count: 24), "🙂👩🏽‍💻🇯🇵 Café résumé"])
        ]
        var fixtures: [Self] = []
        for count in 1...12 {
            for (profile, labels) in labels {
                let items = (0..<count).map { Item(id: "item-\($0)", label: labels[$0 % labels.count], value: "value-\($0)") }
                fixtures.append(Self(name: "\(count)-\(profile)", menu: try Menu(id: "root", title: "Layout fixture", items: items)))
            }
        }
        for name in ["4-long", "2-unicode"] {
            guard let fixture = fixtures.first(where: { $0.name == name }) else { preconditionFailure("Missing text-size fixture") }
            fixtures.append(Self(name: "large-type-" + name, menu: fixture.menu, fontSize: 34))
        }
        let child = try Menu(id: "child", title: "Nested fixture", items: (0..<12).map {
            Item(id: "child-\($0)", label: "Document collection \($0)", value: "value-\($0)")
        })
        fixtures.append(Self(name: "nested", menu: try Menu(id: "root", title: "Nested fixture", items: [
            Item(id: "more", label: "Open recent documents", menu: child),
            Item(id: "done", label: "Done", value: "done")
        ])))
        return fixtures
    }
}
