import SwiftUI
import UniformTypeIdentifiers
import CoreTransferable

public enum SidebarTreeIndentation {
    public static func leadingPadding(forDepth depth: Int) -> CGFloat {
        guard depth > 1 else {
            return 0
        }

        return 22 + CGFloat(depth - 2) * 20
    }
}

extension UTType {
    static let yapaSidebarTreeItem = UTType(exportedAs: "com.yapa.sidebar-tree-item")
}

struct SidebarTreeDragPayload: Codable, Transferable {
    enum Kind: String, Codable {
        case folder
        case note
    }

    let kind: Kind
    let urlPath: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .yapaSidebarTreeItem)
    }

    var url: URL {
        URL(fileURLWithPath: urlPath).standardizedFileURL
    }

    static func folder(_ url: URL) -> SidebarTreeDragPayload {
        SidebarTreeDragPayload(kind: .folder, urlPath: url.standardizedFileURL.path)
    }

    static func note(_ url: URL) -> SidebarTreeDragPayload {
        SidebarTreeDragPayload(kind: .note, urlPath: url.standardizedFileURL.path)
    }
}

struct SidebarView: View {
    @EnvironmentObject var fileSystemService: FileSystemService
    
    @Binding var selectedFolder: FolderItem?
    @Binding var selectedNote: Note?
    
    @State private var expandedFolders: Set<URL> = []
    @State private var editingFolderURL: URL?
    @State private var editingFolderName = ""
    @State private var editingFolderOriginalName = ""
    @State private var editingNoteURL: URL?
    @State private var editingNoteTitle = ""
    @State private var editingNoteOriginalTitle = ""
    @State private var isProjectsDropTargeted = false
    @State private var selectedTagFilters: Set<String> = []
    
    var body: some View {
        VStack(spacing: 0) {
            yapaHeader

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    tasksSection
                    pinnedSection
                    recentSection
                    foldersSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear(perform: expandDefaultProjectIfNeeded)
        .onChange(of: fileSystemService.rootFolder?.standardizedFileURL) { _, _ in
            expandedFolders = []
            expandDefaultProjectIfNeeded()
        }
        .onChange(of: fileSystemService.folderStructure) { _, _ in
            expandDefaultProjectIfNeeded()
        }
        .onChange(of: fileSystemService.lastCreatedProjectURL) { _, url in
            beginRenamingCreatedProject(at: url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .renameSelectedItem)) { _ in
            if let folder = selectedFolder {
                beginRenaming(folder)
            } else if let note = selectedNote {
                beginRenaming(note)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: createNewNote) {
                    Image(systemName: "doc.badge.plus")
                }
                .help("New Note (⌘N)")
                
                Button(action: createNewFolder) {
                    Image(systemName: "folder.badge.plus")
                }
                .help("Create a top-level project (⌘⇧N)")

                Button(action: fileSystemService.selectRootFolder) {
                    Label("Change Yapa Root", systemImage: "folder.badge.gearshape")
                }
                .labelStyle(.iconOnly)
                .help("Change Yapa Root")
            }
        }
    }

