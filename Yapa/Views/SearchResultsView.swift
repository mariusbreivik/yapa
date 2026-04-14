import SwiftUI

struct SearchResultsView: View {
    @EnvironmentObject var searchService: SearchService
    @EnvironmentObject var fileSystemService: FileSystemService
    
    @Binding var searchText: String
    @Binding var selectedNote: Note?
    @Binding var isPresented: Bool

    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            if searchService.isSearching {
                loadingView
            } else if searchService.searchResults.isEmpty {
                emptyResults
            } else {
                resultsList
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            performSearch()
            isSearchFocused = true
        }
        .onExitCommand {
            searchText = ""
            searchService.clearSearch()
            isPresented = false
        }
        .onChange(of: searchText) { _, _ in
            performSearch()
        }
    }
    
    private var header: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            Text("Fuzzy Search")
                .font(.headline)

            TextField("Search all files...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .frame(maxWidth: 280)

            if searchService.lastSearchDurationMS > 0 {
                Text("\(searchService.lastSearchDurationMS) ms")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            if !searchService.recentSearches.isEmpty && searchText.isEmpty {
                Menu {
                    Button("Clear Recent", role: .destructive) {
                        searchService.clearRecentSearches()
                    }
                } label: {
                    Text("Recent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("\(searchService.searchResults.count) found")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            
            Button(action: {
                searchText = ""
                searchService.clearSearch()
                isPresented = false
            }) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.0)
                .padding(.top, 40)
            
            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyResults: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .padding(.top, 40)
            
            Text("No results found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Try different keywords or check your spelling")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !searchService.recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Searches")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(searchService.recentSearches, id: \.self) { search in
                        Button(action: { searchText = search }) {
                            HStack {
                                Image(systemName: "clock")
                                    .font(.caption)
                                Text(search)
                                    .font(.subheadline)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.primary)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .frame(maxWidth: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(searchService.searchResults) { result in
                    SearchResultRow(result: result, isSelected: selectedNote?.fileURL.standardizedFileURL == result.note.fileURL.standardizedFileURL)
                        .onTapGesture {
                            selectNote(result.note)
                        }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func selectNote(_ note: Note) {
        fileSystemService.updateAccessTime(for: note)
        selectedNote = note
        searchText = ""
        searchService.clearSearch()
        isPresented = false
    }

    private func performSearch() {
        searchService.search(query: searchText)
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    
    let isSelected: Bool
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.note.displayTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Spacer()
                
                relevanceBadge
            }
            
            highlightedContent
            
            HStack {
                if let parentFolder = getParentFolder() {
                    Label(parentFolder, systemImage: "folder")
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .white.opacity(0.6) : .gray)
                }
                
                Spacer()
                
                Text(formattedDate)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .white.opacity(0.6) : .gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .cornerRadius(6)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private var relevanceBadge: some View {
        let score = Int(result.relevanceScore * 100)
        return Text("\(score)% match")
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(isSelected ? .white : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                (isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            )
    }
    
    private var highlightedContent: some View {
        let lines = result.matchedLines
        let displayLines = Array(lines.prefix(8))
        let remainingCount = max(0, lines.count - 8)
        
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(displayLines.indices, id: \.self) { index in
                let parts = displayLines[index].components(separatedBy: "**")
                Text(attributedString(from: parts, isSelected: isSelected))
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            
            if remainingCount > 0 {
                Text("+\(remainingCount) more")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .orange)
            }
        }
    }
    
    private func attributedString(from parts: [String], isSelected: Bool) -> AttributedString {
        var result = AttributedString()
        
        for (index, part) in parts.enumerated() {
            var attrStr = AttributedString(part)
            if index % 2 == 1 {
                attrStr.foregroundColor = isSelected ? .yellow : .orange
                attrStr.font = .system(size: 12, weight: .semibold)
            } else {
                attrStr.foregroundColor = isSelected ? Color.white.opacity(0.8) : .secondary
            }
            result.append(attrStr)
        }
        
        return result
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        } else if isHovering {
            return Color.secondary.opacity(0.15)
        }
        return Color.clear
    }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: result.note.modifiedAt, relativeTo: Date())
    }
    
    private func getParentFolder() -> String? {
        let filePath = result.note.fileURL.deletingLastPathComponent().path
        if let rootPath = FileSystemService.shared.rootFolder?.path {
            if filePath != rootPath {
                let relativePath = filePath.replacingOccurrences(of: rootPath + "/", with: "")
                return relativePath.components(separatedBy: "/").first
            }
        }
        return nil
    }
}
