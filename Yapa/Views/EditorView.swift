import SwiftUI
import AppKit
import WebKit
import Down

struct EditorView: View {
    @EnvironmentObject var fileSystemService: FileSystemService
    
    let note: Note
    let onMoveNote: (Note) -> Void
    @Binding var showFindBar: Bool
    
    @State private var editedContent: String
    @State private var editedTitle: String
    @State private var showPreview = false
    @State private var isEditing = true
    @State private var hasChanges = false
    @State private var saveTimer: Timer?
    @State private var saveStatusClearTimer: Timer?
    @State private var saveStatus: SaveStatus?
    @State private var isFocusMode = false
    @State private var showStats = true
    @State private var showMovePicker = false
    @State private var showTemplatePicker = false
    @State private var findQuery = ""
    @State private var tagDraft = ""
    @State private var editedTags: [String]
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isFindFocused: Bool
    
    init(note: Note, onMoveNote: @escaping (Note) -> Void = { _ in }, showFindBar: Binding<Bool> = .constant(false)) {
        self.note = note
        self.onMoveNote = onMoveNote
        self._showFindBar = showFindBar
        _editedContent = State(initialValue: note.content)
        _editedTitle = State(initialValue: note.title)
        _editedTags = State(initialValue: note.tags)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if showFindBar {
                findBar
            }
            
            HSplitView {
                editorPane
                
                if showPreview {
                    previewPane
                }
            }
            
            if showStats {
                VStack(spacing: 0) {
                    tagsBar
                    statsBar
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onChange(of: editedContent) { _, _ in
            markAsChanged()
        }
        .onChange(of: editedTitle) { _, _ in
            markAsChanged()
        }
        .onChange(of: showFindBar) { _, visible in
            if visible {
                DispatchQueue.main.async {
                    isFindFocused = true
                }
            } else {
                findQuery = ""
            }
        }
        .onAppear {
            fileSystemService.updateAccessTime(for: currentNote)
            if note.title == "Untitled" {
                DispatchQueue.main.async {
                    isTitleFocused = true
                }
            }
        }
        .onChange(of: note.tags) { _, tags in
            editedTags = tags
        }
        .sheet(isPresented: $showMovePicker) {
            MoveNotePickerView(
                note: currentNote,
                selectedDestinationURL: currentNote.fileURL.deletingLastPathComponent(),
                onCancel: { showMovePicker = false },
                onMove: moveNote
            )
        }
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerView(
                templates: fileSystemService.templates,
                onCancel: { showTemplatePicker = false },
                onSelect: { template in
                    insertTemplate(template.content)
                    showTemplatePicker = false
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .insertTemplate)) { _ in
            showTemplatePicker = true
        }
    }
    
    private var toolbar: some View {
        HStack {
            if isFocusMode {
                Button(action: { isFocusMode = false }) {
                    Image(systemName: "arrow.left")
                }
                .buttonStyle(.bordered)
            }
            
            TextField("Title", text: $editedTitle)
                .textFieldStyle(.plain)
                .font(.title2.bold())
                .frame(maxWidth: 300)
                .focused($isTitleFocused)

            Divider()
                .frame(height: 20)

            HStack(spacing: 2) {
                ForEach(formattingControls) { control in
                    Button(action: { applyFormatting(control.format) }) {
                        Image(systemName: control.symbol)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 24, height: 24)
                    .background(Color.clear)
                    .help(control.label)
                }

                Divider()
                    .frame(height: 16)

                Button(action: { showTemplatePicker = true }) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .help("Insert Template (⌘⇧T)")
            }
            
            Spacer()
            
            Button(action: { showFindBar = true }) {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.bordered)
            .help("Find (⌘F)")
            
            Button(action: { isFocusMode.toggle() }) {
                Image(systemName: isFocusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.bordered)
            .help("Focus Mode")
            
            Button(action: { showPreview.toggle() }) {
                Image(systemName: showPreview ? "eye.fill" : "eye")
            }
            .buttonStyle(.bordered)
            .help(showPreview ? "Hide Preview" : "Show Preview")
            
            Button(action: { showStats.toggle() }) {
                Image(systemName: "text.word.spacing")
            }
            .buttonStyle(.bordered)
            .help("Toggle Stats")

            Button(action: togglePin) {
                Image(systemName: currentNote.isPinned ? "pin.fill" : "pin")
            }
            .buttonStyle(.bordered)
            .tint(currentNote.isPinned ? .orange : .secondary)
            .help(currentNote.isPinned ? "Unpin" : "Pin")
            
            Button(action: { showMovePicker = true }) {
                Image(systemName: "folder")
            }
            .buttonStyle(.bordered)
            .help("Move Note")
            .keyboardShortcut("m", modifiers: [.command])
            
            Button(action: deleteNote) {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    private var findBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Find in document", text: $findQuery)
                .textFieldStyle(.roundedBorder)
                .focused($isFindFocused)
                .onSubmit { isFindFocused = true }
                .onExitCommand { showFindBar = false }

            Text(findMetrics)
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: { showFindBar = false }) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Close Find")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    private var formattingControls: [FormattingControl] {
        [
            FormattingControl(symbol: "bold", label: "Bold", format: "bold"),
            FormattingControl(symbol: "italic", label: "Italic", format: "italic"),
            FormattingControl(symbol: "strikethrough", label: "Strikethrough", format: "strikethrough"),
            FormattingControl(symbol: "textformat.size.larger", label: "Heading", format: "heading"),
            FormattingControl(symbol: "link", label: "Link", format: "link"),
            FormattingControl(symbol: "chevron.left.forwardslash.chevron.right", label: "Code", format: "code"),
            FormattingControl(symbol: "text.quote", label: "Quote", format: "quote"),
            FormattingControl(symbol: "list.bullet", label: "Bullet List", format: "list.bullet"),
            FormattingControl(symbol: "list.number", label: "Numbered List", format: "list.number")
        ]
    }
    
    private var editorPane: some View {
        DocumentTextEditor(text: $editedContent, searchQuery: findQuery)
            .padding()
            .opacity(isFocusMode ? 1.0 : 0.9)
            .animation(.easeInOut(duration: 0.3), value: isFocusMode)
    }

    private var previewPane: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "eye")
                    .foregroundColor(.secondary)
                Text("Preview")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            MarkdownPreviewView(content: editedContent)
                .frame(minWidth: 300)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .leading) {
            Divider()
        }
    }
    
    private var statsBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize()

                Text("Stats")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer()

                if let saveStatus {
                    Text(saveStatus.title)
                        .foregroundColor(saveStatus.color)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                metricChip("Words", "\(currentNote.wordCount)")
                metricChip("Chars", "\(currentNote.characterCount)")
                metricChip("Lines", "\(currentNote.lineCount)")
                metricChip("Read", "\(currentNote.readingTimeMinutes)m")
                metricChip("Unique", "\(currentNote.uniqueWordCount)")
                metricChip("Sentences", "\(currentNote.sentenceCount)")
                metricChip("Avg/Sent", String(format: "%.1f", currentNote.averageWordsPerSentence))
                metricChip("Headings", "\(currentNote.headingCount)")
                metricChip("Links", "\(currentNote.linkCount)")
                metricChip("Code", "\(currentNote.codeBlockCount)")
                metricChip("Opened", relative(date: currentNote.lastAccessedAt))
                metricChip("Size", String(format: "%.1f KB", Double(currentNote.characterCount) / 1024.0))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var tagsBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "tag")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("Tags")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(editedTags.isEmpty ? "No tags yet" : "\(editedTags.count) tags")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if editedTags.isEmpty {
                Text("Add tags to classify this note.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(editedTags, id: \.self) { tag in
                            tagChip(tag)
                        }
                    }
                }
            }

            HStack(spacing: 4) {
                TextField("Add a tag", text: $tagDraft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTag)

                Button {
                    addTag()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .disabled(tagDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func tagChip(_ tag: String) -> some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Button(action: { removeTag(tag) }) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Remove tag")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.12))
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
        }
        .clipShape(Capsule(style: .continuous))
    }

    private func metricChip(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(Color.orange.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func relative(date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func markAsChanged() {
        hasChanges = true
        saveStatusClearTimer?.invalidate()
        saveStatus = .unsaved
        
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            saveNote()
        }
    }
    
    private func saveNote() {
        saveTimer?.invalidate()
        saveStatusClearTimer?.invalidate()
        
        var updatedNote = currentNote
        updatedNote.title = editedTitle
        updatedNote.content = editedContent
        updatedNote.modifiedAt = Date()
        updatedNote.tags = editedTags
        
        fileSystemService.saveNote(updatedNote)
        hasChanges = false
        saveStatus = .saved
        saveStatusClearTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            saveStatus = nil
        }
    }
    
    private func togglePin() {
        fileSystemService.togglePin(for: currentNote)
    }
    
    private func deleteNote() {
        fileSystemService.deleteNote(currentNote)
    }

    private func addTag() {
        let tag = tagDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        guard !editedTags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) else {
            tagDraft = ""
            return
        }
        editedTags.append(tag)
        tagDraft = ""
        saveNote()
    }

    private func removeTag(_ tag: String) {
        editedTags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
        saveNote()
    }

    private var currentNote: Note {
        let targetURL = note.fileURL.standardizedFileURL
        return fileSystemService.allNotes.first {
            $0.fileURL.standardizedFileURL == targetURL
        } ?? note
    }
    
    private func formatLabel(for format: String) -> String {
        switch format {
        case "bold": return "Bold (⌘B)"
        case "italic": return "Italic (⌘I)"
        case "strikethrough": return "Strikethrough"
        case "heading": return "Heading"
        case "link": return "Link (⌘K)"
        case "code": return "Code"
        case "quote": return "Quote"
        case "list.bullet": return "Bullet List"
        case "list.number": return "Numbered List"
        default: return format
        }
    }
    
    private func applyFormatting(_ format: String) {
        switch format {
        case "bold":
            insertMarkdown("**", "**", "bold text")
        case "italic":
            insertMarkdown("*", "*", "italic text")
        case "strikethrough":
            insertMarkdown("~~", "~~", "strikethrough text")
        case "heading":
            insertLinePrefix("## ")
        case "link":
            insertMarkdown("[", "](url)", "link text")
        case "code":
            insertMarkdown("`", "`", "code")
        case "quote":
            insertLinePrefix("> ")
        case "list.bullet":
            insertLinePrefix("- ")
        case "list.number":
            insertLinePrefix("1. ")
        default:
            break
        }
    }
    
    private func insertMarkdown(_ prefix: String, _ suffix: String, _ placeholder: String) {
        editedContent += "\(prefix)\(placeholder)\(suffix)"
    }
    
    private func insertLinePrefix(_ prefix: String) {
        editedContent += "\n\(prefix)"
    }
    
    private func insertTemplate(_ templateContent: String = "") {
        let template = templateContent.isEmpty ? """

## Template

### Section 1
Your content here

### Section 2
More content

""" : templateContent
        editedContent += template
    }
    
    private func moveNote(to destinationURL: URL) {
        if let updatedNote = fileSystemService.moveNote(currentNote, to: destinationURL) {
            onMoveNote(updatedNote)
            showMovePicker = false
        }
    }

    private var findMetrics: String {
        guard !findQuery.isEmpty else { return "0 matches" }
        let count = matchRanges(in: editedContent, query: findQuery).count
        return count == 1 ? "1 match" : "\(count) matches"
    }

    private func matchRanges(in text: String, query: String) -> [NSRange] {
        let terms = searchTerms(from: query)
        guard !terms.isEmpty else { return [] }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var ranges: [NSRange] = []

        for term in terms {
            var searchRange = fullRange
            while true {
                let found = nsText.range(of: term, options: [.caseInsensitive], range: searchRange)
                if found.location == NSNotFound { break }
                ranges.append(found)
                let nextLocation = found.location + max(found.length, 1)
                guard nextLocation < nsText.length else { break }
                searchRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
            }
        }

        return ranges
    }

    private func searchTerms(from query: String) -> [String] {
        query
            .lowercased()
            .split { $0.isWhitespace || $0.isNewline || $0.isPunctuation }
            .map { String($0).filter { $0.isLetter || $0.isNumber } }
            .filter { !$0.isEmpty }
    }
}

