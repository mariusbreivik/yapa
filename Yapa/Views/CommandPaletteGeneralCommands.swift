import Foundation

enum GeneralCommands: CommandPaletteRegistration {
    static func register(into items: inout [CommandPaletteItem], context: CommandPaletteContext) {
        items.append(contentsOf: [
            CommandPaletteItem(title: "New Note", subtitle: "Create a note in the current project", keywords: ["note", "create", "add"], systemImage: "doc.badge.plus", action: context.onCreateNote),
            CommandPaletteItem(title: "New Folder", subtitle: "Create a top-level project folder", keywords: ["folder", "project", "create"], systemImage: "folder.badge.plus", action: context.onCreateFolder),
            CommandPaletteItem(title: "Quick Open", subtitle: "Search notes by title", keywords: ["open", "note", "recent"], systemImage: "magnifyingglass", action: context.onOpenQuickSwitcher),
            CommandPaletteItem(title: "Search Notes", subtitle: "Search note content across the vault", keywords: ["search", "content", "fuzzy"], systemImage: "text.magnifyingglass", action: context.onOpenFuzzySearch),
            CommandPaletteItem(title: "Open Yapa Folder", subtitle: "Choose a different vault", keywords: ["vault", "root", "folder"], systemImage: "folder", action: context.onOpenVault),
            CommandPaletteItem(title: "Insert Template", subtitle: "Insert a template into the current note", keywords: ["template", "snippet", "insert"], systemImage: "doc.text.fill", action: context.onInsertTemplate)
        ])

        let recentNoteItems = context.recentNotes.prefix(5).map { note in
            CommandPaletteItem(title: note.displayTitle, subtitle: "Recent note", keywords: ["recent", "open", note.displayTitle], systemImage: "clock", action: { context.onOpenRecentNote(note) })
        }

        items.insert(contentsOf: recentNoteItems, at: min(items.count, 3))
    }
}
