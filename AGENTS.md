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

## GitHub Issue Workflow

- Always start from `main`: `git checkout main` and `git pull --ff-only` or `git fetch` plus a fast-forward update.
- Create a new branch for the issue work before editing.
- Link the branch and PR to the issue number in the branch name, commit message, and PR body when practical.
- Use a semver-style commit message: `feat:` for new behavior, `fix:` for bug fixes, `chore:` for maintenance, `docs:` for documentation.
- Open a pull request for the branch before closing the issue.
- Close the issue only after the PR is created and the change is ready to merge, using a closing reference like `Closes #<issue>` in the PR body.

## Commands

- Build: `xcodebuild -project Yapa.xcodeproj -scheme Yapa -configuration Debug build`
- Test: `xcodebuild test -project Yapa.xcodeproj -scheme Yapa -configuration Debug`
- Single test: `xcodebuild test -project Yapa.xcodeproj -scheme Yapa -configuration Debug -only-testing:YapaTests/<Class>/<method>`
