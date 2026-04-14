# AGENTS.md

- This is a macOS 14+ SwiftUI app. `Yapa/App/YapaApp.swift` is the entrypoint; `ContentView` wires the main shell.
- `project.yml` is the source of truth for project structure and dependencies. Update it first for target, package, or scheme changes, then regenerate the Xcode project.
- Notes are plain `.md` files in a user-selected Yapa folder. Metadata is stored in YAML frontmatter (`title`, `created`, `modified`, `pinned`, `lastAccessed`).
- Search uses SQLite FTS5 plus a fuzzy fallback. Keep FTS queries sanitized; invalid operators like `~` will crash search.
- Shared state lives in `FileSystemService.shared` and `SearchService.shared` via `@EnvironmentObject`.
- `YapaTests` is the unit-test target.
- Always check Xcode's Issue Navigator after code changes, including warnings, and fix any reported issues before finishing.
- Add or update a test for each new feature or behavior change.
- If a change touches generated project structure, update `project.yml` first and regenerate the Xcode project before validating.
- Keep changes small and avoid reverting unrelated work in the workspace.

## Commands

- Build: `xcodebuild -project Yapa.xcodeproj -scheme Yapa -configuration Debug build`
- Test: `xcodebuild test -project Yapa.xcodeproj -scheme Yapa -configuration Debug`
- Single test: `xcodebuild test -project Yapa.xcodeproj -scheme Yapa -configuration Debug -only-testing:YapaTests/SearchServiceTests/testBuildFuzzyQueryStripsUnsupportedCharacters`

## Repo Notes

- `opencode.json` enables the local Xcode MCP bridge.
- Keep changes small and prefer editing the generated source files only when the `project.yml`/project file is already in sync.
