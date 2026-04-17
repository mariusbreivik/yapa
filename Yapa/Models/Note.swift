import Foundation

public struct Note: Identifiable, Hashable {
    public let id: UUID
    public var title: String
    public var content: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var fileURL: URL
    public var isPinned: Bool
    public var pinnedAt: Date?
    public var lastAccessedAt: Date
    public var tags: [String]
    
    var displayTitle: String {
        title.isEmpty ? "Untitled" : title
    }
    
    var wordCount: Int {
        let words = content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return words.count
    }
    
    var characterCount: Int {
        content.count
    }
    
    var lineCount: Int {
        content.components(separatedBy: .newlines).count
    }

    var sentenceCount: Int {
        content
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count
    }

    var uniqueWordCount: Int {
        let words = normalizedWords
        return Set(words).count
    }

    var readingTimeMinutes: Int {
        max(1, Int(ceil(Double(wordCount) / 200.0)))
    }

    var headingCount: Int {
        content.components(separatedBy: .newlines).filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }.count
    }

    var linkCount: Int {
        let pattern = #"\[[^\]]+\]\([^\)]+\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        return regex.numberOfMatches(in: content, range: NSRange(content.startIndex..., in: content))
    }

    var codeBlockCount: Int {
        content.components(separatedBy: "```" ).count / 2
    }

    var checklistCount: Int {
        content.components(separatedBy: .newlines).filter {
            let trimmed = $0.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]")
        }.count
    }

    var averageWordsPerSentence: Double {
        guard sentenceCount > 0 else { return Double(wordCount) }
        return Double(wordCount) / Double(sentenceCount)
    }

    private var normalizedWords: [String] {
        content
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.filter { $0.isLetter || $0.isNumber } }
            .filter { !$0.isEmpty }
    }
    
    public init(id: UUID = UUID(), title: String = "", content: String = "", createdAt: Date = Date(), modifiedAt: Date = Date(), fileURL: URL, isPinned: Bool = false, pinnedAt: Date? = nil, lastAccessedAt: Date = Date(), tags: [String] = []) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.fileURL = fileURL
        self.isPinned = isPinned
        self.pinnedAt = pinnedAt
        self.lastAccessedAt = lastAccessedAt
        self.tags = tags
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
    }
}

public struct FolderItem: Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var url: URL
    public var isExpanded: Bool
    public var children: [FolderItem]
    public var notes: [Note]
    
    public init(id: UUID = UUID(), name: String, url: URL, isExpanded: Bool = false, children: [FolderItem] = [], notes: [Note] = []) {
        self.id = id
        self.name = name
        self.url = url
        self.isExpanded = isExpanded
        self.children = children
        self.notes = notes
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: FolderItem, rhs: FolderItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct SearchResult: Identifiable {
    let id: UUID
    let note: Note
    let matchedLines: [String]
    let relevanceScore: Double
    
    init(note: Note, matchedLines: [String], relevanceScore: Double = 1.0) {
        self.id = UUID()
        self.note = note
        self.matchedLines = matchedLines
        self.relevanceScore = relevanceScore
    }
}

public struct NoteTemplate: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let icon: String
    public let content: String
    
    public init(name: String, icon: String, content: String) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.content = content
    }
}
