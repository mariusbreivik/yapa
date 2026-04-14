# Yapa

Yapa is a native macOS Markdown note app built with SwiftUI. Notes live as plain `.md` files inside a user-selected folder, with YAML frontmatter for metadata.

## Highlights

- Local-first note storage in the filesystem
- User-selected Yapa root folder with security-scoped bookmarks
- Top-level project folders with nested organization
- Autosave while typing, with note status feedback in the editor
- Markdown preview, formatting tools, templates, and focus mode
- Sidebar pinned/recent sections plus drag and drop for notes and folders
- SQLite FTS5 search with fuzzy fallback matching
- Quick Open, fuzzy search, and in-document find
- Launch screen with recent vault selection and workspace metrics

## Requirements

- macOS 14.0+
- Xcode 15+

## Getting Started

Open `Yapa.xcodeproj` in Xcode, then choose a folder for your Yapa root when the app launches.

`project.yml` is the source of truth for target, dependency, and scheme changes.

## Build

```bash
xcodebuild -project Yapa.xcodeproj -scheme Yapa -configuration Debug build
```

## Test

```bash
xcodebuild test -project Yapa.xcodeproj -scheme Yapa -configuration Debug
```

Single test example:

```bash
xcodebuild test -project Yapa.xcodeproj -scheme Yapa -configuration Debug -only-testing:YapaTests/SearchServiceTests/testBuildFuzzyQueryStripsUnsupportedCharacters
```

## Scripts

- `swift Scripts/GenerateAppIcon.swift` regenerates the app icon set in `Yapa/Resources/Assets.xcassets/AppIcon.appiconset`
- `bash Scripts/build-unsigned-dmg.sh` builds a release app and writes `dist/Yapa-<version>-unsigned.dmg`

## Keyboard Shortcuts

- `⌘N` New Note
- `⌘⇧N` New Project
- `⌘O` Select Yapa Folder
- `⌘K` Quick Open
- `⌘⇧F` Fuzzy Search
- `⌘F` Find in Document
- `⌘M` Move Note
- `⌘⇧R` Rename selected note or folder
- `⌘⇧/` Help

## Features

### Vaults and Projects

- Open or switch the Yapa root folder at any time
- Persist the selected folder across launches
- Seed a new empty Yapa folder with `My first project` and `Getting Started.md`
- Treat each top-level folder in the Yapa root as a project

### Notes and Editing

- Create Markdown notes with YAML frontmatter
- Edit note title and body
- Auto-focus the title field for new notes
- Auto-save while typing
- Toggle pin state for notes
- Move notes to another folder
- Delete notes
- Show markdown preview beside the editor
- Toggle focus mode
- Toggle the note stats panel
- Insert formatting snippets and templates from the editor toolbar

### Search and Navigation

- Fuzzy search across all notes
- SQLite FTS5-backed full-text search index
- Fuzzy fallback when FTS returns no results or errors
- Search result ranking with SQLite `bm25`
- Quick Open note picker
- Recent search history
- In-document find with live match count

### Metrics and Metadata

- YAML frontmatter fields: `title`, `created`, `modified`, `pinned`, `lastAccessed`
- Editor stats: words, characters, lines, reading time, unique words, sentences, average words per sentence, headings, links, code blocks, last opened, and note size
- Launch screen metrics for the current workspace

## App Structure

- `Yapa/App/YapaApp.swift` app entry point, commands, and Help content
- `Yapa/Views/ContentView.swift` launch screen and main app shell
- `Yapa/Views/SidebarView.swift` sidebar header, pinned/recent sections, project tree, drag and drop
- `Yapa/Views/NoteListView.swift` note list and empty states
- `Yapa/Views/EditorView.swift` editor, preview, formatting tools, and stats
- `Yapa/Views/SearchResultsView.swift` fuzzy search UI and recent searches
- `Yapa/Views/QuickSwitcherView.swift` quick open note picker
- `Yapa/Services/FileSystemService.swift` folder access, note/project CRUD, and starter content
- `Yapa/Services/SearchService.swift` SQLite-backed indexing and search
