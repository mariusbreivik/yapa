import SwiftUI

struct ContentView: View {
    @EnvironmentObject var fileSystemService: FileSystemService
    @EnvironmentObject var searchService: SearchService
    
    @State private var selectedFolder: FolderItem?
    @State private var selectedNote: Note?
    @State private var showSidebar = true
    @State private var showQuickSwitcher = false
    @State private var showFuzzySearch = false
    @State private var showDocumentFind = false
    @State private var fuzzySearchText = ""
    @State private var lastAutoOpenedVaultURL: URL?
    
    var body: some View {
        Group {
            if fileSystemService.rootFolder == nil {
                  LaunchScreenView(
                      workspaceName: nil,
                      projectName: nil,
                      vaultLocation: nil,
                      noteCount: fileSystemService.allNotes.count,
                     wordCount: fileSystemService.totalWordCount,
                     characterCount: fileSystemService.totalCharacterCount,
                     totalVaultSizeBytes: fileSystemService.totalVaultSizeBytes,
                     pinnedCount: fileSystemService.pinnedNotes.count,
                     recentCount: fileSystemService.recentNotes.count,
                     staleCount: fileSystemService.staleNoteCount,
                     streakDays: fileSystemService.activityStreakDays,
                     averageNoteLength: fileSystemService.averageNoteLength,
                     recentNote: fileSystemService.recentNotes.first,
                     recentVaults: getRecentVaults(),
                     isVaultOpen: false,
                     onOpenVault: { fileSystemService.selectRootFolder() },
                     onOpenRecentVault: { url in openRecentVault(at: url) },
                     onCreateNote: createNewNote,
                     onCreateFolder: createNewFolder,
                     onOpenRecentNote: { openRecentNote(fileSystemService.recentNotes.first) },
                     onQuickOpen: { showQuickSwitcher = true },
                     onSearch: { openFuzzySearch() }
                 )
            } else if let error = fileSystemService.rootStructureError {
                YapaStructureIssueView(
                    message: error,
                    onOpenVault: { fileSystemService.selectRootFolder() }
                )
            } else {
                mainContent
            }
        }
        .onAppear {
            setupNotifications()
            restoreLastOpenedNoteIfNeeded()
        }
        .onChange(of: fileSystemService.rootFolder?.standardizedFileURL) { _, _ in
            restoreLastOpenedNoteIfNeeded()
        }
        .onChange(of: fileSystemService.recentNotes.first?.fileURL.standardizedFileURL) { _, _ in
            restoreLastOpenedNoteIfNeeded()
        }
        .sheet(isPresented: $showQuickSwitcher) {
            QuickSwitcherView(
                isPresented: $showQuickSwitcher,
                selectedNote: $selectedNote
            )
            .environmentObject(fileSystemService)
        }
    }
    
