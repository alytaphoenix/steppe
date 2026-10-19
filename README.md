# Steppe

**The open range for your agent herd.**

Steppe is a fork of [Ghostty](https://ghostty.org) with a native macOS cockpit for
[Herdr](https://herdr.dev). The terminal remains Ghostty — local PTYs, Metal rendering,
tabs, splits, configuration, and existing behavior. The Steppe layer adds a native sidebar
that mirrors a running Herdr daemon over its local socket. Herdr still owns workspaces,
panes, and agent state; clicking a row focuses the corresponding Herdr pane while the TUI
inside the surface keeps drawing it.

> Steppe is independent and is not affiliated with, endorsed by, or supported by Ghostty
> or Herdr. Ghostty is MIT-licensed; Herdr is Apache-2.0. See [NOTICE](NOTICE).

## Status

Milestone **M1**: the sidebar is integrated into the Ghostty macOS app.

- Native sidebar with workspaces, tabs, panes, agents, and live status.
- Click an agent or workspace to focus it through Herdr.
- `ctrl+shift+s` shows/hides the sidebar; `ctrl+shift+r` refreshes it.
- Connection state, reconnect with backoff, and a two-second safety poll.
- The standalone client kit and M0 spike live in [`steppe-kit/`](steppe-kit/).

Not yet: native notifications, dock badge, per-pane status subscriptions, and a
config-gated Herdr-only window mode.

## Layout

```
macos/Sources/Features/Steppe/
  SteppeSidebar.swift       native SwiftUI sidebar
  SteppeService.swift       single socket-backed store
  HerdrKit/                 Herdr protocol client (synced copy)
macos/Sources/Features/Terminal/
  TerminalController.swift  creates the sidebar beside the surface
  TerminalViewContainer.swift
steppe-kit/
  Sources/HerdrKit/         standalone client kit
  Sources/SteppeSpike/      M0 SwiftUI cockpit
  Sources/HerdrProbe/       CLI verification tool
  Tests/
```

`HerdrKit` is copied into the app target because the Xcode project uses a synchronized
`Sources` group. Edit the kit and run `scripts/sync-herdrkit.sh`; the copy makes the fork
standalone.

## Build

Requirements:

- macOS with Xcode 26+ and the Metal Toolchain
  (`xcodebuild -downloadComponent MetalToolchain`)
- Zig **0.16.0** (the pinned Ghostty commit requires it)

```sh
export PATH="$HOME/.local/zig/zig-aarch64-macos-0.16.0:$PATH"

# Build the Ghostty core and xcframework
zig build -Demit-macos-app=false

# Build the macOS app
cd macos
xcodebuild -project Ghostty.xcodeproj -scheme Ghostty \
  -configuration Debug SYMROOT="$PWD/build" build

open build/Debug/Ghostty.app
```

If Nushell is installed, `macos/build.nu` wraps the Xcode step. Upstream's full build
instructions remain in [HACKING.md](HACKING.md).

## Run with Herdr

Start a Herdr session in a tab:

```sh
herdr attach
```

The sidebar discovers `~/.config/herdr/herdr.sock`, or `HERDR_SOCKET_PATH` /
`HERDR_SESSION` when set. If Herdr is not running, the sidebar shows a disconnected state
and keeps retrying.

Herdr's own sidebar is still drawn inside the TUI. To avoid two sidebars:

```toml
[ui]
sidebar_start_collapsed = true
sidebar_collapsed_mode = "hidden"
```

Native notifications are not wired yet; Herdr's `ui.toast.delivery` defaults to `"off"`.

## Upstream

Pinned to Ghostty `765ea37` (main at the M1 start), with Steppe changes on branch
`steppe`. Fetch upstream and rebase:

```sh
git remote add upstream https://github.com/ghostty-org/ghostty  # once
git fetch upstream
git rebase upstream/main
```

Keep Steppe changes confined to `macos/Sources/Features/Steppe/`, the menu setup in
`AppDelegate.swift`, and the container hook in `TerminalController.swift` /
`TerminalViewContainer.swift`.

## License

Steppe is MIT-licensed. See [LICENSE](LICENSE) and [NOTICE](NOTICE). Upstream Ghostty is
MIT-licensed; Herdr is Apache-2.0. Protocol models in `HerdrKit` are derived from Herdr's
published schema and documentation.
