# Steppe agent guide

Steppe is a Ghostty fork with a native Herdr cockpit. Keep changes narrow so upstream rebases
stay manageable.

## Commands

- Build the macOS app: `scripts/build-macos.sh`
- Build an optimized local release: `CONFIGURATION=ReleaseLocal scripts/build-macos.sh`
- Package: `scripts/package-macos.sh`
- Test the Herdr client: `cd steppe-kit && swift test`
- Sync the compiled client copy: `scripts/sync-herdrkit.sh`
- Format Swift: `swiftlint lint --strict --fix` (if installed)
- Format Zig: `zig fmt .`

The app build requires Zig 0.16.0 and the Metal Toolchain. See
[docs/building.md](docs/building.md).

## Layout

- `macos/Sources/Features/Steppe/` — sidebar, service, notifications, compiled HerdrKit copy.
- `steppe-kit/` — standalone HerdrKit, CLI probe, M0 spike, tests.
- `macos/Sources/Features/Terminal/` — Ghostty window/container integration.
- `macos/Sources/App/` — menu and notification hooks.
- `src/config/Config.zig` + `Ghostty.Config.swift` — the `steppe-sidebar` key.

## Rules

- Do not modify Ghostty's terminal core unless the integration requires it.
- Edit `steppe-kit/Sources/HerdrKit/`, not the compiled copy, then run
  `scripts/sync-herdrkit.sh`.
- Do not create git tags other than `vX.Y.Z`: Ghostty's build aborts on unexpected tags.
- Do not create upstream Ghostty issues or PRs for Steppe behavior.
- Add tests for protocol/event changes.
- Disclose AI assistance in commits and PRs.

## Docs

- [Architecture](docs/architecture.md)
- [Building](docs/building.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Contributing](CONTRIBUTING.md)
