# M0 notes

Verified against Herdr 0.9.3, socket protocol 22, on macOS.

## What worked

- `session.snapshot` returns `result.snapshot` with `version`, `protocol`, `workspaces`,
  `tabs`, `panes`, `layouts`, `agents`, and the three focused ids.
- `agent.list` returns `result.agents` and is a useful secondary source when the snapshot's
  agent list is empty.
- `events.subscribe` acknowledges with `subscription_started`, then pushes event frames with
  `{"event": "...", "data": {...}}`. Event names are snake_case (`pane_focused`), not dotted.
- `workspace.focus`, `tab.focus`, `pane.focus`, and `agent.focus` all work with the public ids.
- Request/response connections can be short-lived; one connection per request is fine.

## Gotchas found

- **Separate queues are required.** A subscription blocks on a long-lived read. Running both
  subscriptions and requests on one serial queue starves snapshot refreshes and leaves the UI
  stuck on "connecting". `HerdrClient` uses a request queue and an event queue.
- **Custom agent reports are pane-local in 0.9.3.** `pane.report-agent` makes `pane.get` show
  the reported agent and state, but the agent does not appear in `session.snapshot.agents` or
  `agent.list` while the pane's foreground process is a shell. Test agent UI with a real agent
  in a pane, or trust the pane projection in `HerdrStore.agents`.
- **`agent.list` can lag the snapshot.** Merge both sources by `pane_id` and prefer the
  explicit list entry.
- **Status changes need a narrower subscription.** `pane.agent_status_changed` requires a
  `pane_id`, and one invalid entry rejects the whole subscription. The store polls every two
  seconds for now; M2 should subscribe per visible pane and rebuild the stream when panes
  change.
- **`ui.toast.delivery` defaults to `off`.** Native notifications will not double up with
  Herdr toasts.

## Next

1. Replace the 2s poll with per-pane `pane.agent_status_changed` subscriptions plus the
   existing snapshot invalidation loop.
2. Add `events_lost` recovery: finish the stream, resubscribe, and reconcile with a fresh
   snapshot.
3. Port the sidebar to a pinned Ghostty fork behind a `Steppe` feature flag.
