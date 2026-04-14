# Yapa

Yapa is a native macOS Markdown note app built with SwiftUI. Notes are stored as plain `.md` files inside a user-selected folder, with YAML frontmatter used for metadata like title, timestamps, pin state, and last access time.

## Overview

- Local-first Markdown notes stored directly in the filesystem
- Yapa root selection with security-scoped bookmarks
- Top-level project folders inside each Yapa workspace
- Native macOS multi-pane UI for projects, notes, and editing
- SQLite FTS5 search with fuzzy fallback matching

## Features

### Vaults and Projects

- Open or switch the Yapa root folder at any time
- Persist the selected Yapa folder across launches
- Treat each top-level folder in the Yapa root as a project
- Automatically seed a brand new empty Yapa folder with:
  - `My first project`
  - `Getting Started.md`
- Show Yapa-level stats in the sidebar header
- Show pinned notes, recent notes, and the full project tree in the sidebar

### Sidebar and Organization

- Create top-level projects from the sidebar toolbar
- Create notes inside the selected project
- Rename folders and notes inline
- Delete folders from the project tree
- Expand and collapse nested folders
- Drag and drop folders between projects and subfolders
- Drag and drop notes into folders
- Drop folders back onto the Projects section to make them top-level again
- Visual drop-target feedback while dragging

### Notes and Editing

- Create Markdown notes with YAML frontmatter
- Auto-focus the title field for newly created notes
- Auto-save while typing
- Edit note title and body
- Toggle pin state for notes
- Move notes to a different folder
- Delete notes
- Show markdown preview beside the editor
- Toggle focus mode for distraction-free writing
- Toggle note stats panel
- Insert formatting snippets from the editor toolbar:
  - bold
  - italic
  - strikethrough
  - heading
  - link
  - inline code
  - quote
  - bulleted list
  - numbered list
- Insert a basic note template

### Search and Navigation

- Fuzzy search across all notes
- SQLite FTS5-backed full-text search index
- Fuzzy fallback search when FTS returns no results or fails
- Search result ranking with SQLite `bm25`
- Quick Open note picker
- Recent search history
- In-document find bar with live match count

### Metrics and Metadata

- Track note metadata in YAML frontmatter:
  - title
  - created
  - modified
  - pinned
  - lastAccessed
- Note statistics in the editor footer:
  - words
  - characters
  - lines
  - reading time
  - unique words
  - sentences
  - average words per sentence
  - headings
  - links
  - code blocks
  - checklist items
  - last opened
  - last edited
- Yapa-level metrics on the splash screen and project overview

## App Structure

- `Yapa/App/YapaApp.swift` - app entry point, commands, and Help menu
- `Yapa/Views/ContentView.swift` - main app shell and launch/project screens
- `Yapa/Views/SidebarView.swift` - sidebar header, pinned/recent sections, project tree, drag and drop
- `Yapa/Views/NoteListView.swift` - note list, sorting, empty states
- `Yapa/Views/EditorView.swift` - editor, preview, formatting tools, stats, and move flow
- `Yapa/Views/SearchResultsView.swift` - fuzzy search UI and recent searches
- `Yapa/Views/QuickSwitcherView.swift` - fast note picker
- `Yapa/Services/FileSystemService.swift` - root-folder access, note/project CRUD, starter content seeding
- `Yapa/Services/SearchService.swift` - SQLite-backed indexing and searching

## Keyboard Shortcuts

### Global

- `⌘N` - New Note
- `⌘⇧N` - New Project
- `⌘O` - Select Yapa Folder
- `⌘K` - Quick Open
- `⌘⇧F` - Fuzzy Search
- `⌘⇧/` - Yapa Help

### Editor

- `⌘F` - Find in Document
- `⌘M` - Move Note

### Context Actions

- `⌘⇧R` - Rename selected note or folder from the relevant context menu

## Search Implementation

- Uses `SQLite.swift`
- Stores a local search index in the caches directory as `search_index.sqlite`
- Builds an FTS5 virtual table over note id, title, content, and file URL
- Reindexes notes from the filesystem when the index is refreshed
- Falls back to in-memory fuzzy matching if FTS search produces no results or errors

## Build

```bash
xcodebuild -project Yapa.xcodeproj -scheme Yapa -configuration Debug build
```

## Test

```bash
xcodebuild test -project Yapa.xcodeproj -scheme Yapa -configuration Debug
```

Specific test example:

```bash
xcodebuild test -project Yapa.xcodeproj -scheme Yapa -configuration Debug -only-testing:YapaTests/SearchServiceTests/testBuildFuzzyQueryStripsUnsupportedCharacters
```

## Unsigned DMG

```bash
bash scripts/build-unsigned-dmg.sh
```

The disk image is written to `dist/Yapa-1.0.0-unsigned.dmg`.

## Requirements

- macOS 14.0+
- Xcode 15+
