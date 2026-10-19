# Steppe

**The open range for your agent herd.**

Steppe is an independent macOS terminal and cockpit for [Herdr](https://herdr.dev), built on
[Ghostty](https://ghostty.org). This repository is at milestone **M0**: a working Herdr socket
client and a SwiftUI prototype of the native cockpit. The Ghostty fork comes next.

> Steppe is not affiliated with, endorsed by, or supported by Ghostty or Herdr.

## What works today

- `HerdrKit`: newline-delimited JSON client for Herdr's local socket.
- Session discovery: `HERDR_SOCKET_PATH`, `HERDR_SESSION`, the default socket, and named sessions.
- `session.snapshot` decoding into typed models.
- Long-lived `events.subscribe` stream used as an invalidation signal, with authoritative refreshes.
- A SwiftUI sidebar prototype that lists workspaces, tabs, panes, and agents with live status.
- `herdr-probe`, a small CLI for verifying the client without the UI.

## Requirements

- macOS 14 or newer
- Swift 6 (Xcode 16+)
- A running Herdr server (`herdr status`)
- Herdr 0.9.x for the modern snapshot and event surface

## Run

```sh
swift build
swift run herdr-probe snapshot     # print the live session as text
swift run herdr-probe watch        # print events as they arrive
swift run steppe-spike             # open the cockpit prototype
swift test
```

If Herdr is not running, the app still opens and shows a disconnected state.

## Layout

```
Sources/
  HerdrKit/           Socket, protocol models, client, session discovery, store
  HerdrProbe/         CLI verification tool
  SteppeSpike/        SwiftUI cockpit prototype
Tests/
  HerdrKitTests/      Protocol and discovery tests
```

The eventual app will keep `HerdrKit` free of Ghostty dependencies and add a
`Features/Steppe/` module to the Ghostty macOS shell.

## Roadmap

- **M0 (now):** socket client, snapshot/event loop, sidebar prototype.
- **M1:** fork and pin Ghostty; add a collapsible native sidebar to a Herdr window.
- **M2:** focus/create/rename/split, command palette, native notifications, dock badge.
- **M3:** reconnect and `events_lost` recovery, performance, accessibility.
- **M4:** rebrand, sign/notarize, updater, first release.

## Product notes

- The terminal surface stays a normal PTY running `herdr attach`; Steppe adds native chrome
  around it rather than reimplementing Herdr's pane renderer.
- Later, Herdr's own sidebar can be hidden with:
  ```toml
  [ui]
  sidebar_start_collapsed = true
  sidebar_collapsed_mode = "hidden"
  window_title = ""
  ```
- Notifications should be native; Herdr's toast delivery defaults to `off`.

## Licenses

Steppe is MIT-licensed. Ghostty is MIT-licensed. Herdr is Apache-2.0. If Steppe vendors or
derives code from Herdr's schema or documentation, the Apache-2.0 NOTICE requirements apply.
