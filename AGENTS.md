# AGENTS.md

## Working Rules

- Inspect the relevant files before changing anything.
- Prefer the smallest correct change.
- Preserve unrelated work in the tree.
- Ask a short question if requirements are ambiguous or conflicting.
- Keep edits ASCII unless the file already uses non-ASCII.

- macOS 14+ SwiftUI app. Entrypoint: `Yapa/App/YapaApp.swift`. Main shell: `Yapa/Views/ContentView.swift`.
- Notes are plain `.md` files in a user-selected Yapa folder. Metadata lives in YAML frontmatter.
- Search uses SQLite FTS5 with a fuzzy fallback. Keep queries sanitized; invalid operators like `~` can crash search.
- Shared state comes from `FileSystemService.shared` and `SearchService.shared` via `@EnvironmentObject`.
- `project.yml` is the source of truth for target, dependency, and scheme changes. Update it first, then regenerate the Xcode project.
- `opencode.json` enables the local Xcode MCP bridge.
- After code changes, check Xcode Issue Navigator for errors and warnings, fix them, then build and test.
- Add or update a test for every new feature or behavior change.
- Do not revert unrelated work in the shared tree.

## Agent Modes

- `Plan`: analyze and propose; do not edit files.
- `Build`: implement changes, run verification, and fix failures.
- `Explore`: search and summarize; avoid edits unless explicitly needed.

## MCP And Tool Safety

- Treat MCP servers and skills as privileged inputs.
- Prefer narrow tool scope and approved servers only.
- Require explicit approval for write or high-impact actions.
- Sanitize any user- or tool-derived search input before using it.

## Response Quality

- State assumptions when they matter.
- Use concrete file references when explaining changes.
- Include tests and build verification in the final check.

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

## OpenCode Notes

- Prefer `permission` over deprecated `tools` in `opencode.json`.
- Use `steps` to bound long-running agents.
- Hide internal subagents when they are only meant for orchestration.
- Keep agent prompts structured with purpose, constraints, and examples.
