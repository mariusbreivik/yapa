# Yapa ✨

Yapa is a local-first macOS Markdown notes app built with SwiftUI. Notes stay as plain `.md` files inside a user-selected folder, with YAML frontmatter for metadata.

## Highlights 🌟

- 🗂️ Local note storage in the filesystem
- 🔐 User-selected Yapa root folder with security-scoped bookmarks
- 🧩 Top-level project folders with nested organization
- 💾 Autosave while typing, with editor status feedback
- 📝 Markdown preview, formatting tools, templates, and focus mode
- 📌 Sidebar pinned/recent sections plus drag and drop for notes and folders
- 🔎 SQLite FTS5 search with fuzzy fallback matching
- 🚀 Quick Open, fuzzy search, and in-document find
- 📊 Launch screen with recent vault selection and workspace metrics

## Requirements 🛠️

- macOS 14.0+
- Xcode 15+

## Getting Started 🚪

1. Open `Yapa.xcodeproj` in Xcode.
2. Launch the app and choose a Yapa folder when prompted.
3. Use the built-in templates or create new notes/projects from the toolbar.

`project.yml` is the source of truth for target, dependency, and scheme changes.

## Configuration ⚙️

- `project.yml` defines the app target, test target, deployment target, Swift version, and package dependencies.
- The app depends on `Down` for Markdown rendering and `SQLite.swift` for search indexing.
- `Templates/` contains the built-in note templates shipped in the app bundle.
- `Yapa/Resources/` contains app icon, Info.plist, and entitlements files.
- Release builds use the version metadata stamped into the bundle.
- Release notes are generated from merged PRs, and `.github/release-changelog-builder.config.json` matches Conventional Commit-style PR titles like `fix:` and `docs:`.

## Development 🧪

- Open `Yapa.xcodeproj` in Xcode and work from the `Yapa` scheme
- Build from the command line with `xcodebuild -project Yapa.xcodeproj -scheme Yapa -configuration Debug build`
- Run the full test suite with `xcodebuild test -project Yapa.xcodeproj -scheme Yapa -configuration Debug`
- Check Xcode's Issue Navigator before shipping changes, especially after editing search, file system, or release code

## Build 🚧

```bash
xcodebuild -project Yapa.xcodeproj -scheme Yapa -configuration Debug build
```

## Test ✅

```bash
xcodebuild test -project Yapa.xcodeproj -scheme Yapa -configuration Debug
```

Single test example:

```bash
xcodebuild test -project Yapa.xcodeproj -scheme Yapa -configuration Debug -only-testing:YapaTests/SearchServiceTests/testBuildFuzzyQueryStripsUnsupportedCharacters
```

## Scripts 🧰

- `swift Scripts/GenerateAppIcon.swift` regenerates the app icon set in `Yapa/Resources/Assets.xcassets/AppIcon.appiconset`
- `bash Scripts/build-unsigned-dmg.sh` builds a release app and writes `dist/Yapa-<version>-unsigned.dmg`
- `Scripts/build-unsigned-dmg.sh` accepts optional `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` environment variables
- The DMG script requires a macOS build machine with `xcodebuild`, `ditto`, and `hdiutil`

## Templates 🧾

- Built-in note templates live in `Templates/`
- The shipped templates are `Quick Note.md`, `Daily Standup.md`, `Meeting Note.md`, and `Weekly Review.md`
- Add new templates by placing additional `.md` files in that folder

## GitHub Actions 🚀

- `CI` runs on `pull_request` and pushes to `main`, then builds and tests the app before merge.
- `Release` is triggered manually, checks out `main`, creates the next semantic version tag, and produces an unsigned versioned `.dmg` for distribution as a GitHub Release asset.
- `Notify Slack on Release` runs after the `Release` workflow completes successfully and posts release details to Slack.
- The release workflow accepts an optional `build_number` input.
- Conventional Commit-style PR titles drive semver bumps: `feat:` for minor, `fix:` for patch, and `feat!:` or `BREAKING CHANGE:` for major.
- `Notify Slack on Release` requires a configured `SLACK_BOT_TOKEN` secret.
- Release notes are generated from merged commits and linked PRs between the previous release tag and the new release tag.

## Versioning 🔖

- The app displays the current version as `vX.Y.Z (build)` in the launch screen and Help window.
- The UI reads from bundle metadata, so the running app shows the same version that was stamped during release.
- Release builds derive `MARKETING_VERSION` from the latest tag on `main` and `CURRENT_PROJECT_VERSION` from the release workflow input or workflow run number.
- The unsigned release DMG is renamed from `Yapa-<version>-unsigned.dmg` to `Yapa-<version>.dmg` during release.

Recommended branch protection for `main` 🔒:

- Require the `CI` workflow to pass before merging.
- Require pull requests for all changes.
- Restrict direct pushes to `main`.

## Keyboard Shortcuts ⌨️

- `⌘N` New Note
- `⌘⇧N` New Project
- `⌘O` Select Yapa Folder
- `⌘K` Quick Open
- `⌘⇧F` Fuzzy Search
- `⌘F` Find in Document
- `⌘M` Move Note
- `⌘⇧R` Rename selected note or folder
- `⌘⇧/` Help

## Features 📚

### Vaults and Projects 🗃️

- Open or switch the Yapa root folder at any time
- Persist the selected folder across launches
- Seed a new empty Yapa folder with `My first project` and `Getting Started.md`
- Treat each top-level folder in the Yapa root as a project

### Notes and Editing ✍️

- Create Markdown notes with YAML frontmatter
- Edit note title and body
- Add and remove note tags from the bottom note metadata section
- Auto-focus the title field for new notes
- Auto-save while typing
- Toggle pin state for notes
- Move notes to another folder
- Delete notes
- Show markdown preview beside the editor
- Toggle focus mode
- Toggle the note stats panel
- Insert formatting snippets and templates from the editor toolbar

### Search and Navigation 🔍

- Fuzzy search across all notes
- Tag-aware filtering with `tag:foo` search syntax
- SQLite FTS5-backed full-text search index
- Fuzzy fallback when FTS returns no results or errors
- Search result ranking with SQLite `bm25`
- Quick Open note picker
- Recent search history
- In-document find with live match count

### Metrics and Metadata 📈

- YAML frontmatter fields: `title`, `created`, `modified`, `pinned`, `lastAccessed`, `tags`
- Editor stats: words, characters, lines, reading time, unique words, sentences, average words per sentence, headings, links, code blocks, last opened, and note size
- Launch screen metrics for the current workspace

## App Structure 🧱

- `Yapa/App/YapaApp.swift` app entry point, commands, and Help content
- `Yapa/Views/ContentView.swift` launch screen and main app shell
- `Yapa/Views/SidebarView.swift` sidebar header, pinned/recent sections, project tree, drag and drop
- `Yapa/Views/NoteListView.swift` note list and empty states
- `Yapa/Views/EditorView.swift` editor, preview, formatting tools, and stats
- `Yapa/Views/SearchResultsView.swift` fuzzy search UI and recent searches
- `Yapa/Views/QuickSwitcherView.swift` quick open note picker
- `Yapa/Services/FileSystemService.swift` folder access, note/project CRUD, and starter content
- `Yapa/Services/SearchService.swift` SQLite-backed indexing and search
