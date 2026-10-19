# Steppe

**The open range for your agent herd.**

Steppe is a macOS terminal for [Herdr](https://herdr.dev), built as a fork of
[Ghostty](https://ghostty.org). The terminal is still Ghostty — PTYs, Metal rendering, tabs,
splits, keybindings, and configuration. Herdr still owns the workspaces, panes, and agent
state. Steppe adds a native sidebar and notifications so you can see which agent needs you
without reading the TUI chrome.

> Steppe is an independent project. It is not affiliated with, endorsed by, or supported by
> Ghostty or Herdr. Ghostty is MIT-licensed; Herdr is Apache-2.0. See [NOTICE](NOTICE).

## Features

- Native sidebar with workspaces, tabs, panes, agents, live status, and worktree names.
- Click an agent or workspace to focus it through Herdr.
- Per-pane `pane.agent_status_changed` subscriptions with authoritative snapshot refresh.
- Native notifications and a dock badge for blocked/done agents; click to focus the pane.
- New workspace, new tab, split right/down, and “focus next attention” actions.
- “Open Herdr in New Tab” from the Steppe menu or sidebar.
- Named-session picker that switches the Herdr store without restarting.
- `steppe-sidebar` Ghostty config key and a persisted sidebar toggle.
- Reconnect with backoff, `events_lost` recovery, and wake/activate refresh.
- The terminal surface remains a normal PTY running `herdr attach`.

## Install

Download the latest DMG or ZIP from the repository's Releases page. The local package is
ad-hoc signed; for a fully notarized build, see [docs/building.md](docs/building.md).

Build from source:

```sh
export PATH="$HOME/.local/zig/zig-aarch64-macos-0.16.0:$PATH"
scripts/build-macos.sh
open macos/build/Debug/Steppe.app
```

Requirements: Xcode 26+, the Metal Toolchain, and Zig 0.16.0. Full instructions, including
the dependency-fetch workaround, are in [docs/building.md](docs/building.md).

## Quick start

Start Herdr inside a Steppe tab:

```sh
herdr attach
```

The sidebar discovers `~/.config/herdr/herdr.sock`, or `HERDR_SOCKET_PATH` /
`HERDR_SESSION` when set. Use the session menu in the sidebar header to switch named sessions.

Herdr's own sidebar is still drawn inside the TUI. To use only Steppe's sidebar:

```toml
[ui]
sidebar_start_collapsed = true
sidebar_collapsed_mode = "hidden"
```

Steppe-specific Ghostty config:

```toml
# Show the native sidebar for new windows (default true).
steppe-sidebar = true
```

## Keyboard

| Shortcut | Action |
| --- | --- |
| `ctrl+shift+s` | Show/hide the Steppe sidebar |
| `ctrl+shift+r` | Refresh the Herdr snapshot |
| `ctrl+shift+a` | Focus the next attention-needing agent |
| `ctrl+shift+h` | Open Herdr in a new tab |

## Documentation

- [Architecture](docs/architecture.md) — modules, subscription model, failure handling.
- [Building](docs/building.md) — toolchain, build, package, signing, rebase.
- [Troubleshooting](docs/troubleshooting.md) — socket, double sidebar, notifications, builds.
- [M1 notes](docs/m1-notes.md) — environment findings from the initial integration.
- [Contributing](CONTRIBUTING.md).
- [Changelog](CHANGELOG.md).

## Status and limitations

Steppe is at **0.1.0**. The sidebar, notifications, session picker, and Herdr actions are
implemented and locally tested against Herdr 0.9.3.

Known limits:

- The packaged app is ad-hoc signed unless you provide a Developer ID. macOS may refuse
  notification authorization for an ad-hoc build launched from a build directory.
- Steppe still reads Ghostty's config at `~/.config/ghostty/config` for compatibility.
- The sidebar is fixed-width (264 pt) and has no dedicated settings pane yet.
- Steppe does not mirror Herdr workspaces into Ghostty tabs; one terminal surface per window
  keeps one layout authority.
- A non-`vX.Y.Z` git tag makes Ghostty's build abort; use branch `steppe` as the fork marker.

## Layout

```
macos/Sources/Features/Steppe/
  SteppeSidebar.swift       native SwiftUI sidebar
  SteppeService.swift       shared store, sessions, dock badge
  SteppeNotifications.swift native notifications
  HerdrKit/                 compiled Herdr client (synced copy)
macos/Sources/Features/Terminal/
  TerminalController.swift  creates the sidebar beside the surface
  TerminalViewContainer.swift
steppe-kit/
  Sources/HerdrKit/         standalone client kit
  Sources/SteppeSpike/      M0 SwiftUI cockpit
  Sources/HerdrProbe/       CLI verification tool
  Tests/
scripts/
  build-macos.sh
  package-macos.sh
  sync-herdrkit.sh
```

## Upstream

Pinned to Ghostty `765ea37` (upstream `main` at the start of the integration), with Steppe
changes on branch `steppe`:

```sh
git fetch upstream
git rebase upstream/main
```

Keep the diff confined to the Steppe feature directory, the window/container hook, the menu
and notification hooks, the config key, and `steppe-kit/`.

## License

Steppe is MIT-licensed. See [LICENSE](LICENSE) and [NOTICE](NOTICE). Upstream Ghostty is
MIT-licensed; Herdr is Apache-2.0. Protocol models in `HerdrKit` are derived from Herdr's
published schema and documentation.