    private var mainContent: some View {
        HSplitView {
            if showSidebar {
                SidebarView(
                    selectedFolder: $selectedFolder,
                    selectedNote: $selectedNote,
                )
                .frame(minWidth: 250, idealWidth: 300, maxWidth: 380)
            }
            
            if let note = selectedNote {
                EditorView(note: note, onMoveNote: handleMovedNote, showFindBar: $showDocumentFind)
                    .id(note.fileURL.standardizedFileURL)
                    .frame(minWidth: 400)
            } else if showFuzzySearch {
                SearchResultsView(
                    searchText: $fuzzySearchText,
                    selectedNote: $selectedNote,
                    isPresented: $showFuzzySearch
                )
                .environmentObject(fileSystemService)
                .environmentObject(searchService)
            } else if let project = activeProjectFolder {
                LaunchScreenView(
                    workspaceName: fileSystemService.rootFolder?.lastPathComponent,
                    projectName: project.name,
                      vaultLocation: vaultLocationText(for: fileSystemService.rootFolder),
                    noteCount: fileSystemService.allNotes.count,
                    wordCount: fileSystemService.totalWordCount,
                    characterCount: fileSystemService.totalCharacterCount,
                    totalVaultSizeBytes: fileSystemService.totalVaultSizeBytes,
                    pinnedCount: fileSystemService.pinnedNotes.count,
                    recentCount: fileSystemService.recentNotes.count,
                    staleCount: fileSystemService.staleNoteCount,
                    streakDays: fileSystemService.activityStreakDays,
                    averageNoteLength: fileSystemService.averageNoteLength,
                    recentNote: fileSystemService.recentNotes.first,
                    recentVaults: getRecentVaults(),
                    isVaultOpen: true,
                    onOpenVault: { fileSystemService.selectRootFolder() },
                     onOpenRecentVault: { url in openRecentVault(at: url) },
                    onCreateNote: createNewNoteInCurrentProject,
                    onCreateFolder: createNewFolderInCurrentProject,
                    onOpenRecentNote: { openRecentNote(fileSystemService.recentNotes.first) },
                    onQuickOpen: { showQuickSwitcher = true },
                    onSearch: { openFuzzySearch() }
                )
            } else {
                NoProjectSelectedView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSidebar)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .createNewNote,
            object: nil,
            queue: .main
        ) { _ in
            createNewNote()
        }
        
        NotificationCenter.default.addObserver(
            forName: .createNewFolder,
            object: nil,
            queue: .main
        ) { _ in
            createNewFolder()
        }
        
        NotificationCenter.default.addObserver(
            forName: .focusSearch,
            object: nil,
            queue: .main
        ) { _ in
            if selectedNote != nil {
                showDocumentFind = true
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .openQuickSwitcher,
            object: nil,
            queue: .main
        ) { _ in
            showQuickSwitcher = true
        }

        NotificationCenter.default.addObserver(
            forName: .openFuzzySearch,
            object: nil,
            queue: .main
        ) { _ in
            openFuzzySearch()
        }
    }
    
    private func createNewNote() {
        guard fileSystemService.rootFolder != nil else {
            fileSystemService.selectRootFolder()
            return
        }

        guard let folder = activeProjectFolder?.url ?? fileSystemService.folderStructure.first?.url else { return }
        if let newNote = fileSystemService.createNote(in: folder) {
            selectedNote = newNote
        }
    }

    private func createNewNoteInCurrentProject() {
        guard let parent = activeProjectFolder?.url else { return }
        if let newNote = fileSystemService.createNote(in: parent) {
            selectedFolder = resolveFolder(matching: parent)
            selectedNote = newNote
        }
    }
    
    private func createNewFolder() {
        _ = fileSystemService.createTopLevelProject()
    }

    private func createNewFolderInCurrentProject() {
        guard let parent = activeProjectFolder?.url else { return }
        _ = fileSystemService.createFolder(in: parent, name: "New Folder")
        selectedFolder = resolveFolder(matching: parent)
        selectedNote = nil
    }

    private func openFuzzySearch() {
        guard fileSystemService.rootFolder != nil else { return }
        showQuickSwitcher = false
        showFuzzySearch = true
        fuzzySearchText = ""
        selectedNote = nil
    }

    private func restoreLastOpenedNoteIfNeeded() {
        guard fileSystemService.rootFolder != nil else { return }
        guard selectedNote == nil else { return }

        let currentVaultURL = fileSystemService.rootFolder?.standardizedFileURL
        guard lastAutoOpenedVaultURL != currentVaultURL else { return }

        if let recent = fileSystemService.recentNotes.first {
            openRecentNote(recent)
        }

        lastAutoOpenedVaultURL = currentVaultURL
    }

    private func openRecentNote(_ note: Note?) {
        guard let note else { return }
        selectedNote = note
        selectedFolder = resolveFolder(matching: note.fileURL.deletingLastPathComponent())
    }
    
    private func handleMovedNote(_ note: Note) {
        selectedNote = note
        selectedFolder = resolveFolder(matching: note.fileURL.deletingLastPathComponent())
    }
    
    private func resolveFolder(matching url: URL) -> FolderItem? {
        resolveFolder(matching: url.standardizedFileURL, in: fileSystemService.folderStructure)
    }
    
    private func resolveFolder(matching url: URL, in folders: [FolderItem]) -> FolderItem? {
        for folder in folders {
            if folder.url.standardizedFileURL == url {
                return folder
            }
            
            if let child = resolveFolder(matching: url, in: folder.children) {
                return child
            }
        }
        
        return nil
    }

    private var activeProjectFolder: FolderItem? {
        if let selectedFolder {
            return projectRoot(containing: selectedFolder.url)
        }

        if let selectedNote {
            return projectRoot(containing: selectedNote.fileURL.deletingLastPathComponent())
        }

        return nil
    }

    private func projectRoot(containing url: URL) -> FolderItem? {
        Yapa.projectRoot(containing: url, in: fileSystemService.folderStructure)
    }

}

func projectRoot(containing url: URL, in folderStructure: [FolderItem]) -> FolderItem? {
    let targetPath = url.standardizedFileURL.path
    return folderStructure.first { project in
        let projectPath = project.url.standardizedFileURL.path
        return targetPath == projectPath || targetPath.hasPrefix(projectPath + "/")
    }
}

func vaultLocationText(for url: URL?) -> String? {
    url?.standardizedFileURL.path
}

func pathBadge(text: String, fillOpacity: Double, strokeOpacity: Double, iconOpacity: Double) -> some View {
    Label {
        Text(text)
            .font(.caption)
            .monospaced()
            .lineLimit(1)
            .truncationMode(.middle)
    } icon: {
        Image(systemName: "externaldrive")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.orange.opacity(iconOpacity))
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(
        Capsule(style: .continuous)
            .fill(Color.orange.opacity(fillOpacity))
    )
    .overlay(
        Capsule(style: .continuous)
            .stroke(Color.orange.opacity(strokeOpacity), lineWidth: 1)
    )
    .foregroundStyle(Color.orange.opacity(0.92))
}

struct LaunchScreenView: View {
    let workspaceName: String?
    let projectName: String?
    let vaultLocation: String?
    let noteCount: Int
    let wordCount: Int
    let characterCount: Int
    let totalVaultSizeBytes: Int64
    let pinnedCount: Int
    let recentCount: Int
    let staleCount: Int
    let streakDays: Int
    let averageNoteLength: Double
    let recentNote: Note?
    let recentVaults: [URL]
    let isVaultOpen: Bool
    let onOpenVault: () -> Void
    let onOpenRecentVault: (URL) -> Void
    let onCreateNote: () -> Void
    let onCreateFolder: () -> Void
    let onOpenRecentNote: () -> Void
    let onQuickOpen: () -> Void
    let onSearch: () -> Void

