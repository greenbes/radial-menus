import RadialCore

/// Four levels and several sibling branches, with illustrative results only.
enum SubmenuDemo {
    static let definition: Menu = {
        do {
            let research = try Menu(id: "research-layouts", title: "Research layouts", items: [
                Item(id: "notes-beside", label: "Notes beside sources", title: "Place notes beside the sources", icon: .writing, value: "notes-beside"),
                Item(id: "notes-below", label: "Notes below sources", title: "Place notes below the sources", icon: .writing, value: "notes-below"),
                Item(id: "references-left", label: "References on the left", title: "Keep references on the left", icon: .documents, value: "references-left"),
                Item(id: "restore-research", label: "Restore research", title: "Restore my previous research layout", icon: .history, value: "restore-research")
            ])
            let windows = try Menu(id: "window-layouts", title: "Window layouts", items: [
                Item(id: "focus-writing", label: "Focus on writing", title: "Focus on the current writing project", icon: .writing, value: "focus-writing"),
                Item(id: "research-layout", label: "Research layouts", title: "Arrange research sources and notes", icon: .workspace, menu: research),
                Item(id: "compare-documents", label: "Compare documents", title: "Compare two documents side by side", icon: .documents, value: "compare-documents"),
                Item(id: "restore-windows", label: "Restore windows", title: "Restore the previous window layout", icon: .history, value: "restore-windows")
            ])
            let tabs = try Menu(id: "tab-groups", title: "Tab groups", items: [
                Item(id: "tab-research", label: "Research sources", title: "Reopen my research sources", icon: .documents, value: "tab-research"),
                Item(id: "tab-writing", label: "Writing references", title: "Open references for writing", icon: .writing, value: "tab-writing"),
                Item(id: "tab-save", label: "Save current tabs", title: "Save the current group of tabs", icon: .commands, value: "tab-save"),
                Item(id: "tab-restore", label: "Restore closed tabs", title: "Restore recently closed tabs", icon: .history, value: "tab-restore")
            ])
            let commands = try Menu(id: "saved-commands", title: "Saved commands", items: [
                Item(id: "windows", label: "Window layouts", title: "Arrange my windows for this task", icon: .workspace, menu: windows),
                Item(id: "tab-groups", label: "Tab groups", title: "Reopen a saved group of tabs", icon: .history, menu: tabs),
                Item(id: "color-choices", label: "Colors", title: "Choose a color for this workspace", icon: .color, menu: SampleMenu.definition),
                Item(id: "yesterday", label: "Yesterday's files", title: "Open the files I used yesterday", icon: .documents, value: "yesterday")
            ])
            let documents = try Menu(id: "documents", title: "Documents", items: [
                Item(id: "project-notes", label: "Project notes", title: "Open notes for the current project", icon: .documents, value: "project-notes"),
                Item(id: "draft-proposal", label: "Draft proposal", title: "Continue writing the draft proposal", icon: .writing, value: "draft-proposal"),
                Item(id: "recent-files", label: "Recent files", title: "Show recently opened documents", icon: .history, value: "recent-files"),
                Item(id: "reference-folder", label: "Reference folder", title: "Open my folder of reference material", icon: .documents, value: "reference-folder")
            ])
            return try Menu(id: "workspace", title: "Workspace", items: [
                Item(id: "commands", label: "Saved commands", title: "Browse saved commands and shortcuts", menu: commands),
                Item(id: "documents", label: "Documents", title: "Open documents for the current project", icon: .documents, menu: documents),
                Item(id: "workspace-research", label: "Research workspace", title: "Switch to my research workspace", icon: .workspace, value: "workspace-research"),
                Item(id: "capture-screen", label: "Capture screen", title: "Capture this screen and copy the image", icon: .capture, value: "capture-screen")
            ])
        } catch { preconditionFailure("Invalid submenu demo: \(error)") }
    }()
}
