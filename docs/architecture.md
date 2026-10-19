# Architecture

Steppe is a thin native layer over two systems that already do the hard parts:

- **Ghostty** owns the terminal: PTYs, parsing, Metal rendering, windows, tabs, splits, and
  configuration.
- **Herdr** owns agent runtime state: workspaces, tabs, panes, agents, and their lifecycle.

Steppe adds a native cockpit that reads Herdr's local JSON socket and renders it beside a
normal Ghostty terminal surface.

```
┌─────────────────────────────┐
│ Herdr daemon                │
│ workspaces / tabs / panes   │
│ agents / status / events    │
└──────────────┬──────────────┘
               │ newline-delimited JSON
               │ ~/.config/herdr/herdr.sock
┌──────────────▼──────────────┐
│ HerdrKit                    │
│  HerdrClient  request queue │
│  event stream event queue   │
│  HerdrStore   @MainActor    │
└──────────────┬──────────────┘
               │ snapshot + invalidation events
┌──────────────▼──────────────┐
│ SteppeService               │
│  one store per session      │
│  notifications / dock badge │
└──────────────┬──────────────┘
               │ SwiftUI
┌──────────────▼──────────────┐
│ Steppe sidebar              │
│  agents, workspaces, actions│
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│ Ghostty macOS shell         │
│  TerminalController         │
│  TerminalViewContainer      │
│   ├─ sidebar (264 pt)       │
│   └─ terminal surface       │
└─────────────────────────────┘
```

## Modules

### `steppe-kit/Sources/HerdrKit`

The standalone protocol client. It has no Ghostty dependency and is testable with `swift test`.

- `HerdrSocket` — buffered Unix-domain socket, newline framing, read timeout for requests,
  max frame size, `SO_NOSIGPIPE`.
- `HerdrClient` — one request connection per call and one long-lived event connection.
  Requests and subscriptions use **separate serial queues**: a subscription blocks on a
  long-lived read, and sharing a queue with requests would starve snapshot refreshes.
- `HerdrStore` — `@MainActor` state. Bootstraps from `session.snapshot`, treats events as
  invalidation signals, refreshes authoritatively, and publishes workspaces, agents, status
  changes, and connection state.
- `HerdrSession` — socket discovery (`HERDR_SOCKET_PATH`, `HERDR_SESSION`, default, named
  sessions).

### `macos/Sources/Features/Steppe`

The app integration:

- `SteppeService` — one shared store, session switching, dock badge, config reload handling,
  wake/activate refresh.
- `SteppeSidebar` — SwiftUI sidebar and row views.
- `SteppeNotifications` — native notifications on blocked/done transitions.
- `HerdrKit/` — a compiled copy of the kit. The Xcode project uses a synchronized `Sources`
  group, so the copy makes the fork standalone. `scripts/sync-herdrkit.sh` keeps it in sync.

### Ghostty integration points

- `TerminalController.windowDidLoad` creates the sidebar and adds it to the window container.
- `TerminalViewContainer` lays out the sidebar and terminal, and keeps `window.contentView`
  as the terminal container so Ghostty's glass-effect lookup keeps working.
- `AppDelegate` adds the Steppe menu and routes notification clicks.

## Subscription model

On connect the store subscribes to:

- lifecycle events (`workspace.*`, `tab.*`, `pane.*`, `layout.updated`, `worktree.*`);
- one `pane.agent_status_changed` subscription per live pane.

Herdr rejects the whole subscription request if any per-pane entry references a pane that no
longer exists, so the store rebuilds the subscription list whenever the pane set changes. A
two-second poll remains as a safety net for state that does not emit an event.

Events are hints, not state. Every event schedules an authoritative `session.snapshot` read.
`events_lost` triggers an immediate reconnect and snapshot reconciliation.

## Failure handling

- Request reads time out after 15 seconds.
- Event streams reconnect with exponential backoff (500 ms → 10 s).
- Frames larger than 16 MiB are rejected.
- A missing Herdr server leaves the app running in a disconnected state; it keeps retrying.
- Session switching stops the old store before starting the new one.

## Deliberate non-goals

- Steppe does not paint Herdr panes itself. The terminal PTY runs `herdr attach`, and Herdr
  draws the TUI. This keeps Ghostty's emulator and config behavior intact.
- Steppe does not turn Herdr workspaces into Ghostty tabs. One surface per window avoids two
  sources of layout truth.
