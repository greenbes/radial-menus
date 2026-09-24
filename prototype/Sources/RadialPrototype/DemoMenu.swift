import RadialCore

/// Illustrative messages return values only; they do not run the described actions.
enum DemoMenu {
    static let definition: Menu = {
        do {
            return try Menu(id: "workspace", title: "Workspace actions", items: [
                Item(id: "documents", label: "Recent documents", title: "Open the documents I worked on yesterday",
                     detail: "Restore project notes and the draft proposal in their original windows.", icon: .documents, value: "documents"),
                Item(id: "research", label: "Research workspace", title: "Switch to my research workspace",
                     detail: "Bring reference material and research notes together on this desktop.", icon: .workspace, value: "research"),
                Item(id: "writing", label: "Focus for writing", title: "Arrange the windows for focused writing",
                     detail: "Center the draft, keep references to the left, and hide unrelated windows.", icon: .writing, value: "writing"),
                Item(id: "tabs", label: "Reopen tabs", title: "Reopen the last closed group of tabs",
                     detail: "Recover the reference pages from the most recently closed browser group.", icon: .history, value: "tabs"),
                Item(id: "capture", label: "Capture screen", title: "Capture this screen and copy the image",
                     detail: "Copy a full-screen image to the clipboard, ready to paste into a message.", icon: .capture, value: "capture"),
                Item(id: "commands", label: "More commands", title: "Browse saved commands and shortcuts",
                     detail: "Open another radial menu with saved actions, grouped by the work you do.", menu: SampleMenu.definition)
            ])
        } catch { preconditionFailure("Invalid message demo: \(error)") }
    }()
}