    private var yapaHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.31, green: 0.33, blue: 0.63))
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.88))
            }
            .frame(width: 76, height: 76)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(fileSystemService.rootFolder?.lastPathComponent ?? "Yapa")
                    .font(.headline)
                    .lineLimit(1)

                if let vaultLocation = vaultLocationText(for: fileSystemService.rootFolder) {
                    pathBadge(text: vaultLocation, fillOpacity: 0.07, strokeOpacity: 0.14, iconOpacity: 0.7)
                }
                
                HStack(spacing: 6) {
                    statPill(value: "\(fileSystemService.projectCount)", symbol: "folder", tooltip: "Top-level project folders in this Yapa workspace")
                    statPill(value: "\(fileSystemService.allNotes.count)", symbol: "doc.text", tooltip: "All notes in the current Yapa workspace")
                    statPill(value: "\(fileSystemService.pinnedNotes.count)", symbol: "pin.fill", tooltip: "Notes pinned for quick access")
                    statPill(value: "\(fileSystemService.recentNotes.count)", symbol: "clock", tooltip: "Most recently opened notes")
                }

                tagFilterMenu
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .padding(.trailing, 8)
        .padding(.top, 8)
    }
    
    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            sidebarSectionHeader(title: "Pinned", symbol: "pin.fill")

            ForEach(fileSystemService.pinnedNotes) { note in
                PinnedNoteRow(
                    note: note,
                    isSelected: false,
                    onSelect: { selectedNote = note },
                    onUnpin: { fileSystemService.togglePin(for: note) },
                    isEditing: editingNoteURL == note.fileURL.standardizedFileURL,
                    editingTitle: $editingNoteTitle,
                    onBeginRename: beginRenaming,
                    onRename: renameNote,
                    onCancelRename: cancelNoteRename
                )
            }
        }
    }
    
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            sidebarSectionHeader(title: "Recent", symbol: "clock.fill")

            ForEach(filteredNotes(fileSystemService.recentNotes)) { note in
                RecentNoteRow(
                    note: note,
                    isSelected: false,
                    onSelect: { selectedNote = note },
                    isEditing: editingNoteURL == note.fileURL.standardizedFileURL,
                    editingTitle: $editingNoteTitle,
                    onBeginRename: beginRenaming,
                    onRename: renameNote,
                    onCancelRename: cancelNoteRename
                )
            }
        }
    }
    
    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            sidebarSectionHeader(title: "Projects", symbol: "folder.fill")

            ForEach(fileSystemService.folderStructure.map { filteredFolder($0) }) { folder in
                FolderRowView(
                    folder: folder,
                    depth: 1,
                    projectStats: fileSystemService.projectStats(for: folder),
                    expandedFolders: $expandedFolders,
                    selectedFolder: $selectedFolder,
                    selectedNote: $selectedNote,
                    editingFolderURL: $editingFolderURL,
                    editingFolderName: $editingFolderName,
                    editingNoteURL: $editingNoteURL,
                    editingNoteTitle: $editingNoteTitle,
                    onBeginRename: beginRenaming,
                    onRename: renameFolder,
                    onBeginRenameNote: beginRenaming,
                    onRenameNote: renameNote,
                    onCancelRename: cancelFolderRename,
                    onCancelRenameNote: cancelNoteRename,
                    onCreateNote: createNote(in:),
                    onDelete: { deleteFolder(folder) },
                    onDropItems: handleDrop
                )
            }
        }
        .padding(.vertical, 2)
        .background(projectsDropBackground)
        .overlay {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(projectsDropBorder, lineWidth: isProjectsDropTargeted ? 1 : 0)

                if isProjectsDropTargeted {
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(height: 3)
                        .padding(.horizontal, 10)
                        .padding(.top, 2)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .dropDestination(for: SidebarTreeDragPayload.self) { items, _ in
            handleRootDrop(items)
        } isTargeted: { targeted in
            isProjectsDropTargeted = targeted
        }
    }

    private func sidebarSectionHeader(title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundColor(.secondary)
        .textCase(nil)
        .padding(.top, 4)
    }

    private func statPill(value: String, symbol: String, tooltip: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(value)
                .foregroundColor(Color.orange.opacity(0.9))
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.08))
        .clipShape(Capsule())
        .help(tooltip)
    }

    private var tagFilterMenu: some View {
        let availableTags = fileSystemService.availableTags()
        return Group {
            if !availableTags.isEmpty {
                Menu {
                    Button("Clear Tag Filters", action: { selectedTagFilters.removeAll() })
                    Divider()
                    ForEach(availableTags, id: \.self) { tag in
                        Button(action: { toggleTagFilter(tag) }) {
                            HStack {
                                Text(tag)
                                if selectedTagFilters.contains(tag.lowercased()) {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "tag")
                        Text(selectedTagFilters.isEmpty ? "Tags" : "Tags (\(selectedTagFilters.count))")
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(Capsule())
                }
                .menuStyle(.borderlessButton)
            }
        }
    }

    private var tasksSection: some View {
        let tasks = openTasks

        return VStack(alignment: .leading, spacing: 2) {
            sidebarSectionHeader(title: "Tasks", symbol: "checklist")

            if tasks.isEmpty {
                Text("No open tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
            } else {
                ForEach(tasks) { item in
                    Button(action: { toggleTask(item) }) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: item.task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.task.isCompleted ? .green : .secondary)
                                .font(.caption)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.task.title)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                Text(item.note.displayTitle)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggleTagFilter(_ tag: String) {
        let normalized = tag.lowercased()
        if selectedTagFilters.contains(normalized) {
            selectedTagFilters.remove(normalized)
        } else {
            selectedTagFilters.insert(normalized)
        }
    }

    private func filteredNotes(_ notes: [Note]) -> [Note] {
        fileSystemService.notes(filteredByTags: selectedTagFilters, in: notes)
    }

    private var openTasks: [NoteTask] {
        fileSystemService.allNotes
            .flatMap { note in
                note.taskItems
                    .filter { !$0.isCompleted }
                    .map { NoteTask(note: note, task: $0) }
            }
    }

    private func toggleTask(_ item: NoteTask) {
        var lines = item.note.content.components(separatedBy: .newlines)
        guard item.task.lineIndex < lines.count else { return }

        let line = lines[item.task.lineIndex].trimmingCharacters(in: .whitespaces)
        if line.hasPrefix("- [x]") || line.hasPrefix("- [X]") {
            lines[item.task.lineIndex] = line.replacingOccurrences(of: "- [x]", with: "- [ ]", options: .caseInsensitive)
        } else if line.hasPrefix("- [ ]") {
            lines[item.task.lineIndex] = line.replacingOccurrences(of: "- [ ]", with: "- [x]", options: .literal)
        }

        var updatedNote = item.note
        updatedNote.content = lines.joined(separator: "\n")
        updatedNote.modifiedAt = Date()
        fileSystemService.saveNote(updatedNote)

        if selectedNote?.fileURL.standardizedFileURL == updatedNote.fileURL.standardizedFileURL {
            selectedNote = updatedNote
        }
    }

    private func filteredFolder(_ folder: FolderItem) -> FolderItem {
        let filteredChildren = folder.children.map(filteredFolder).filter { !$0.notes.isEmpty || !$0.children.isEmpty }
        let filteredNotes = fileSystemService.notes(filteredByTags: selectedTagFilters, in: folder.notes)
        return FolderItem(id: folder.id, name: folder.name, url: folder.url, isExpanded: folder.isExpanded, children: filteredChildren, notes: filteredNotes)
    }

    private func createNewNote() {
        let folder = selectedFolder?.url ?? fileSystemService.folderStructure.first?.url
        guard let folder else { return }
        if let newNote = fileSystemService.createNote(in: folder) {
            selectedNote = newNote
        }
    }

    private func createNote(in folder: FolderItem) {
        selectedFolder = folder
        selectedNote = fileSystemService.createNote(in: folder.url)
    }
    
    private func createNewFolder() {
        _ = fileSystemService.createTopLevelProject()
    }
    
    private func deleteFolder(_ folder: FolderItem) {
        fileSystemService.deleteFolder(folder.url)
        if selectedFolder?.url.standardizedFileURL == folder.url.standardizedFileURL {
            selectedFolder = nil
        }
    }

    private func beginRenaming(_ folder: FolderItem) {
        selectedFolder = folder
        selectedNote = nil
        editingFolderURL = folder.url.standardizedFileURL
        editingFolderName = folder.name
        editingFolderOriginalName = folder.name
    }

    private func renameFolder(_ folder: FolderItem, to newName: String) {
        let oldURL = folder.url.standardizedFileURL
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            cancelFolderRename()
            return
        }

        guard let newURL = fileSystemService.renameFolder(folder.url, to: trimmedName) else {
            return
        }

        editingFolderURL = nil
        editingFolderName = ""
        editingFolderOriginalName = ""
        selectedNote = nil
        selectedFolder = resolveFolder(matching: newURL)
        remapExpandedFolders(from: oldURL, to: newURL)
    }

    private func beginRenaming(_ note: Note) {
        selectedNote = note
        editingNoteURL = note.fileURL.standardizedFileURL
        editingNoteTitle = note.displayTitle
        editingNoteOriginalTitle = note.displayTitle
    }

    private func renameNote(_ note: Note, to newTitle: String) {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            cancelNoteRename()
            return
        }

        guard let updatedNote = fileSystemService.renameNote(note, to: trimmedTitle) else {
            return
        }

        editingNoteURL = nil
        editingNoteTitle = ""
        editingNoteOriginalTitle = ""
        selectedNote = updatedNote
    }

    private func cancelFolderRename() {
        editingFolderURL = nil
        editingFolderName = editingFolderOriginalName
        editingFolderOriginalName = ""
    }

    private func cancelNoteRename() {
        editingNoteURL = nil
        editingNoteTitle = editingNoteOriginalTitle
        editingNoteOriginalTitle = ""
    }

    private func resolveFolder(matching url: URL) -> FolderItem? {
        findFolder(matching: url.standardizedFileURL, in: fileSystemService.folderStructure)
    }

    private func findFolder(matching url: URL, in folders: [FolderItem]) -> FolderItem? {
        for folder in folders {
            if folder.url.standardizedFileURL == url {
                return folder
            }

            if let child = findFolder(matching: url, in: folder.children) {
                return child
            }
        }

        return nil
    }

    private func remapExpandedFolders(from oldURL: URL, to newURL: URL) {
        let oldPath = oldURL.standardizedFileURL.path
        let newPath = newURL.standardizedFileURL.path

        expandedFolders = Set(expandedFolders.map { url in
            let path = url.standardizedFileURL.path

            if path == oldPath {
                return newURL.standardizedFileURL
            }

            guard path.hasPrefix(oldPath + "/") else {
                return url.standardizedFileURL
            }

            let suffix = String(path.dropFirst(oldPath.count))
            return URL(fileURLWithPath: newPath + suffix)
        })
    }

    private func resolveNote(matching url: URL) -> Note? {
        fileSystemService.allNotes.first { $0.fileURL.standardizedFileURL == url.standardizedFileURL }
    }

    private func handleDrop(_ items: [SidebarTreeDragPayload], into folder: FolderItem) -> Bool {
        guard let item = items.first else { return false }

        switch item.kind {
        case .folder:
            let oldURL = item.url
            guard let newURL = fileSystemService.moveFolder(oldURL, to: folder.url) else { return false }
            remapExpandedFolders(from: oldURL, to: newURL)
            if selectedFolder?.url.standardizedFileURL == oldURL {
                selectedFolder = resolveFolder(matching: newURL)
            }
            return true
        case .note:
            guard let note = resolveNote(matching: item.url) else { return false }
            guard let updatedNote = fileSystemService.moveNote(note, to: folder.url) else { return false }
            if selectedNote?.fileURL.standardizedFileURL == note.fileURL.standardizedFileURL {
                selectedFolder = folder
                selectedNote = updatedNote
            }
            return true
        }
    }

    private func handleRootDrop(_ items: [SidebarTreeDragPayload]) -> Bool {
        guard let rootFolder = fileSystemService.rootFolder else { return false }
        guard let item = items.first else { return false }

        switch item.kind {
        case .folder:
            let oldURL = item.url
            guard let newURL = fileSystemService.moveFolder(oldURL, to: rootFolder) else { return false }
            remapExpandedFolders(from: oldURL, to: newURL)
            if selectedFolder?.url.standardizedFileURL == oldURL {
                selectedFolder = resolveFolder(matching: newURL)
            }
            return true
        case .note:
            return false
        }
    }

    private var projectsDropBackground: Color {
        isProjectsDropTargeted ? Color.accentColor.opacity(0.05) : .clear
    }

    private var projectsDropBorder: Color {
        isProjectsDropTargeted ? Color.accentColor.opacity(0.35) : .clear
    }

    private func expandDefaultProjectIfNeeded() {
        guard expandedFolders.isEmpty else { return }
        guard fileSystemService.folderStructure.count == 1 else { return }

        let project = fileSystemService.folderStructure[0]
        guard project.name == "My first project" else { return }

        expandedFolders.insert(project.url.standardizedFileURL)
    }

    private func beginRenamingCreatedProject(at url: URL?) {
        guard let url else { return }
        guard let folder = resolveFolder(matching: url) else { return }

        selectedFolder = folder
        selectedNote = nil
        editingFolderURL = url.standardizedFileURL
        editingFolderName = folder.name
        editingFolderOriginalName = folder.name
        expandedFolders.insert(url.standardizedFileURL)
    }

}

private struct NoteTask: Identifiable {
    let note: Note
    let task: TaskItem
    var id: String { "\(note.fileURL.standardizedFileURL.path)#\(task.lineIndex)" }
}

struct FolderRowView: View {
    let folder: FolderItem
    let depth: Int
    let projectStats: (notes: Int, folders: Int, words: Int, chars: Int)?
    @Binding var expandedFolders: Set<URL>
    @Binding var selectedFolder: FolderItem?
    @Binding var selectedNote: Note?
    @Binding var editingFolderURL: URL?
    @Binding var editingFolderName: String
    @Binding var editingNoteURL: URL?
    @Binding var editingNoteTitle: String
    let onBeginRename: (FolderItem) -> Void
    let onRename: (FolderItem, String) -> Void
    let onBeginRenameNote: (Note) -> Void
    let onRenameNote: (Note, String) -> Void
    let onCancelRename: () -> Void
    let onCancelRenameNote: () -> Void
    let onCreateNote: (FolderItem) -> Void
    let onDelete: () -> Void
    let onDropItems: ([SidebarTreeDragPayload], FolderItem) -> Bool
    
    @State private var isHovering = false
    @State private var isDropTargeted = false
    @FocusState private var isRenameFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if !folder.children.isEmpty || !folder.notes.isEmpty {
                    Button(action: toggleExpanded) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                } else {
                    Color.clear.frame(width: 22, height: 22)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.accentColor)
                }
                
                if isEditing {
                    TextField("Folder name", text: $editingFolderName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .focused($isRenameFocused)
                        .onSubmit { onRename(folder, editingFolderName) }
                        .onExitCommand(perform: onCancelRename)
                } else {
                    HStack(spacing: 6) {
                        Text(folder.name)
                            .lineLimit(1)

                        if let projectStats, depth == 1 {
                            statPill(value: "\(projectStats.notes)", symbol: "doc.text", tooltip: "Notes in this project")
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 1)
            .padding(.horizontal, 8)
            .padding(.leading, leadingPadding)
            .frame(minHeight: 26)
            .background(backgroundColor)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture {
                selectedFolder = folder
                selectedNote = nil
                toggleExpanded()
            }
            .onHover { hovering in
                isHovering = hovering
            }
            .contextMenu {
                Button("New Note") { onCreateNote(folder) }
                    .keyboardShortcut("n", modifiers: [.command])
                Button("Rename Folder", action: { onBeginRename(folder) })
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Delete Folder", role: .destructive, action: onDelete)
                    .keyboardShortcut(.delete, modifiers: [.command])
            }
            .draggable(SidebarTreeDragPayload.folder(folder.url))
            .dropDestination(for: SidebarTreeDragPayload.self) { items, _ in
                onDropItems(items, folder)
            } isTargeted: { targeted in
                isDropTargeted = targeted
            }
            .onChange(of: isEditing) { _, editing in
                if editing {
                    DispatchQueue.main.async {
                        isRenameFocused = true
                    }
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(folder.children) { child in
                        FolderRowView(
                            folder: child,
                            depth: depth + 1,
                            projectStats: nil,
                            expandedFolders: $expandedFolders,
                            selectedFolder: $selectedFolder,
                            selectedNote: $selectedNote,
                            editingFolderURL: $editingFolderURL,
                            editingFolderName: $editingFolderName,
                            editingNoteURL: $editingNoteURL,
                            editingNoteTitle: $editingNoteTitle,
                            onBeginRename: onBeginRename,
                            onRename: onRename,
                            onBeginRenameNote: onBeginRenameNote,
                            onRenameNote: onRenameNote,
                            onCancelRename: onCancelRename,
                            onCancelRenameNote: onCancelRenameNote,
                            onCreateNote: onCreateNote,
                            onDelete: { fileSystemService.deleteFolder(child.url) },
                            onDropItems: onDropItems
                        )
                    }

                    ForEach(folder.notes) { note in
                        FolderNoteRow(
                            note: note,
                            depth: depth + 1,
                            isSelected: selectedNote?.fileURL.standardizedFileURL == note.fileURL.standardizedFileURL,
                            isEditing: editingNoteURL == note.fileURL.standardizedFileURL,
                            editingTitle: $editingNoteTitle,
                            onBeginRename: onBeginRenameNote,
                            onRename: onRenameNote,
                            onCancelRename: onCancelRenameNote,
                            onSelect: {
                                selectedFolder = folder
                                selectedNote = note
                            }
                        )
                    }
                }
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 1)
                        .padding(.leading, 16)
                }
            }
        }
    }
    
    private var isExpanded: Bool {
        expandedFolders.contains(folder.url.standardizedFileURL)
    }
    
    private var isSelected: Bool {
        selectedFolder?.url.standardizedFileURL == folder.url.standardizedFileURL
    }

    private var isEditing: Bool {
        editingFolderURL == folder.url.standardizedFileURL
    }
    
    private var leadingPadding: CGFloat {
        sidebarTreeLeadingPadding(forDepth: depth)
    }

    private var backgroundColor: Color {
        if isDropTargeted {
            return Color.accentColor.opacity(0.12)
        }
        if isHovering {
            return Color.secondary.opacity(0.08)
        }
        return Color.clear
    }

    private var borderColor: Color {
        if isDropTargeted {
            return Color.accentColor.opacity(0.4)
        }
        if isHovering {
            return Color.secondary.opacity(0.16)
        }
        return Color.clear
    }
    
    private var fileSystemService: FileSystemService {
        FileSystemService.shared
    }

    private func statPill(value: String, symbol: String, tooltip: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(value)
                .foregroundColor(Color.orange.opacity(0.9))
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.08))
        .clipShape(Capsule())
        .help(tooltip)
    }

    private func formatCount(_ count: Int) -> String {
        switch count {
        case 0..<1_000: return "\(count)"
        case 1_000..<1_000_000: return String(format: "%.1fk", Double(count) / 1_000.0)
        default: return String(format: "%.1fM", Double(count) / 1_000_000.0)
        }
    }
    
    private func toggleExpanded() {
        let url = folder.url.standardizedFileURL
        if expandedFolders.contains(url) {
            expandedFolders.remove(url)
        } else {
            expandedFolders.insert(url)
        }
    }
}

