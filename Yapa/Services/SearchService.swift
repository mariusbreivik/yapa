import Foundation
import SQLite

final class SearchService: ObservableObject {
    static let shared = SearchService()
    
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var recentSearches: [String] = []
    @Published var lastSearchDurationMS: Int = 0
    
    private var db: Connection?
    private let notesTable = VirtualTable("notes_fts")
    private let tagsTable = Table("tags")
    private let noteTagsTable = Table("note_tags")
    
    private let id = Expression<String>("id")
    private let title = Expression<String>("title")
    private let content = Expression<String>("content")
    private let fileURL = Expression<String>("fileURL")
    private let tagID = Expression<Int64>("id")
    private let tagName = Expression<String>("name")
    private let noteTagNoteID = Expression<String>("note_id")
    private let noteTagTagID = Expression<Int64>("tag_id")
    
    private let recentSearchesKey = "recentSearches"
    private let maxRecentSearches = 5
    
    private init() {
        setupDatabase()
        loadRecentSearches()
    }
    
    private func setupDatabase() {
        do {
            let path = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Yapa", isDirectory: true)
            
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
            
            let dbPath = path.appendingPathComponent("search_index.sqlite").path
            db = try Connection(dbPath)
            
            try db?.run(notesTable.drop(ifExists: true))
            
            try db?.run(notesTable.create(.FTS5(
                FTS5Config()
                    .column(id, [.unindexed])
                    .column(title)
                    .column(content)
                    .column(fileURL, [.unindexed])
            )))
            try db?.run(tagsTable.create(ifNotExists: true) { t in
                t.column(tagID, primaryKey: .autoincrement)
                t.column(tagName, unique: true)
            })
            try db?.run(noteTagsTable.create(ifNotExists: true) { t in
                t.column(noteTagNoteID)
                t.column(noteTagTagID)
                t.unique(noteTagNoteID, noteTagTagID)
            })
        } catch {
            print("Database setup error: \(error)")
        }
    }
    
    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }
    
    private func saveRecentSearch(_ query: String) {
        var searches = recentSearches.filter { $0 != query }
        searches.insert(query, at: 0)
        if searches.count > maxRecentSearches {
            searches = Array(searches.prefix(maxRecentSearches))
        }
        recentSearches = searches
        UserDefaults.standard.set(searches, forKey: recentSearchesKey)
    }
    
    func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: recentSearchesKey)
    }
    
    func indexNotes(_ notes: [Note]) {
        guard let db = db else { return }
        
        do {
            try db.run(notesTable.delete())
            
            for note in notes {
                try db.run(notesTable.insert(
                    id <- note.id.uuidString,
                    title <- note.title,
                    content <- note.content,
                    fileURL <- note.fileURL.path
                ))
                try upsertTags(for: note)
            }
        } catch {
            print("Indexing error: \(error)")
        }
    }

    private func upsertTags(for note: Note) throws {
        guard let db = db else { return }
        try db.run(noteTagsTable.filter(noteTagNoteID == note.id.uuidString).delete())
        for tag in note.tags {
            let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            let existing = tagsTable.filter(tagName == normalized)
            let tagRowID: Int64
            if let row = try db.pluck(existing) {
                tagRowID = row[tagID]
            } else {
                tagRowID = try db.run(tagsTable.insert(or: .ignore, tagName <- normalized))
            }
            try db.run(noteTagsTable.insert(or: .ignore, noteTagNoteID <- note.id.uuidString, noteTagTagID <- tagRowID))
        }
    }
    
    func search(query: String) {
        guard let db = db, !query.isEmpty else {
            searchResults = []
            lastSearchDurationMS = 0
            return
        }
        
        isSearching = true
        let start = DispatchTime.now()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var results: [SearchResult] = []
            
            do {
                let parsed = parseSearchQuery(query)
                if parsed.textQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    results = self.fuzzySearchFallback(query: query)
                    DispatchQueue.main.async {
                        self.searchResults = results
                        self.isSearching = false
                        let elapsed = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
                        self.lastSearchDurationMS = Int(elapsed / 1_000_000)
                        if !query.isEmpty && !results.isEmpty {
                            self.saveRecentSearch(query)
                        }
                    }
                    return
                }
                let fuzzyQuery = buildFuzzyQuery(parsed.textQuery)
                
                let statement = try db.prepare("""
                    SELECT id, title, content, fileURL,
                           bm25(notes_fts) as rank
                    FROM notes_fts
                    WHERE notes_fts MATCH ?
                    ORDER BY rank
                    LIMIT 50
                """, fuzzyQuery)
                
                for row in statement {
                    if let idString = row[0] as? String,
                       let uuid = UUID(uuidString: idString),
                       let titleValue = row[1] as? String,
                       let contentValue = row[2] as? String,
                       let fileURLString = row[3] as? String,
                       let rank = row[4] as? Double {
                        
                        let url = URL(fileURLWithPath: fileURLString)
                        
                        let note = Note(
                            id: uuid,
                            title: titleValue,
                            content: contentValue,
                            fileURL: url
                        )

                        let noteTagSet = Set(note.tags.map { $0.lowercased() })
                        guard parsed.tagFilters.isEmpty || !parsed.tagFilters.isDisjoint(with: noteTagSet) else {
                            continue
                        }
                        
                        let snippet = self.extractAllMatchingLines(from: contentValue, matching: parsed.textQuery.isEmpty ? query : parsed.textQuery)
                        let highlightedLines = snippet.map { self.highlightMatches(in: $0, query: parsed.textQuery.isEmpty ? query : parsed.textQuery) }
                        
                        let result = SearchResult(
                            note: note,
                            matchedLines: highlightedLines,
                            relevanceScore: abs(rank)
                        )
                        results.append(result)
                    }
                }
                
                if results.isEmpty {
                    results = self.fuzzySearchFallback(query: query)
                }
            } catch {
                print("Search error: \(error)")
                results = self.fuzzySearchFallback(query: query)
            }
            
            DispatchQueue.main.async {
                self.searchResults = results
                self.isSearching = false
                let elapsed = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
                self.lastSearchDurationMS = Int(elapsed / 1_000_000)
                if !query.isEmpty && !results.isEmpty {
                    self.saveRecentSearch(query)
                }
            }
        }
    }

    private func parseSearchQuery(_ query: String) -> (textQuery: String, tagFilters: Set<String>) {
        let parts = query.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        var textParts: [String] = []
        var tags = Set<String>()

        for part in parts {
            let term = String(part)
            if term.lowercased().hasPrefix("tag:") {
                let tag = term.dropFirst(4).trimmingCharacters(in: .whitespacesAndNewlines)
                if !tag.isEmpty { tags.insert(tag.lowercased()) }
            } else {
                textParts.append(term)
            }
        }

        return (textParts.joined(separator: " "), tags)
    }
    
    func buildFuzzyQuery(_ query: String) -> String {
        buildFuzzySearchQuery(query)
    }
    
    private func fuzzySearchFallback(query: String) -> [SearchResult] {
        let allNotes = FileSystemService.shared.allNotes
        let parsed = parseSearchQuery(query)
        let terms = searchTerms(from: parsed.textQuery)

        guard !terms.isEmpty else { return [] }
        
        return allNotes
            .compactMap { note -> SearchResult? in
                let noteTagSet = Set(note.tags.map { $0.lowercased() })
                guard parsed.tagFilters.isEmpty || !parsed.tagFilters.isDisjoint(with: noteTagSet) else { return nil }

                let matches = terms.compactMap { term -> Double? in
                    let titleMatch = fuzzyMatch(term: term, in: note.title.lowercased())
                    let contentMatch = fuzzyMatch(term: term, in: note.content.lowercased())
                    let bestMatch = max(titleMatch, contentMatch)
                    return bestMatch > 0 ? bestMatch : nil
                }

                guard matches.count == terms.count else { return nil }

                let score = matches.reduce(0, +) / Double(matches.count)
                let snippet = extractAllMatchingLines(from: note.content, matching: parsed.textQuery)
                let highlightedLines = snippet.map { highlightMatches(in: $0, query: parsed.textQuery) }
                
                return SearchResult(
                    note: note,
                    matchedLines: highlightedLines,
                    relevanceScore: score
                )
            }
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .prefix(50)
            .map { $0 }
    }
    
    private func searchTerms(from query: String) -> [String] {
        query
            .lowercased()
            .split { $0.isWhitespace || $0.isNewline || $0.isPunctuation }
            .map { term -> String in
                term.filter { $0.isLetter || $0.isNumber }
            }
            .filter { !$0.isEmpty }
    }
    
    private func fuzzyMatch(term: String, in text: String) -> Double {
        if text.contains(term) {
            return 1.0
        }
        
        let queryChars = Array(term)
        let textChars = Array(text)
        
        var matches = 0
        var textIndex = 0
        
        for queryChar in queryChars {
            while textIndex < textChars.count {
                if textChars[textIndex] == queryChar {
                    matches += 1
                    textIndex += 1
                    break
                }
                textIndex += 1
            }
        }
        
        if matches > 0 {
            return Double(matches) / Double(queryChars.count) * 0.8
        }
        
        return 0
    }
    
    private func extractAllMatchingLines(from content: String, matching query: String, limit: Int = 8) -> [String] {
        let terms = query.lowercased().split(separator: " ").map { String($0) }
        guard !terms.isEmpty else { return [] }
        
        let lines = content.components(separatedBy: .newlines)
        var matchingLines: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            let lowercaseLine = trimmed.lowercased()
            let allTermsMatch = terms.allSatisfy { lowercaseLine.contains($0) }
            
            if allTermsMatch {
                matchingLines.append(trimmed)
            }
        }
        
        if matchingLines.count > limit {
            return Array(matchingLines.prefix(limit))
        }
        
        return matchingLines
    }
    
    private func highlightMatches(in line: String, query: String) -> String {
        let words = query.split(separator: " ").map { String($0) }
        var result = line
        
        for word in words {
            let pattern = "(?i)(\(NSRegularExpression.escapedPattern(for: word)))"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: range,
                    withTemplate: "**$1**"
                )
            }
        }
        
        return result
    }
    
    private func extractSnippet(from content: String, matching query: String) -> String {
        let words = query.lowercased().split(separator: " ").map { String($0) }
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let lowercaseLine = line.lowercased()
            for word in words {
                if lowercaseLine.contains(word) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.count > 150 {
                        return String(trimmed.prefix(150)) + "..."
                    }
                    return trimmed
                }
            }
        }
        
        let firstLine = lines.first?.trimmingCharacters(in: .whitespaces) ?? ""
        if firstLine.count > 150 {
            return String(firstLine.prefix(150)) + "..."
        }
        return firstLine
    }
    
    func clearSearch() {
        searchResults = []
    }
    
    func suggestCompletion(for partial: String) -> [String] {
        guard !partial.isEmpty else { return [] }
        
        let notes = FileSystemService.shared.allNotes
        let partialLower = partial.lowercased()
        
        return notes
            .map { $0.displayTitle }
            .filter { $0.lowercased().hasPrefix(partialLower) }
            .prefix(5)
            .map { $0 }
    }
}
