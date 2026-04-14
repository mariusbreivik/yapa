import SwiftUI

struct NoteListView: View {
    @EnvironmentObject var fileSystemService: FileSystemService
    
    let selectedFolder: FolderItem?
    @Binding var selectedNote: Note?
    
    @State private var sortOrder: SortOrder = .modified
    @State private var showSortMenu = false
    
    enum SortOrder: String, CaseIterable {
        case modified = "Modified"
        case created = "Created"
        case title = "Title"
        
        var icon: String {
            switch self {
            case .modified: return "clock"
            case .created: return "calendar"
            case .title: return "textformat"
            }
        }
    }
    
    private var displayedNotes: [Note] {
        let notes: [Note]
        
        if let folder = selectedFolder {
            notes = folder.notes
        } else {
            notes = fileSystemService.allNotes
        }
        
        switch sortOrder {
        case .modified:
            return notes.sorted { $0.modifiedAt > $1.modifiedAt }
        case .created:
            return notes.sorted { $0.createdAt > $1.createdAt }
        case .title:
            return notes.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            if displayedNotes.isEmpty {
                emptyState
            } else {
                notesList
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: sortOrder)
    }
    
    private var header: some View {
        HStack {
            Image(systemName: selectedFolder == nil ? "doc.on.doc" : "folder.fill")
                .foregroundColor(.accentColor)
            
            Text(headerTitle)
                .font(.headline)
                .lineLimit(1)
            
            if !displayedNotes.isEmpty {
                Text("\(displayedNotes.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            Menu {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Button(action: { withAnimation { sortOrder = order } }) {
                        HStack {
                            Image(systemName: order.icon)
                            Text(order.rawValue)
                            if sortOrder == order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text("Sort")
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    private var headerTitle: String {
        if let folder = selectedFolder {
            return folder.name
        }
        return "All Notes"
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .opacity(0.5)
            
            VStack(spacing: 8) {
                Text("No notes yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(emptyStateMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: createNote) {
                Label("Create your first note", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            createNote()
        }
    }
    
    private var emptyStateMessage: String {
        if selectedFolder != nil {
            return "This folder is empty.\nCreate a new note to get started."
        }
        return "Create a new note to get started.\nYour thoughts, organized."
    }
    
    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(displayedNotes) { note in
                    NoteRowView(
                        note: note,
                        isSelected: selectedNote?.fileURL.standardizedFileURL == note.fileURL.standardizedFileURL,
                        onSelect: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedNote = note
                            }
                        }
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func createNote() {
        let folder = selectedFolder?.url ?? fileSystemService.folderStructure.first?.url
        guard let folder else { return }
        if let newNote = fileSystemService.createNote(in: folder) {
            withAnimation {
                selectedNote = newNote
            }
        }
    }
}

struct NoteRowView: View {
    @EnvironmentObject var fileSystemService: FileSystemService

    let note: Note
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }
                    
                    Text(note.displayTitle)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(isSelected ? .white : .primary)
                }
                
                Text(previewText)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(formattedDate)
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .white.opacity(0.6) : .gray)
                    
                    if note.wordCount > 0 {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(isSelected ? .white.opacity(0.4) : .gray)
                        
                        Text("\(note.wordCount) words")
                            .font(.system(size: 10))
                            .foregroundColor(isSelected ? .white.opacity(0.6) : .gray)
                    }
                }
            }
            
            Spacer()

            Button(action: togglePin) {
                Image(systemName: note.isPinned ? "pin.fill" : "pin")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(isSelected ? .white : (note.isPinned ? .orange : .secondary))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .opacity(isHovering || isSelected || note.isPinned ? 1 : 0.35)
            .help(note.isPinned ? "Unpin" : "Pin")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(backgroundColor)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
    
    private var previewText: String {
        let content = note.content
            .replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if content.count > 100 {
            return String(content.prefix(100)) + "..."
        }
        return content
    }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: note.modifiedAt, relativeTo: Date())
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        } else if isHovering {
            return Color.secondary.opacity(0.08)
        }
        return Color.clear
    }

    private var borderColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.35)
        } else if isHovering {
            return Color.secondary.opacity(0.16)
        }
        return Color.clear
    }

    private func togglePin() {
        fileSystemService.togglePin(for: note)
    }
}
