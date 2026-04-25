import XCTest
@testable import Yapa

final class ContentViewTests: XCTestCase {
    func testCommandPaletteCatalogOmitsNoteOnlyActionsWhenNoNoteIsOpen() {
        let items = CommandPaletteRegistry.items(context: CommandPaletteContext(
            selectedNote: nil,
            recentNotes: [],
            onCreateNote: {},
            onCreateFolder: {},
            onOpenQuickSwitcher: {},
            onOpenFuzzySearch: {},
            onOpenFindInDocument: {},
            onOpenVault: {},
            onInsertTemplate: {},
            onRenameSelectedItem: {},
            onToggleSelectedItemPin: {},
            onMoveSelectedNote: {},
            onOpenRecentNote: { _ in }
        ))

        XCTAssertFalse(items.contains(where: { $0.title == "Find in Document" }))
        XCTAssertFalse(items.contains(where: { $0.title == "Toggle Pin" }))
        XCTAssertFalse(items.contains(where: { $0.title == "Move Note" }))
    }

    func testCommandPaletteCatalogIncludesEditorAndSidebarActionsWhenNoteIsOpen() {
        let note = Note(
            title: "Test",
            content: "Hello",
            createdAt: Date(),
            modifiedAt: Date(),
            fileURL: URL(fileURLWithPath: "/tmp/yapa/Project/Test.md"),
            isPinned: true,
            pinnedAt: nil,
            lastAccessedAt: Date(),
            tags: []
        )

        let items = CommandPaletteRegistry.items(context: CommandPaletteContext(
            selectedNote: note,
            recentNotes: [],
            onCreateNote: {},
            onCreateFolder: {},
            onOpenQuickSwitcher: {},
            onOpenFuzzySearch: {},
            onOpenFindInDocument: {},
            onOpenVault: {},
            onInsertTemplate: {},
            onRenameSelectedItem: {},
            onToggleSelectedItemPin: {},
            onMoveSelectedNote: {},
            onOpenRecentNote: { _ in }
        ))

        XCTAssertTrue(items.contains(where: { $0.title == "Find in Document" }))
        XCTAssertTrue(items.contains(where: { $0.title == "Toggle Pin" }))
        XCTAssertTrue(items.contains(where: { $0.title == "Move Note" }))
        XCTAssertTrue(items.contains(where: { $0.title == "Rename Item" }))
    }

    func testCommandPaletteItemMatchesTitleKeywordsAndSubtitle() {
        let item = CommandPaletteItem(
            title: "Insert Template",
            subtitle: "Insert a template into the current note",
            keywords: ["template", "snippet"],
            systemImage: "doc.text.fill",
            action: {}
        )

        XCTAssertTrue(item.matches("snippet"))
        XCTAssertTrue(item.matches("current note"))
        XCTAssertFalse(item.matches("rename"))
    }

    func testCommandPaletteRegistryReturnsRecentNotesNearTop() {
        let note = Note(
            title: "Recent One",
            content: "Hello",
            createdAt: Date(),
            modifiedAt: Date(),
            fileURL: URL(fileURLWithPath: "/tmp/yapa/Project/Recent.md"),
            isPinned: false,
            pinnedAt: nil,
            lastAccessedAt: Date(),
            tags: []
        )

        let items = CommandPaletteRegistry.items(context: CommandPaletteContext(
            selectedNote: nil,
            recentNotes: [note],
            onCreateNote: {},
            onCreateFolder: {},
            onOpenQuickSwitcher: {},
            onOpenFuzzySearch: {},
            onOpenFindInDocument: {},
            onOpenVault: {},
            onInsertTemplate: {},
            onRenameSelectedItem: {},
            onToggleSelectedItemPin: {},
            onMoveSelectedNote: {},
            onOpenRecentNote: { _ in }
        ))

        XCTAssertEqual(items.first?.title, "New Note")
        XCTAssertTrue(items.contains(where: { $0.title == "Recent One" }))
    }

    func testGeneralCommandsRegisterExpectedCoreActions() {
        var items: [CommandPaletteItem] = []
        GeneralCommands.register(into: &items, context: CommandPaletteContext(
            selectedNote: nil,
            recentNotes: [],
            onCreateNote: {},
            onCreateFolder: {},
            onOpenQuickSwitcher: {},
            onOpenFuzzySearch: {},
            onOpenFindInDocument: {},
            onOpenVault: {},
            onInsertTemplate: {},
            onRenameSelectedItem: {},
            onToggleSelectedItemPin: {},
            onMoveSelectedNote: {},
            onOpenRecentNote: { _ in }
        ))

        XCTAssertTrue(items.contains(where: { $0.title == "New Note" }))
        XCTAssertTrue(items.contains(where: { $0.title == "Insert Template" }))
        XCTAssertFalse(items.contains(where: { $0.title == "Find in Document" }))
    }

