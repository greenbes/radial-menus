import RadialCore

struct LayoutFixture {
    let name: String
    let menu: Menu
    let fontSize: Double

    init(name: String, menu: Menu, fontSize: Double = 17) {
        self.name = name; self.menu = menu; self.fontSize = fontSize
    }

    static func all(style: MenuStyle = .pie) throws -> [Self] {
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
        if style != .pie {
            fixtures.append(Self(name: "rich", menu: DemoMenu.definition))
            fixtures.append(Self(name: "large-type-rich", menu: DemoMenu.definition, fontSize: 34))
        }
        if style.showsFullTitles {
            for (name, count, title) in [
                ("6-full-title", 6, String(String(repeating: "Open recent documents in the research workspace. ", count: 4).prefix(160))),
                ("4-unicode-title", 4, String(repeating: "界", count: 160))
            ] {
                let menu = try Menu(id: "root", title: "Full title limits", items: (0..<count).map {
                    Item(id: "item-\($0)", label: "Short \($0)", title: title, value: "value-\($0)")
                })
                fixtures.append(Self(name: name, menu: menu))
            }
        }
        if style == .cards {
            let descriptions = ["", "Restore project notes and the draft proposal in their original windows.",
                                "First line\nA second line with a longer explanation.\nLast line.",
                                "研究資料とメモをまとめて表示します。 Café résumé 🙂"]
            for count in 1...12 {
                fixtures.append(Self(name: "\(count)-details", menu: try Menu(id: "root", title: "Descriptions", items: (0..<count).map {
                    Item(id: "item-\($0)", label: "Short", title: "Review the saved research material",
                         detail: descriptions[($0 + 1) % descriptions.count], value: "value-\($0)")
                })))
            }
            let maximum = String(String(repeating: "Read the saved documents and notes before continuing. ", count: 12).prefix(600))
            fixtures.append(Self(name: "2-max-detail", menu: try Menu(id: "root", title: "Description limit", items: (0..<2).map {
                Item(id: "item-\($0)", label: "Short", title: "Review the saved documents", detail: maximum, value: "value-\($0)")
            })))
        }
        return fixtures
    }
}
