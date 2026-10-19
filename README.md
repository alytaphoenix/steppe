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

Milestone **local release**: the native sidebar, notifications, session picker, and
Herdr actions are integrated into the rebranded Steppe macOS app.
- Native sidebar with workspaces, tabs, panes, agents, and live status.
- Click an agent or workspace to focus it through Herdr.
- Per-pane `pane.agent_status_changed` subscriptions, with authoritative snapshot refreshes.
- Native notifications and a dock badge for agents that need attention; click a notification to
  focus its pane.
- Create workspaces/tabs, split panes, and jump to the next attention-needing agent from the
  sidebar or the Steppe menu.
- `ctrl+shift+s` shows/hides the sidebar; `ctrl+shift+r` refreshes it; `ctrl+shift+a` focuses
  the next attention-needing agent.
- Session picker for named Herdr sessions.
- `steppe-sidebar` config key (default `true`) gates the sidebar for new windows.
- The standalone client kit and M0 spike live in [`steppe-kit/`](steppe-kit/).

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

open build/Debug/Steppe.app
```

If Nushell is installed, `macos/build.nu` wraps the Xcode step. Upstream's full build
instructions remain in [HACKING.md](HACKING.md).

Package a release build (zip and DMG) with:

```sh
scripts/package-macos.sh
```

The packaged build uses the optimized `ReleaseLocal` configuration with ad-hoc signing and
`disable-library-validation`, which lets the bundled Sparkle framework load without a Developer
ID. For a Developer ID build, set `CONFIGURATION=Release` plus `SIGN_IDENTITY`, `TEAM_ID`, and
optionally `NOTARY_PROFILE`. Without them the app is suitable only for local use.

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

Steppe-specific Ghostty config:

```toml
# Show the native sidebar for new windows (default true; toggle from the Steppe menu).
steppe-sidebar = true
```

Steppe posts native notifications on blocked/done transitions and updates the dock badge.
Herdr's `ui.toast.delivery` defaults to `"off"`, so there is no double notification.

Steppe still reads Ghostty's configuration at `~/.config/ghostty/config`, so existing
settings carry over. The bundle identifier is `dev.steppe.app` (Debug:
`dev.steppe.app.debug`). Notifications need the app to be signed and allowed in System
Settings; an ad-hoc local build may be denied by macOS.

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