struct FolderNoteRow: View {
    let note: Note
    let depth: Int
    let isSelected: Bool
    let isEditing: Bool
    @Binding var editingTitle: String
    let onBeginRename: (Note) -> Void
    let onRename: (Note, String) -> Void
    let onCancelRename: () -> Void
    let onSelect: () -> Void
    
    @State private var isHovering = false
    @FocusState private var isRenameFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Color.clear
                .frame(width: 22, height: 22)

            Image(systemName: note.isPinned ? "pin.fill" : "doc.text")
                .font(.caption2)
                .foregroundColor(note.isPinned ? .orange : .secondary)
            
                if isEditing {
                    TextField("Note title", text: $editingTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .focused($isRenameFocused)
                        .onSubmit { onRename(note, editingTitle) }
                        .onExitCommand(perform: onCancelRename)
                } else {
                Text(note.displayTitle)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.vertical, 1)
        .padding(.leading, leadingPadding)
        .padding(.horizontal, 8)
        .background(backgroundColor)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Rename Note", action: { onBeginRename(note) })
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
        .draggable(SidebarTreeDragPayload.note(note.fileURL))
        .onChange(of: isEditing) { _, editing in
            if editing {
                DispatchQueue.main.async {
                    isRenameFocused = true
                }
            }
        }
    }
    
