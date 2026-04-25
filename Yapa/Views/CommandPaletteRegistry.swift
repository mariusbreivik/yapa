import Foundation

struct CommandPaletteContext {
    let selectedNote: Note?
    let recentNotes: [Note]
    let onCreateNote: () -> Void
    let onCreateFolder: () -> Void
    let onOpenQuickSwitcher: () -> Void
    let onOpenFuzzySearch: () -> Void
    let onOpenFindInDocument: () -> Void
    let onOpenVault: () -> Void
    let onInsertTemplate: () -> Void
    let onRenameSelectedItem: () -> Void
    let onToggleSelectedItemPin: () -> Void
    let onMoveSelectedNote: () -> Void
    let onOpenRecentNote: (Note?) -> Void
}

protocol CommandPaletteRegistration {
    static func register(into items: inout [CommandPaletteItem], context: CommandPaletteContext)
}

enum CommandPaletteRegistry {
    static func items(context: CommandPaletteContext) -> [CommandPaletteItem] {
        var items: [CommandPaletteItem] = []
        GeneralCommands.register(into: &items, context: context)
        EditorCommands.register(into: &items, context: context)
        SidebarCommands.register(into: &items, context: context)
        return items
    }
}
