import RadialCore

/// Sample snapshots only. Selecting a row reports its value without executing it.
enum ChoiceDemo {
    static let definition: Menu = {
        do {
            func list(_ title: String, _ names: [String], detail: String) throws -> ChoiceList {
                try ChoiceList(title: title, items: names.enumerated().map {
                    ListChoice(id: "row-\($0.offset)", title: $0.element, detail: detail, value: $0.element)
                })
            }
            let sessions = ["radial-menu", "api-server", "research", "build-watch", "deploy-staging", "data-pipeline",
                            "integration-tests", "docs", "logs", "scratch", "release-review", "monitoring",
                            "database", "experiments", "backup-check", "weekend-project"]
            let tmux = try ChoiceList(title: "Active TMUX sessions", items: sessions.enumerated().map { index, name in
                ListChoice(id: "session-\(index)", title: name,
                    detail: "\([4, 3, 2, 1][index % 4]) windows" + (index == 0 ? " · attached" : ""), value: name)
            })
            return try Menu(id: "choice-demo", title: "Workspace choices", items: [
                Item(id: "tmux", label: "TMUX sessions", title: "Choose an active TMUX session",
                     detail: "Attach to an existing session. Its windows and running programs stay available.", icon: .terminal, choices: tmux),
                Item(id: "research", label: "Research workspace", title: "Switch to my research workspace",
                     detail: "Bring a workspace's windows together and continue where you left off.", icon: .workspace,
                     choices: try list("Workspaces", ["Research", "Development", "Writing", "Operations", "Personal", "Planning"], detail: "Saved workspace")),
                Item(id: "writing", label: "Focus for writing", title: "Arrange the windows for focused writing",
                     detail: "Choose an arrangement for the current display.", icon: .writing,
                     choices: try list("Window arrangements", ["Editor and references", "Editor only", "Notes alongside draft", "Research side by side", "Review and compare"], detail: "Saved arrangement")),
                Item(id: "tabs", label: "Reopen tabs", title: "Reopen the last closed group of tabs",
                     detail: "Restore a group of browser tabs from a previous session.", icon: .history,
                     choices: try list("Recent tab groups", ["Architecture notes", "SwiftUI documentation", "Controller research", "Design references", "Project planning", "Release notes", "Reading list", "API documentation"], detail: "Recently closed")),
                Item(id: "capture", label: "Capture screen", title: "Capture this screen and copy the image",
                     detail: "Choose the area to capture, then copy the image to the clipboard.", icon: .capture,
                     choices: try list("Capture area", ["Current display", "All displays", "Selected window", "Selected region"], detail: "Capture target")),
                Item(id: "commands", label: "Saved commands", title: "Browse saved commands and shortcuts",
                     detail: "Choose a saved command for the current project.", icon: .commands,
                     choices: try list("Saved commands", ["Build prototype", "Run unit tests", "Validate layouts", "Open project notes", "Show Git changes", "Start local server", "View logs", "Clean build output", "Open terminal", "Run smoke tests"], detail: "Saved command"))
            ])
        } catch { preconditionFailure("Invalid choice demo: \(error)") }
    }()
}
