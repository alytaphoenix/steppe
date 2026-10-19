# M1 notes

The Ghostty fork is pinned to `765ea37` (upstream `main` at the start of M1). Steppe changes
are on branch `steppe`.

## Integration points

- `macos/Sources/Features/Steppe/SteppeSidebar.swift` — SwiftUI sidebar.
- `macos/Sources/Features/Steppe/SteppeService.swift` — one `HerdrStore` for the app.
- `macos/Sources/Features/Terminal/TerminalController.swift` — creates the sidebar beside the
  terminal surface in `windowDidLoad`.
- `macos/Sources/Features/Terminal/TerminalViewContainer.swift` — lays out the 264 pt sidebar
  and keeps `window.contentView` as the terminal container so Ghostty's glass-effect lookup
  continues to work.
- `macos/Sources/App/AppDelegate.swift` — adds the `Steppe` menu and the toggle/refresh actions.
- `macos/Sources/Features/Steppe/HerdrKit/` — a compiled copy of `steppe-kit/Sources/HerdrKit`.

The Xcode project uses a `PBXFileSystemSynchronizedRootGroup` for `macos/Sources`, so new files
under `Features/Steppe` join the target automatically. No project-file edits were needed.

## Build environment

- Ghostty `main` requires Zig **0.16.0**. Zig 0.15.2 cannot link against the macOS 27 SDK on
  this machine (`undefined symbol: _dispatch_time`, `_malloc_size`, …), so the fork uses main
  with 0.16.0 instead of the v1.3.1 tag.
- Xcode 27 requires the separately downloaded Metal Toolchain:
  `xcodebuild -downloadComponent MetalToolchain`.
- `xcodebuild` prints a CoreSimulator version warning and a `DVTCoreDeviceCore` plug-in error.
  They are non-fatal for the macOS target; the build reports `** BUILD SUCCEEDED **`.
- Zig's HTTP client timed out reaching `deps.files.ghostty.org` (IPv6 path). Dependencies were
  pre-seeded with `curl -4` into `~/.cache/zig/p` and `zig-pkg/`. If a clean checkout fails to
  fetch, use the same workaround or force Zig onto IPv4.

## Current behavior

- Sidebar is created for every terminal window.
- `ctrl+shift+s` toggles it; `ctrl+shift+r` refreshes the snapshot.
- Clicking a workspace or agent calls `workspace.focus` / `agent.focus`; the Herdr TUI remains
  the thing that draws panes.
- Herdr's own sidebar is still visible inside the TUI. Set
  `ui.sidebar_start_collapsed = true` and `ui.sidebar_collapsed_mode = "hidden"` in
  `~/.config/herdr/config.toml` for a single-sidebar setup.

## Next

1. Gate the sidebar on a config key and add a dedicated Herdr window mode.
2. Native notifications and dock badge from `pane.agent_status_changed`.
3. Per-pane status subscriptions instead of the two-second poll.
4. `events_lost` recovery and multi-session support.
5. Rebrand the app bundle (currently still `com.mitchellh.ghostty`).