    private let metricsColumns = [
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 14),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 14),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 14)
    ]
    
    var body: some View {
        ScrollView {
                VStack(spacing: 18) {
                VStack(spacing: 10) {
                    Image(systemName: isVaultOpen ? "doc.text.magnifyingglass" : "folder.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                        .symbolEffect(.pulse, isActive: true)

                    VStack(spacing: 2) {
                        Text(isVaultOpen ? (projectName ?? workspaceName ?? "Yapa") : "Welcome to Yapa")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        if isVaultOpen, let vaultLocation {
                            pathBadge(text: vaultLocation, fillOpacity: 0.12, strokeOpacity: 0.22, iconOpacity: 0.9)
                        }
                    }

                    Text(isVaultOpen ? "Continue where you left off or create something new" : "Open a Yapa folder to start writing")
                        .font(.title3)
                        .foregroundColor(.secondary)

                        headerActionGrid
                }

                if isVaultOpen {
                    VStack(alignment: .leading, spacing: 8) {
                        LazyVGrid(columns: metricsColumns, spacing: 10) {
                            summaryMetric(label: "Size", value: formatBytes(totalVaultSizeBytes))
                            summaryMetric(label: "Notes", value: "\(noteCount)")
                            summaryMetric(label: "Words", value: formatCount(wordCount))
                            summaryMetric(label: "Chars", value: formatCount(characterCount))
                            summaryMetric(label: "Pinned", value: "\(pinnedCount)")
                            summaryMetric(label: "Recent", value: "\(recentCount)")
                            summaryMetric(label: "Stale", value: "\(staleCount)")
                            summaryMetric(label: "Streak", value: "\(streakDays)d")
                            summaryMetric(label: "Avg Note", value: String(format: "%.0f words", averageNoteLength))
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondary.opacity(0.04))
                        )
                        .overlay(alignment: .topLeading) {
                            Text("Metrics")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(nsColor: .windowBackgroundColor))
                                .offset(x: 10, y: -10)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                        }
                        .padding(.top, 6)
                    }
                }

                if isVaultOpen, let recentNote {
                    Button(action: onOpenRecentNote) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Last file worked on")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(recentNote.displayTitle)
                                .font(.headline.weight(.semibold))

                            Text(String(recentNote.content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(140)))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 10) {
                    if isVaultOpen {
                        EmptyView()
                    } else {
                        Button(action: onOpenVault) {
                            Label("Open Yapa Vault", systemImage: "folder")
                        }
                        .buttonStyle(.borderedProminent)

                        if !recentVaults.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Open Recent")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                ForEach(Array(recentVaults.prefix(3)), id: \.self) { vaultURL in
                                    Button(action: {
                                        onOpenRecentVault(vaultURL)
                                    }) {
                                        HStack {
                                            Image(systemName: "folder")
                                            Text(vaultURL.lastPathComponent)
                                                .lineLimit(1)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            Text("No recent vaults")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                shortcutsGrid
                    .padding(.top, 18)
            }
            .padding(30)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity, minHeight: 420)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var headerActionGrid: some View {
        if isVaultOpen {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                compactActionButton(
                    title: "New Note",
                    systemImage: "doc.badge.plus",
                    prominent: true,
                    action: onCreateNote
                )
                compactActionButton(
                    title: "New Folder",
                    systemImage: "folder.badge.plus",
                    action: onCreateFolder
                )
                compactActionButton(
                    title: "Quick Open",
                    systemImage: "magnifyingglass",
                    action: onQuickOpen
                )
                compactActionButton(
                    title: "Search",
                    systemImage: "text.magnifyingglass",
                    action: onSearch
                )
            }
            .frame(maxWidth: 420)
            .padding(.top, 2)
        }
    }

    private var shortcutsGrid: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Shortcuts")
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                ForEach(shortcuts) { shortcut in
                    VStack(spacing: 3) {
                        Text(shortcut.key)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 2)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text(shortcut.label)
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
                }
            }

            Text("Version \(AppVersionInfo.current.displayString)")
                .font(.caption2)
                .foregroundColor(Color.orange.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 2)
        }
    }

    private var shortcuts: [ShortcutItem] {
        [
            ShortcutItem(label: "New Note", key: "⌘N"),
            ShortcutItem(label: "New Folder", key: "⌘⇧N"),
            ShortcutItem(label: "Open Yapa Folder", key: "⌘O"),
            ShortcutItem(label: "Find in Document", key: "⌘F"),
            ShortcutItem(label: "Fuzzy Search", key: "⌘⇧F"),
            ShortcutItem(label: "Quick Open", key: "⌘K"),
            ShortcutItem(label: "Move Note", key: "⌘M"),
            ShortcutItem(label: "Rename Item", key: "⌘⇧R"),
            ShortcutItem(label: "Help", key: "⌘⇧/")
        ]
    }

    private func compactActionButton(title: String, systemImage: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Group {
            if prominent {
                Button(action: action) {
                    Label(title, systemImage: systemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: action) {
                    Label(title, systemImage: systemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.small)
    }

    private func summaryMetric(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(Color.orange.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatCount(_ count: Int) -> String {
        switch count {
        case 0..<1_000: return "\(count)"
        case 1_000..<1_000_000: return String(format: "%.1fk", Double(count) / 1_000.0)
        default: return String(format: "%.1fM", Double(count) / 1_000_000.0)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

private struct ShortcutItem: Identifiable {
    let id = UUID()
    let label: String
    let key: String
}

struct YapaStructureIssueView: View {
    let message: String
    let onOpenVault: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundColor(.orange)

            Text("Yapa structure issue")
                .font(.title2.weight(.semibold))

            Text(message)
                .foregroundColor(.secondary)

            Button("Choose Another Yapa", action: onOpenVault)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(48)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct NoProjectSelectedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Select a project")
                .font(.headline)
            Text("Choose a project in the sidebar to create notes and folders.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

extension ContentView {
    private func getRecentVaults() -> [URL] {
        let defaults = UserDefaults.standard
        return defaults.stringArray(forKey: "recentVaults")?.compactMap { URL(fileURLWithPath: $0) } ?? []
    }

    private func openRecentVault(at url: URL) {
        fileSystemService.openVaultFolder(at: url)
        selectedFolder = nil
        selectedNote = nil
        lastAutoOpenedVaultURL = nil
    }
}
