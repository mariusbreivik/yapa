import SwiftUI

struct QuickSwitcherView: View {
    @EnvironmentObject var fileSystemService: FileSystemService
    @Binding var isPresented: Bool
    @Binding var selectedNote: Note?
    
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool
    
    private var filteredNotes: [Note] {
        if searchText.isEmpty {
            return fileSystemService.allNotes.prefix(10).map { $0 }
        }
        
        let query = searchText.lowercased()
        return fileSystemService.allNotes
            .filter { note in
                note.displayTitle.lowercased().contains(query) ||
                note.content.lowercased().contains(query)
            }
            .prefix(10)
            .map { $0 }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchField
            
            if !filteredNotes.isEmpty {
                resultsList
            } else if !searchText.isEmpty {
                emptyState
            }
        }
        .frame(width: 500, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            isSearchFocused = true
        }
        .onDisappear {
            searchText = ""
        }
    }
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search notes...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($isSearchFocused)
                .onChange(of: searchText) { _, _ in
                    selectedIndex = 0
                }
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Button(action: { isPresented = false }) {
                Text("Esc")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(filteredNotes.enumerated()), id: \.element.id) { index, note in
                        QuickSwitcherRow(
                            note: note,
                            isSelected: index == selectedIndex,
                            searchText: searchText
                        )
                        .id(index)
                        .onTapGesture {
                            selectNote(note)
                        }
                        .onHover { hovering in
                            if hovering {
                                selectedIndex = index
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: selectedIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredNotes.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.return) {
            if !filteredNotes.isEmpty {
                selectNote(filteredNotes[selectedIndex])
            }
            return .handled
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No notes found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Try a different search term")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func selectNote(_ note: Note) {
        fileSystemService.updateAccessTime(for: note)
        selectedNote = note
        isPresented = false
    }
}

struct QuickSwitcherRow: View {
    let note: Note
    let isSelected: Bool
    let searchText: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                highlightedTitle
                    .font(.system(size: 14, weight: .medium))
                
                Text(note.content.prefix(60).replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "arrow.up.left")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
    }
    
    private var highlightedTitle: some View {
        let title = note.displayTitle
        let query = searchText.lowercased()
        
        if query.isEmpty {
            return Text(title)
                .foregroundColor(isSelected ? .white : .primary)
        }
        
        guard let range = title.lowercased().range(of: query) else {
            return Text(title)
                .foregroundColor(isSelected ? .white : .primary)
        }
        
        let before = String(title[title.startIndex..<range.lowerBound])
        let matched = String(title[range])
        let after = String(title[range.upperBound..<title.endIndex])
        
        return Text(before)
            .foregroundColor(isSelected ? .white : .primary)
        + Text(matched)
            .foregroundColor(isSelected ? .yellow : .orange)
            .bold()
        + Text(after)
            .foregroundColor(isSelected ? .white : .primary)
    }
}