    private var backgroundColor: Color {
        if isHovering {
            return Color.secondary.opacity(0.08)
        }
        return Color.clear
    }

    private var borderColor: Color {
        if isHovering {
            return Color.secondary.opacity(0.16)
        }
        return Color.clear
    }

    private var leadingPadding: CGFloat {
        sidebarTreeLeadingPadding(forDepth: depth)
    }
}

struct PinnedNoteRow: View {
    let note: Note
    let isSelected: Bool
    let onSelect: () -> Void
    let onUnpin: () -> Void
    let isEditing: Bool
    @Binding var editingTitle: String
    let onBeginRename: (Note) -> Void
    let onRename: (Note, String) -> Void
    let onCancelRename: () -> Void
    
    @State private var isHovering = false
    @FocusState private var isRenameFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "pin.fill")
                .font(.caption)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                if isEditing {
                    TextField("Note title", text: $editingTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .focused($isRenameFocused)
                        .onSubmit { onRename(note, editingTitle) }
                        .onExitCommand(perform: onCancelRename)
                } else {
                    Text(note.displayTitle)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                }
                
                Text(formattedDate)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()

            Button(action: onUnpin) {
                Image(systemName: "pin.slash")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .opacity(isHovering || isSelected ? 1 : 0.35)
            .help("Unpin")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(backgroundColor)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Rename Note", action: { onBeginRename(note) })
                .keyboardShortcut("r", modifiers: [.command, .shift])
            Button("Unpin", action: onUnpin)
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                DispatchQueue.main.async {
                    isRenameFocused = true
                }
            }
        }
        .onChange(of: isRenameFocused) { _, focused in
            if !focused, isEditing {
                onRename(note, editingTitle)
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.10)
        } else if isHovering {
            return Color.secondary.opacity(0.08)
        }
        return Color.clear
    }

    private var borderColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.14)
        } else if isHovering {
            return Color.secondary.opacity(0.16)
        }
        return Color.clear
    }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: note.pinnedAt ?? note.lastAccessedAt, relativeTo: Date())
    }
}

struct RecentNoteRow: View {
    let note: Note
    let isSelected: Bool
    let onSelect: () -> Void
    let isEditing: Bool
    @Binding var editingTitle: String
    let onBeginRename: (Note) -> Void
    let onRename: (Note, String) -> Void
    let onCancelRename: () -> Void
    
    @State private var isHovering = false
    @FocusState private var isRenameFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                if isEditing {
                    TextField("Note title", text: $editingTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .focused($isRenameFocused)
                        .onSubmit { onRename(note, editingTitle) }
                        .onExitCommand(perform: onCancelRename)
                } else {
                    Text(note.displayTitle)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                }
                
                Text("Last opened \(formattedDate)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(backgroundColor)
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Rename Note", action: { onBeginRename(note) })
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                DispatchQueue.main.async {
                    isRenameFocused = true
                }
            }
        }
        .onChange(of: isRenameFocused) { _, focused in
            if !focused, isEditing {
                onRename(note, editingTitle)
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        } else if isHovering {
            return Color.secondary.opacity(0.1)
        }
        return Color.clear
    }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: note.lastAccessedAt, relativeTo: Date())
    }
}
