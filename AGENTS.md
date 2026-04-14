# AGENTS.md

- macOS 14+ SwiftUI app. Entrypoint: `Yapa/App/YapaApp.swift`. Main shell: `Yapa/Views/ContentView.swift`.
- Notes are plain `.md` files in a user-selected Yapa folder. Metadata lives in YAML frontmatter.
- Search uses SQLite FTS5 with a fuzzy fallback. Keep queries sanitized; invalid operators like `~` can crash search.
- Shared state comes from `FileSystemService.shared` and `SearchService.shared` via `@EnvironmentObject`.
- `project.yml` is the source of truth for target, dependency, and scheme changes. Update it first, then regenerate the Xcode project.
- `opencode.json` enables the local Xcode MCP bridge.
- After code changes, check Xcode Issue Navigator for errors and warnings, fix them, then build and test.
- Add or update a test for every new feature or behavior change.
- Do not revert unrelated work in the shared tree.

## Commands

- Build: `xcodebuild -project Yapa.xcodeproj -scheme Yapa -configuration Debug build`
- Test: `xcodebuild test -project Yapa.xcodeproj -scheme Yapa -configuration Debug`
- Single test: `xcodebuild test -project Yapa.xcodeproj -scheme Yapa -configuration Debug -only-testing:YapaTests/<Class>/<method>`
