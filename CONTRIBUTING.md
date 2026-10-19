# Contributing to Steppe

Steppe is a Ghostty fork with a native Herdr cockpit. Contributions should keep the Ghostty
core untouched unless the change is genuinely required by the integration.

## Development setup

See [docs/building.md](docs/building.md). In short:

```sh
export PATH="$HOME/.local/zig/zig-aarch64-macos-0.16.0:$PATH"
scripts/build-macos.sh
```

Kit tests:

```sh
cd steppe-kit
swift test
```

## Where to make changes

- Herdr protocol, store, and model changes: `steppe-kit/Sources/HerdrKit/`, then run
  `scripts/sync-herdrkit.sh` to update the compiled copy under
  `macos/Sources/Features/Steppe/HerdrKit/`.
- Sidebar/UI: `macos/Sources/Features/Steppe/`.
- Window layout: `macos/Sources/Features/Terminal/TerminalViewContainer.swift` and
  `TerminalController.windowDidLoad`.
- Menu/notification hooks: `macos/Sources/App/AppDelegate.swift`.
- Config: `src/config/Config.zig` and `macos/Sources/Ghostty/Ghostty.Config.swift`.

Avoid broad reformatting of upstream Ghostty files. Keeping the diff narrow makes rebases
manageable.

## Style

- Swift: `swiftlint lint --strict --fix` when available.
- Zig: `zig fmt .`.
- Docs/JSON: Prettier with the repository defaults.
- Prefer small, focused commits with imperative messages.

## Tests

Add protocol tests for new socket methods and event shapes. For UI changes, include a short
manual test note in the PR description: which Herdr session, which pane state, and what was
clicked.

## Upstream

Steppe tracks `ghostty-org/ghostty` on `main`. Rebase with:

```sh
git fetch upstream
git rebase upstream/main
```

Do not create GitHub issues or pull requests against upstream Ghostty for Steppe-specific
behavior. Upstream has its own AI disclosure policy; disclose AI assistance in Steppe commits
and PRs as well.

## Releasing

1. Update `CHANGELOG.md` and `MARKETING_VERSION` if needed.
2. Run `cd steppe-kit && swift test`.
3. Run `scripts/package-macos.sh`.
4. Sign and notarize with a Developer ID for public distribution.
5. Tag a release with a `vX.Y.Z` tag only if you understand Ghostty's tag-based build logic.
