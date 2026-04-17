import Foundation
import AppKit
import UniformTypeIdentifiers

struct NoteMetadata {
    var title: String?
    var created: Date?
    var modified: Date?
    var isPinned: Bool = false
    var pinnedAt: Date?
    var lastAccessed: Date?
    var tags: [String] = []
}

public final class FileSystemService: ObservableObject {
    public static let shared = FileSystemService()
    
    @Published public var rootFolder: URL?
    @Published public var folderStructure: [FolderItem] = []
    @Published public var allNotes: [Note] = []
    @Published public var pinnedNotes: [Note] = []
    @Published public var recentNotes: [Note] = []
    @Published public var rootStructureError: String?
    @Published public var lastCreatedProjectURL: URL?
    @Published public var templates: [NoteTemplate] = []
    
    private let fileManager: FileManager
    private let markdownExtension = "md"
    private let yapaBookmarkKey = "yapaFolderBookmark"
    private let seededYapaMarkerName = ".yapa-seeded"
    private var securityScopedFolderURL: URL?
    
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        loadTemplates()
        restorePersistedVaultFolder()
    }
    
    func selectRootFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Yapa Folder"
        panel.message = "Choose a folder to store your notes"
        
        if panel.runModal() == .OK, let url = panel.url {
            openVaultFolder(at: url)
        }
    }

    func openVaultFolder(at url: URL) {
        activateSecurityScopedAccess(for: url)
        rootFolder = url
        saveVaultBookmark(for: url)
        seedDefaultVaultContentIfNeeded(at: url)
        loadFolderStructure()
        loadAllNotes()
    }

    private func restorePersistedVaultFolder() {
        guard let url = resolveVaultBookmark() else { return }
        activateSecurityScopedAccess(for: url)
        rootFolder = url
        seedDefaultVaultContentIfNeeded(at: url)
        loadFolderStructure()
        loadAllNotes()
    }

    private func saveVaultBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: yapaBookmarkKey)
        } catch {
            print("Error saving Yapa bookmark: \(error)")
        }
    }

    private func resolveVaultBookmark() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: yapaBookmarkKey) else { return nil }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                saveVaultBookmark(for: url)
            }

            return url
        } catch {
            print("Error resolving Yapa bookmark: \(error)")
            return nil
        }
    }

    private func activateSecurityScopedAccess(for url: URL) {
        if securityScopedFolderURL != url {
            securityScopedFolderURL?.stopAccessingSecurityScopedResource()
        }

        if url.startAccessingSecurityScopedResource() {
            securityScopedFolderURL = url
        }
    }

    private func loadTemplates() {
        let templateFiles = templateFileURLs()
        let mdFiles = templateFiles.filter { $0.pathExtension == "md" }

        var loadedTemplates: [NoteTemplate] = []

        for fileURL in mdFiles {
            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                let name = fileURL.deletingPathExtension().lastPathComponent
                let icon = extractTemplateIcon(from: content) ?? "doc.text"
                let cleanContent = extractTemplateContent(from: content)

                let template = NoteTemplate(name: name, icon: icon, content: cleanContent)
                loadedTemplates.append(template)
            }
        }

        templates = loadedTemplates
    }

    private func templateFileURLs() -> [URL] {
        if let scoped = Bundle.main.urls(forResourcesWithExtension: "md", subdirectory: "Templates"), !scoped.isEmpty {
            return scoped
        }

        if let rootFiles = Bundle.main.urls(forResourcesWithExtension: "md", subdirectory: nil), !rootFiles.isEmpty {
            return rootFiles.filter { ["Meeting Note", "Daily Standup", "Quick Note", "Weekly Review"].contains($0.deletingPathExtension().lastPathComponent) }
        }

        return []
    }

    private func extractTemplateIcon(from content: String) -> String? {
        guard content.hasPrefix("---") else { return nil }

        let lines = content.components(separatedBy: .newlines)
        guard let closingIndex = lines.dropFirst().firstIndex(of: "---"), closingIndex > 1 else {
            return nil
        }

        for line in lines[1..<closingIndex] {
            if line.hasPrefix("icon:") {
                let iconPart = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                return iconPart.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }

        return nil
    }

    private func extractTemplateContent(from content: String) -> String {
        var inFrontmatter = false
        var frontmatterClosed = false
        var contentLines: [String] = []

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            if line == "---" && !inFrontmatter {
                inFrontmatter = true
                continue
            } else if line == "---" && inFrontmatter {
                frontmatterClosed = true
                inFrontmatter = false
                continue
            }

            if frontmatterClosed {
                contentLines.append(line)
            }
        }

        let cleaned = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? content : cleaned
    }

    private func seedDefaultVaultContentIfNeeded(at url: URL) {
        let markerURL = url.appendingPathComponent(seededYapaMarkerName)

        guard !fileManager.fileExists(atPath: markerURL.path) else { return }

        let visibleContents = (try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        guard visibleContents.isEmpty else { return }

        let projectURL = url.appendingPathComponent("My first project", isDirectory: true)
        let noteURL = projectURL.appendingPathComponent("Getting Started.md")
        let now = ISO8601DateFormatter().string(from: Date())
        let content = defaultGettingStartedContent(createdAt: now)

        do {
            try fileManager.createDirectory(at: projectURL, withIntermediateDirectories: false)
            try content.write(to: noteURL, atomically: true, encoding: .utf8)
            try Data().write(to: markerURL)
        } catch {
            print("Error seeding default Yapa content: \(error)")
        }
    }

    private func defaultGettingStartedContent(createdAt: String) -> String {
        """
        ---
        title: "Getting Started"
        created: \(createdAt)
        modified: \(createdAt)
        ---

        # Welcome to Yapa

        Yapa is a macOS note-taking app built around plain Markdown files stored inside a folder that you control.

        ## How it works

        - A Yapa folder is the root folder you open in the app.
        - Each top-level folder is treated as a project.
        - Notes are plain `.md` files stored inside those project folders.
        - Search uses a fast full-text index with a fuzzy fallback.

        ## Features

        - Project-based organization in the sidebar
        - Plain Markdown notes with YAML frontmatter metadata
        - Pinning and recent-note tracking
        - Full-text search and quick open
        - Drag and drop for moving folders and notes
        - Markdown preview and note statistics

        ## Shortcuts

        - `⌘N` New Note
        - `⌘⇧N` New Folder
        - `⌘O` Open Yapa Folder
        - `⌘F` Find in Document
        - `⌘⇧F` Fuzzy Search
        - `⌘K` Quick Open
        - `⌘M` Move Note
        - `⌘⇧R` Rename Item
        - `⌘⇧/` Help

        ## Tips

        - Use the sidebar toolbar to create notes, create folders, or switch Yapa roots.
        - Start typing in the editor and Yapa will autosave your note.
        - Use Quick Open when you know the note name, and Search when you want matching content.
        """
    }
    
    public func loadFolderStructure() {
        guard let root = rootFolder else {
            folderStructure = []
            rootStructureError = nil
            return
        }
        
        let contents = (try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        rootStructureError = contents.contains(where: { !$0.hasDirectoryPath }) ? "Yapa root can only contain project folders." : nil

        folderStructure = buildFolderStructure(from: root)
    }
    
    private func buildFolderStructure(from url: URL) -> [FolderItem] {
        var items: [FolderItem] = []
        
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return items
        }
        
        for itemURL in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory)
            
            if isDirectory.boolValue {
                let subItems = buildFolderStructure(from: itemURL)
                let notesInFolder = loadNotesFromFolder(itemURL)
                let folderItem = FolderItem(
                    name: itemURL.lastPathComponent,
                    url: itemURL,
                    isExpanded: false,
                    children: subItems,
                    notes: notesInFolder
                )
                items.append(folderItem)
            }
        }
        
        return items
    }
    
    private func loadNotesFromFolder(_ folderURL: URL) -> [Note] {
        var notes: [Note] = []
        
        guard let contents = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return notes
        }
        
        for fileURL in contents {
            if fileURL.pathExtension == markdownExtension {
                if let note = loadNote(from: fileURL) {
                    notes.append(note)
                }
            }
        }
        
        return notes.sorted { $0.modifiedAt > $1.modifiedAt }
    }
    
    public func loadAllNotes() {
        guard let root = rootFolder else {
            allNotes = []
            pinnedNotes = []
            recentNotes = []
            return
        }

        allNotes = projectRootURLs(in: root).flatMap { collectAllNotes(from: $0) }
        refreshDerivedNoteLists()
    }

    private func projectRootURLs(in root: URL) -> [URL] {
        let contents = (try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        return contents
            .filter { $0.hasDirectoryPath }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func refreshDerivedNoteLists() {
        let currentPinnedURLs = pinnedNotes.map { $0.fileURL.standardizedFileURL }
        let currentRecentURLs = recentNotes.map { $0.fileURL.standardizedFileURL }

        let pinnedNow = allNotes.filter { $0.isPinned }
        var stablePinned: [Note] = []
        var seenPinned = Set<URL>()

        for url in currentPinnedURLs {
            if let note = pinnedNow.first(where: { $0.fileURL.standardizedFileURL == url }) {
                stablePinned.append(note)
                seenPinned.insert(note.fileURL.standardizedFileURL)
            }
        }

        for note in pinnedNow {
            let standardizedURL = note.fileURL.standardizedFileURL
            guard !seenPinned.contains(standardizedURL) else { continue }
            stablePinned.append(note)
            seenPinned.insert(standardizedURL)
        }

        pinnedNotes = Array(stablePinned.prefix(5))

        let recentCandidates = currentRecentURLs.compactMap { url in
            allNotes.first { $0.fileURL.standardizedFileURL == url }
        }

        if recentCandidates.isEmpty {
            recentNotes = Array(allNotes.sorted { $0.lastAccessedAt > $1.lastAccessedAt }.prefix(4))
        } else {
            recentNotes = Array(recentCandidates.prefix(4))
        }
    }

    var projectCount: Int {
        folderStructure.count
    }

    var totalWordCount: Int {
        allNotes.reduce(0) { $0 + $1.wordCount }
    }

    var totalCharacterCount: Int {
        allNotes.reduce(0) { $0 + $1.characterCount }
    }

    var totalVaultSizeBytes: Int64 {
        allNotes.reduce(into: Int64(0)) { total, note in
            let fileSize = ((try? fileManager.attributesOfItem(atPath: note.fileURL.path)[.size] as? NSNumber)?.int64Value) ?? Int64(note.characterCount)
            total += fileSize
        }
    }

    var averageNoteLength: Double {
        guard !allNotes.isEmpty else { return 0 }
        return Double(totalWordCount) / Double(allNotes.count)
    }

    var staleNoteCount: Int {
        let threshold = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
        return allNotes.filter { $0.lastAccessedAt < threshold }.count
    }

    var activityStreakDays: Int {
        let days = Set(allNotes.map { Calendar.current.startOfDay(for: $0.lastAccessedAt) })
        guard !days.isEmpty else { return 0 }

        var streak = 0
        var currentDay = Calendar.current.startOfDay(for: Date())

        while days.contains(currentDay) {
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: currentDay) else { break }
            currentDay = previous
        }

        return streak
    }

    func projectStaleNoteCount(for folder: FolderItem) -> Int {
        let threshold = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
        return collectNotes(in: folder).filter { $0.lastAccessedAt < threshold }.count
    }

    func projectHeatScore(for folder: FolderItem) -> Int {
        let notes = collectNotes(in: folder)
        guard !notes.isEmpty else { return 0 }

        let recentCount = notes.filter {
            ($0.lastAccessedAt >= Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast)
        }.count
        let staleCount = projectStaleNoteCount(for: folder)
        let score = (Double(recentCount) / Double(notes.count) * 100.0) - Double(staleCount * 5)
        return max(0, min(100, Int(score.rounded())))
    }

    func projectStats(for folder: FolderItem) -> (notes: Int, folders: Int, words: Int, chars: Int) {
        let nestedFolders = countFolders(in: folder) - 1
        let notes = countNotes(in: folder)
        let words = countWords(in: folder)
        let chars = countCharacters(in: folder)
        return (notes, nestedFolders, words, chars)
    }

    private func countFolders(in folder: FolderItem) -> Int {
        1 + folder.children.reduce(0) { $0 + countFolders(in: $1) }
    }

    private func countNotes(in folder: FolderItem) -> Int {
        folder.notes.count + folder.children.reduce(0) { $0 + countNotes(in: $1) }
    }

    private func countWords(in folder: FolderItem) -> Int {
        folder.notes.reduce(0) { $0 + $1.wordCount } + folder.children.reduce(0) { $0 + countWords(in: $1) }
    }

    private func countCharacters(in folder: FolderItem) -> Int {
        folder.notes.reduce(0) { $0 + $1.characterCount } + folder.children.reduce(0) { $0 + countCharacters(in: $1) }
    }

    private func collectNotes(in folder: FolderItem) -> [Note] {
        folder.notes + folder.children.flatMap { collectNotes(in: $0) }
    }
    
    private func collectAllNotes(from url: URL) -> [Note] {
        var notes: [Note] = []
        
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return notes
        }
        
        for itemURL in contents {
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory)
            
            if isDirectory.boolValue {
                notes.append(contentsOf: collectAllNotes(from: itemURL))
            } else if itemURL.pathExtension == markdownExtension {
                if let note = loadNote(from: itemURL) {
                    notes.append(note)
                }
            }
        }
        
        return notes
    }
    
    public func loadNote(from url: URL) -> Note? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        
        let metadata = parseFrontmatter(content)
        let title = metadata.title ?? extractTitleFromContent(content)
        let createdAt = metadata.created ?? extractDateFromFilename(url)
        let modifiedAt = (try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? Date()
        
        let cleanContent = removeFrontmatter(from: content)
        
        return Note(
            title: title,
            content: cleanContent,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            fileURL: url,
            isPinned: metadata.isPinned,
            pinnedAt: metadata.pinnedAt,
            lastAccessedAt: metadata.lastAccessed ?? modifiedAt,
            tags: metadata.tags
        )
    }
    
    private func parseFrontmatter(_ content: String) -> NoteMetadata {
        var metadata = NoteMetadata()
        
        guard content.hasPrefix("---") else { return metadata }
        
        let lines = content.components(separatedBy: .newlines)
        var inFrontmatter = false
        var frontmatterLines: [String] = []
        
        for line in lines {
            if line == "---" {
                if !inFrontmatter {
                    inFrontmatter = true
                    continue
                } else {
                    break
                }
            }
            
            if inFrontmatter {
                frontmatterLines.append(line)
            }
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        for line in frontmatterLines {
            if line.contains(":") {
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    
                    if key == "title" {
                        metadata.title = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    } else if key == "created" {
                        metadata.created = dateFormatter.date(from: value)
                    } else if key == "modified" {
                        metadata.modified = dateFormatter.date(from: value)
                    } else if key == "pinned" {
                        metadata.isPinned = value == "true"
                    } else if key == "pinnedAt" {
                        metadata.pinnedAt = dateFormatter.date(from: value)
                    } else if key == "lastAccessed" {
                        metadata.lastAccessed = dateFormatter.date(from: value)
                    } else if key == "tags" {
                        metadata.tags = parseTags(from: value)
                    }
                }
            }
        }
        
        return metadata
    }

    private func parseTags(from value: String) -> [String] {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            let inner = trimmed.dropFirst().dropLast()
            return inner
                .split(separator: ",")
                .map { token in
                    token.trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                        .trimmingCharacters(in: CharacterSet(charactersIn: "'"))
                }
                .filter { !$0.isEmpty }
        }

        return trimmed
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func extractTitleFromContent(_ content: String) -> String {
        let cleanContent = removeFrontmatter(from: content)
        let lines = cleanContent.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                let title = trimmed.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                return title
            }
        }
        
        return "Untitled"
    }
    
    private func removeFrontmatter(from content: String) -> String {
        var remaining = content.trimmingCharacters(in: .whitespacesAndNewlines)

        while remaining.hasPrefix("---") {
            let lines = remaining.components(separatedBy: .newlines)
            guard lines.first == "---" else { break }

            guard let closingDelimiterIndex = lines.dropFirst().firstIndex(of: "---") else {
                break
            }

            let contentStartIndex = lines.index(after: closingDelimiterIndex)
            let nextContent = lines[contentStartIndex...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

            if nextContent == remaining {
                break
            }

            remaining = nextContent
        }

        return remaining
    }
    
    private func extractDateFromFilename(_ url: URL) -> Date {
        let filename = url.deletingPathExtension().lastPathComponent
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = dateFormatter.date(from: String(filename.prefix(10))) {
            return date
        }
        
        return (try? fileManager.attributesOfItem(atPath: url.path)[.creationDate] as? Date) ?? Date()
    }
    
    func saveNote(_ note: Note) {
        let tagsLine = formattedTagsLine(for: note.tags)
        let frontmatter = """
        ---
        title: "\(note.title)"
        created: \(ISO8601DateFormatter().string(from: note.createdAt))
        modified: \(ISO8601DateFormatter().string(from: Date()))
        pinned: \(note.isPinned)
        \(tagsLine)
        \(note.pinnedAt.map { "pinnedAt: \(ISO8601DateFormatter().string(from: $0))\n" } ?? "")
        lastAccessed: \(ISO8601DateFormatter().string(from: note.lastAccessedAt))
        ---
        
        """
        
        let body = removeFrontmatter(from: note.content)
        let content = frontmatter + body
        
        do {
            try content.write(to: note.fileURL, atomically: true, encoding: .utf8)
            loadAllNotes()
            loadFolderStructure()
        } catch {
            print("Error saving note: \(error)")
        }
    }

    private func formattedTagsLine(for tags: [String]) -> String {
        guard !tags.isEmpty else { return "" }
        let quoted = tags.map { "\"\($0)\"" }.joined(separator: ", ")
        return "tags: [\(quoted)]\n"
    }
    
    func createNote(in folder: URL, title: String = "Untitled") -> Note? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        var filename = "\(dateString)-\(title).md"
        filename = filename.replacingOccurrences(of: " ", with: "-")
        filename = filename.replacingOccurrences(of: "/", with: "-")
        
        var fileURL = folder.appendingPathComponent(filename)
        
        var counter = 1
        while fileManager.fileExists(atPath: fileURL.path) {
            filename = "\(dateString)-\(title)-\(counter).md"
            filename = filename.replacingOccurrences(of: " ", with: "-")
            filename = filename.replacingOccurrences(of: "/", with: "-")
            fileURL = folder.appendingPathComponent(filename)
            counter += 1
        }
        
        let content = """
        ---
        title: "\(title)"
        created: \(ISO8601DateFormatter().string(from: Date()))
        modified: \(ISO8601DateFormatter().string(from: Date()))
        tags: []
        ---
        
        # \(title)
        
        """
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            
            if let note = loadNote(from: fileURL) {
                loadAllNotes()
                loadFolderStructure()
                return note
            }
        } catch {
            print("Error creating note: \(error)")
        }
        
        return nil
    }

    func availableTags() -> [String] {
        Array(Set(allNotes.flatMap { $0.tags }))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func notes(filteredByTags tags: Set<String>, in notes: [Note]) -> [Note] {
        guard !tags.isEmpty else { return notes }
        return notes.filter { !tags.isDisjoint(with: Set($0.tags)) }
    }
    
    func createFolder(in parent: URL, name: String) -> URL? {
        let folderURL = uniqueFolderURL(in: parent, baseName: name)
        
        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: false)
            loadFolderStructure()
            return folderURL
        } catch {
            print("Error creating folder: \(error)")
            return nil
        }
    }

    func createTopLevelProject(named name: String = "New project") -> URL? {
        guard let rootFolder else { return nil }

        let projectURL = createFolder(in: rootFolder, name: name)
        lastCreatedProjectURL = projectURL?.standardizedFileURL
        return projectURL
    }

    private func uniqueFolderURL(in parent: URL, baseName: String) -> URL {
        let trimmedName = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = trimmedName.isEmpty ? "New Folder" : trimmedName

        var candidate = parent.appendingPathComponent(fallbackName)
        var suffix = 1

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = parent.appendingPathComponent("\(fallbackName) (\(suffix))")
            suffix += 1
        }

        return candidate
    }
    
    func deleteNote(_ note: Note) {
        do {
            try fileManager.removeItem(at: note.fileURL)
            loadAllNotes()
            loadFolderStructure()
        } catch {
            print("Error deleting note: \(error)")
        }
    }
    
    func deleteFolder(_ folder: URL) {
        do {
            try fileManager.removeItem(at: folder)
            loadAllNotes()
            loadFolderStructure()
        } catch {
            print("Error deleting folder: \(error)")
        }
    }
    
    func renameNote(_ note: Note, to newTitle: String) -> Note? {
        let newFilename = "\(note.fileURL.deletingPathExtension().lastPathComponent.components(separatedBy: "-").prefix(3).joined(separator: "-"))-\(newTitle).md"
        let newURL = note.fileURL.deletingLastPathComponent().appendingPathComponent(newFilename)
        
        do {
            try fileManager.moveItem(at: note.fileURL, to: newURL)
            
            var updatedNote = note
            updatedNote.title = newTitle
            updatedNote.fileURL = newURL
            updatedNote.modifiedAt = Date()
            saveNote(updatedNote)

            return updatedNote
        } catch {
            print("Error renaming note: \(error)")
            return nil
        }
    }
    
    public func moveNote(_ note: Note, to destinationFolder: URL) -> Note? {
        let sourceURL = note.fileURL.standardizedFileURL
        let targetFolder = destinationFolder.standardizedFileURL
        guard targetFolder != rootFolder?.standardizedFileURL else { return nil }
        let targetURL = uniqueMoveDestinationURL(for: sourceURL, in: targetFolder)
        
        guard sourceURL != targetURL else {
            return note
        }
        
        do {
            try fileManager.moveItem(at: sourceURL, to: targetURL)
            
            var updatedNote = note
            updatedNote.fileURL = targetURL
            updatedNote.modifiedAt = Date()
            
            loadAllNotes()
            loadFolderStructure()
            
            return updatedNote
        } catch {
            print("Error moving note: \(error)")
            return nil
        }
    }

    func moveFolder(_ folder: URL, to destinationFolder: URL) -> URL? {
        let sourceURL = folder.standardizedFileURL
        let targetFolder = destinationFolder.standardizedFileURL

        guard sourceURL != targetFolder else { return nil }
        guard sourceURL.deletingLastPathComponent().standardizedFileURL != targetFolder else {
            return sourceURL
        }

        let sourcePath = sourceURL.path
        let targetPath = targetFolder.path
        guard !targetPath.hasPrefix(sourcePath + "/") else { return nil }

        let targetURL = uniqueMoveDestinationURL(for: sourceURL, in: targetFolder)

        do {
            try fileManager.moveItem(at: sourceURL, to: targetURL)
            loadAllNotes()
            loadFolderStructure()
            return targetURL
        } catch {
            print("Error moving folder: \(error)")
            return nil
        }
    }
    
    func renameFolder(_ folder: URL, to newName: String) -> URL? {
        let newURL = folder.deletingLastPathComponent().appendingPathComponent(newName)
        
        do {
            try fileManager.moveItem(at: folder, to: newURL)
            loadFolderStructure()
            return newURL
        } catch {
            print("Error renaming folder: \(error)")
            return nil
        }
    }
    
    func togglePin(for note: Note) {
        var updatedNote = note
        updatedNote.isPinned.toggle()
        updatedNote.pinnedAt = updatedNote.isPinned ? Date() : nil
        saveNote(updatedNote)
    }
    
    func updateAccessTime(for note: Note) {
        var updatedNote = note
        updatedNote.lastAccessedAt = Date()
        saveNote(updatedNote)

        let targetURL = updatedNote.fileURL.standardizedFileURL
        recentNotes.removeAll { $0.fileURL.standardizedFileURL == targetURL }
        recentNotes.insert(updatedNote, at: 0)
        recentNotes = Array(recentNotes.prefix(4))
    }
    
    func noteByTitle(_ title: String) -> Note? {
        allNotes.first { $0.displayTitle.localizedCaseInsensitiveContains(title) }
    }

    private func uniqueMoveDestinationURL(for sourceURL: URL, in destinationFolder: URL) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension
        var candidate = destinationFolder.appendingPathComponent(sourceURL.lastPathComponent)
        var suffix = 1

        while fileManager.fileExists(atPath: candidate.path) {
            let filename = ext.isEmpty ? "\(baseName) \(suffix)" : "\(baseName) \(suffix).\(ext)"
            candidate = destinationFolder.appendingPathComponent(filename)
            suffix += 1
        }

        return candidate
    }
}
