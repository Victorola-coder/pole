# Contributing to Pole

Thanks for helping improve this project. The following guidelines keep reviews predictable and the codebase maintainable.

## How to contribute

1. **Open an issue** (or discuss in an existing one) before large refactors or new features, so direction and scope are agreed.
2. **Fork the repository** (if you use forks) and create a **feature branch** from the default development branch (e.g. `dev` or `main`, as used in this repo).
3. **Make focused changes**: one logical concern per pull request when possible.
4. **Run tests** locally in Xcode (**⌘U**) before opening a PR; fix any failures.
5. **Open a pull request** with a clear title and description of what changed and why.

## Pull request checklist

- [ ] Builds cleanly in Xcode for the **Pole** scheme (simulator is fine unless your change is device-specific).
- [ ] Unit tests pass (**PoleTests**).
- [ ] No new Swift warnings that the team treats as errors (address serious analyzer issues).
- [ ] User-visible behavior changes are described in the PR (screenshots or short notes help).
- [ ] If you change `project.yml`, run `xcodegen generate` and include the updated `Pole.xcodeproj` if the project is committed.

## Code style

- **Swift**: Follow common Swift conventions and match existing patterns in the repo (naming, file layout, MVVM-style separation already in use).
- **UI**: Prefer SwiftUI patterns already used in the app; keep accessibility in mind for interactive controls.
- **Scope**: Avoid unrelated refactors or drive-by formatting-only edits in the same PR as a bugfix unless necessary.

## What we look for

- Clear, readable code with descriptive names.
- Error handling appropriate for user-facing flows (permissions, file access, PhotoKit).
- Respect for user privacy: do not log sensitive paths or personal media identifiers in production code without a strong reason and documentation.

## Questions

If something in the workflow or architecture is unclear, ask in an issue or PR comment. Small, incremental PRs are easier to review and merge.
