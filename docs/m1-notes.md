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

## M2/M3 update

- Per-pane `pane.agent_status_changed` subscriptions are live; the store rebuilds the
  subscription set whenever the pane list changes and treats events as invalidation signals.
- `events_lost` reconnects immediately and reconciles with a fresh snapshot.
- Native notifications and the dock badge are wired through `SteppeNotifications`.
- Named-session switching recreates the store without restarting the app.
- Steppe actions create workspaces/tabs and split panes through the socket API.
- The app is rebranded as **Steppe** (`dev.steppe.app`, `Steppe.app`, `Steppe.icns`).
- The `steppe-sidebar` config key gates the sidebar for new windows.
- Local packaging produces `build-artifacts/Steppe-0.1.0.dmg` and
  `build-artifacts/Steppe-0.1.0-macos.zip`.

Known environment limits:

- `UNUserNotificationCenter` refused authorization for the ad-hoc debug bundle
  (`Notifications are not allowed for this application`). Notifications should be tested from
  a signed Release build installed in `/Applications`.
- The release package uses `ReleaseLocal` because the hardened `Release` configuration rejects
  the ad-hoc-signed Sparkle framework without `disable-library-validation`.

## Next

1. Sign and notarize a Developer ID release, then verify notifications end to end.
2. Add configurable, resizable sidebar widths and a compact collapsed rail.
3. Replace the full snapshot poll with layout-diff updates for large sessions.
4. Add a `Steppe` settings page for socket/session, notifications, and sidebar behavior.