    func testEditorCommandsRegisterOnlyWhenNoteExists() {
        var items: [CommandPaletteItem] = []
        EditorCommands.register(into: &items, context: CommandPaletteContext(
            selectedNote: nil,
            recentNotes: [],
            onCreateNote: {},
            onCreateFolder: {},
            onOpenQuickSwitcher: {},
            onOpenFuzzySearch: {},
            onOpenFindInDocument: {},
            onOpenVault: {},
            onInsertTemplate: {},
            onRenameSelectedItem: {},
            onToggleSelectedItemPin: {},
            onMoveSelectedNote: {},
            onOpenRecentNote: { _ in }
        ))

        XCTAssertTrue(items.isEmpty)
    }

    func testEditorCommandsRegisterFindPinAndMove() {
        let note = Note(
            title: "Test",
            content: "Hello",
            createdAt: Date(),
            modifiedAt: Date(),
            fileURL: URL(fileURLWithPath: "/tmp/yapa/Project/Test.md"),
            isPinned: false,
            pinnedAt: nil,
            lastAccessedAt: Date(),
            tags: []
        )

        var items: [CommandPaletteItem] = []
        EditorCommands.register(into: &items, context: CommandPaletteContext(
            selectedNote: note,
            recentNotes: [],
            onCreateNote: {},
            onCreateFolder: {},
            onOpenQuickSwitcher: {},
            onOpenFuzzySearch: {},
            onOpenFindInDocument: {},
            onOpenVault: {},
            onInsertTemplate: {},
            onRenameSelectedItem: {},
            onToggleSelectedItemPin: {},
            onMoveSelectedNote: {},
            onOpenRecentNote: { _ in }
        ))

        XCTAssertTrue(items.contains(where: { $0.title == "Find in Document" }))
        XCTAssertTrue(items.contains(where: { $0.title == "Toggle Pin" }))
        XCTAssertTrue(items.contains(where: { $0.title == "Move Note" }))
    }

    func testSidebarCommandsRegisterOnlyWhenNoteExists() {
        var items: [CommandPaletteItem] = []
        SidebarCommands.register(into: &items, context: CommandPaletteContext(
            selectedNote: nil,
            recentNotes: [],
            onCreateNote: {},
            onCreateFolder: {},
            onOpenQuickSwitcher: {},
            onOpenFuzzySearch: {},
            onOpenFindInDocument: {},
            onOpenVault: {},
            onInsertTemplate: {},
            onRenameSelectedItem: {},
            onToggleSelectedItemPin: {},
            onMoveSelectedNote: {},
            onOpenRecentNote: { _ in }
        ))

        XCTAssertTrue(items.isEmpty)
    }

    func testSidebarCommandsRegisterRenameForSelectedNote() {
        let note = Note(
            title: "Test",
            content: "Hello",
            createdAt: Date(),
            modifiedAt: Date(),
            fileURL: URL(fileURLWithPath: "/tmp/yapa/Project/Test.md"),
            isPinned: false,
            pinnedAt: nil,
            lastAccessedAt: Date(),
            tags: []
        )

        var items: [CommandPaletteItem] = []
        SidebarCommands.register(into: &items, context: CommandPaletteContext(
            selectedNote: note,
            recentNotes: [],
            onCreateNote: {},
            onCreateFolder: {},
            onOpenQuickSwitcher: {},
            onOpenFuzzySearch: {},
            onOpenFindInDocument: {},
            onOpenVault: {},
            onInsertTemplate: {},
            onRenameSelectedItem: {},
            onToggleSelectedItemPin: {},
            onMoveSelectedNote: {},
            onOpenRecentNote: { _ in }
        ))

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.title, "Rename Item")
    }

    func testProjectRootHelperFindsParentProjectForNestedFolder() {
        let root = URL(fileURLWithPath: "/tmp/yapa")
        let project = FolderItem(name: "Project", url: root.appendingPathComponent("Project", isDirectory: true))
        let nested = root.appendingPathComponent("Project/Notes/Today", isDirectory: true)

        let result = projectRoot(containing: nested, in: [project])

        XCTAssertEqual(result?.name, "Project")
    }

    func testProjectRootHelperReturnsNilOutsideProjects() {
        let project = FolderItem(name: "Project", url: URL(fileURLWithPath: "/tmp/yapa/Project", isDirectory: true))
        let outside = URL(fileURLWithPath: "/tmp/yapa/Other", isDirectory: true)

        XCTAssertNil(projectRoot(containing: outside, in: [project]))
    }
}