private enum SaveStatus {
    case unsaved
    case saved

    var title: String {
        switch self {
        case .unsaved: return "Unsaved changes"
        case .saved: return "Saved"
        }
    }

    var color: Color {
        switch self {
        case .unsaved: return .orange
        case .saved: return .green
        }
    }
}

struct DocumentTextEditor: NSViewRepresentable {
    @Binding var text: String
    let searchQuery: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.backgroundColor = .clear

        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView
        textView.string = text
        context.coordinator.applyHighlights(in: textView, query: searchQuery)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            let newLocation = min(selection.location, (text as NSString).length)
            textView.setSelectedRange(NSRange(location: newLocation, length: 0))
        }

        context.coordinator.applyHighlights(in: textView, query: searchQuery)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: NSTextView?

        private var currentQuery = ""

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            applyHighlights(in: textView, query: currentQuery)
        }

        func applyHighlights(in textView: NSTextView, query: String) {
            currentQuery = query
            guard let storage = textView.textStorage else { return }

            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            storage.beginEditing()
            storage.removeAttribute(.backgroundColor, range: fullRange)

            let terms = query
                .lowercased()
                .split { $0.isWhitespace || $0.isNewline || $0.isPunctuation }
                .map { String($0).filter { $0.isLetter || $0.isNumber } }
                .filter { !$0.isEmpty }

            for term in terms {
                var searchRange = fullRange
                while true {
                    let found = (textView.string as NSString).range(of: term, options: [.caseInsensitive], range: searchRange)
                    if found.location == NSNotFound { break }
                    storage.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.35), range: found)
                    let nextLocation = found.location + max(found.length, 1)
                    guard nextLocation < fullRange.length else { break }
                    searchRange = NSRange(location: nextLocation, length: fullRange.length - nextLocation)
                }
            }

            storage.endEditing()
        }
    }
}

struct MoveNotePickerView: View {
    @EnvironmentObject var fileSystemService: FileSystemService
    
    let note: Note
    let selectedDestinationURL: URL
    let onCancel: () -> Void
    let onMove: (URL) -> Void
    
    @State private var destinationURL: URL
    
    init(note: Note, selectedDestinationURL: URL, onCancel: @escaping () -> Void, onMove: @escaping (URL) -> Void) {
        self.note = note
        self.selectedDestinationURL = selectedDestinationURL.standardizedFileURL
        self.onCancel = onCancel
        self.onMove = onMove
        _destinationURL = State(initialValue: selectedDestinationURL.standardizedFileURL)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            destinationList
            footer
        }
        .frame(width: 420, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Move Note")
                .font(.title3.weight(.semibold))
            
            Text(note.displayTitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Text("Choose a destination project or folder.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var destinationList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(fileSystemService.folderStructure) { folder in
                    folderDestinationRows(for: folder, depth: 0)
                }
            }
            .padding(12)
        }
    }
    
    @ViewBuilder
    private func folderDestinationRows(for folder: FolderItem, depth: Int) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 6) {
                destinationRow(
                    title: folder.name,
                    subtitle: folder.url.path,
                    url: folder.url.standardizedFileURL,
                    depth: depth,
                    symbol: "folder"
                )
                
                ForEach(folder.children) { child in
                    folderDestinationRows(for: child, depth: depth + 1)
                }
            }
        )
    }
    
    private func destinationRow(title: String, subtitle: String, url: URL, depth: Int, symbol: String) -> some View {
        Button(action: {
            destinationURL = url.standardizedFileURL
        }) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundColor(destinationURL.standardizedFileURL == url.standardizedFileURL ? .white : .accentColor)
                    .frame(width: 18)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(destinationURL.standardizedFileURL == url.standardizedFileURL ? .white : .primary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(destinationURL.standardizedFileURL == url.standardizedFileURL ? .white.opacity(0.7) : .secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .padding(.leading, CGFloat(depth * 14))
            .background(destinationURL.standardizedFileURL == url.standardizedFileURL ? Color.accentColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private var footer: some View {
        HStack {
            Button("Cancel", action: onCancel)
            
            Spacer()
            
            Button("Move") {
                onMove(destinationURL.standardizedFileURL)
            }
            .buttonStyle(.borderedProminent)
            .disabled(destinationURL.standardizedFileURL == note.fileURL.deletingLastPathComponent().standardizedFileURL)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct FormattingControl: Identifiable {
    let symbol: String
    let label: String
    let format: String
    var id: String { format }
}

private struct TagWrapLayout<Item: Hashable, TagContent: View>: View {
    let items: [Item]
    let content: (Item) -> TagContent

    var body: some View {
        GeometryReader { proxy in
            let rows = makeRows(maxWidth: proxy.size.width)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: 8) {
                        ForEach(rows[rowIndex], id: \.self) { item in
                            content(item)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 1)
    }

    private func makeRows(maxWidth: CGFloat) -> [[Item]] {
        var rows: [[Item]] = [[]]
        var currentWidth: CGFloat = 0

        for item in items {
            let itemWidth = estimatedWidth(for: item)
            if currentWidth + itemWidth > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([item])
                currentWidth = itemWidth + 8
            } else {
                rows[rows.count - 1].append(item)
                currentWidth += itemWidth + 8
            }
        }

        return rows
    }

    private func estimatedWidth(for item: Item) -> CGFloat {
        max(72, CGFloat(String(describing: item).count) * 8.2 + 44)
    }
}

struct TemplatePickerView: View {
    let templates: [NoteTemplate]
    let onCancel: () -> Void
    let onSelect: (NoteTemplate) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .frame(width: 420, height: 360)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Insert Template")
                .font(.title3.weight(.semibold))

            Text("Choose a template to insert into the current note.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var content: some View {
        if templates.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)

                Text("No templates available")
                    .font(.headline)

                Text("Add Markdown templates to the app bundle to use them here.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("Close", action: onCancel)
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(templates) { template in
                        Button(action: { onSelect(template) }) {
                            HStack(spacing: 12) {
                                Image(systemName: template.icon)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 18)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(template.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Text(templatePreview(for: template))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
            .overlay(alignment: .bottomTrailing) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                    .padding(12)
            }
        }
    }

    private func templatePreview(for template: NoteTemplate) -> String {
        let lines = template.content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.prefix(2).joined(separator: "  ")
    }
}

struct MarkdownPreviewView: NSViewRepresentable {
    let content: String
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = renderMarkdown(content)
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    private func renderMarkdown(_ markdown: String) -> String {
        do {
            let down = Down(markdownString: markdown)
            let html = try down.toHTML()
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                    :root {
                        color-scheme: light dark;
                    }
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                        font-size: 14px;
                        line-height: 1.6;
                        padding: 20px;
                        max-width: 800px;
                        margin: 0 auto;
                        background-color: transparent;
                        color: #333;
                    }
                    @media (prefers-color-scheme: dark) {
                        body { color: #ccc; }
                        a { color: #6eb5ff; }
                        code { background: #2d2d2d; }
                        pre { background: #2d2d2d; }
                        blockquote { border-left-color: #555; }
                    }
                    h1, h2, h3, h4, h5, h6 { margin-top: 24px; margin-bottom: 16px; font-weight: 600; }
                    h1 { font-size: 2em; border-bottom: 1px solid #eee; padding-bottom: 0.3em; }
                    h2 { font-size: 1.5em; border-bottom: 1px solid #eee; padding-bottom: 0.3em; }
                    h3 { font-size: 1.25em; }
                    code { padding: 0.2em 0.4em; background: #f4f4f4; border-radius: 3px; font-family: 'SF Mono', Menlo, monospace; }
                    pre { padding: 16px; background: #f4f4f4; border-radius: 6px; overflow-x: auto; }
                    pre code { padding: 0; background: none; }
                    blockquote { margin: 0; padding-left: 1em; border-left: 4px solid #ddd; color: #666; }
                    a { color: #0969da; text-decoration: none; }
                    a:hover { text-decoration: underline; }
                    img { max-width: 100%; height: auto; }
                    table { border-collapse: collapse; width: 100%; }
                    th, td { border: 1px solid #ddd; padding: 8px; }
                    th { background: #f4f4f4; }
                </style>
            </head>
            <body>
            \(html)
            </body>
            </html>
            """
        } catch {
            return "<html><body><p>Error rendering markdown</p></body></html>"
        }
    }
}
