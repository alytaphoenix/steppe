# Troubleshooting

## The sidebar says disconnected

Check that Herdr is running:

```sh
herdr status
```

Steppe resolves the socket in this order:

1. `HERDR_SOCKET_PATH`
2. `HERDR_SESSION` → `~/.config/herdr/sessions/<name>/herdr.sock`
3. `~/.config/herdr/herdr.sock`

Use the session picker in the sidebar header to switch named sessions. If the socket exists but
the server is stopped, the sidebar keeps retrying with backoff.

## Two sidebars

Herdr's TUI sidebar is independent of Steppe's native sidebar. Hide the TUI sidebar:

```toml
[ui]
sidebar_start_collapsed = true
sidebar_collapsed_mode = "hidden"
```

Then toggle Steppe's sidebar with `ctrl+shift+s` or the Steppe menu.

## “Open Herdr” opens a shell error

Steppe runs `herdr attach` in a new tab. Make sure `herdr` is on the shell's `PATH`. For a named
session, Steppe runs `herdr --session <name> attach`.

## Notifications are denied

macOS may refuse notification authorization for an ad-hoc-signed app launched from a build
directory. The app logs:

```
notification authorization failed: Notifications are not allowed for this application
```

Use a signed app installed in `/Applications`, then enable notifications in System Settings →
Notifications → Steppe. The dock badge works independently of notification permission.

## The packaged Release app will not launch

The hardened `Release` configuration rejects the ad-hoc-signed Sparkle framework:

```
Library not loaded: @rpath/Sparkle.framework/Versions/B/Sparkle
different Team IDs
```

Use `ReleaseLocal` for local packages (the default in `scripts/package-macos.sh`), or sign with
a Developer ID and notarize.

## Build aborts with “tagged releases must be in vX.Y.Z format”

Ghostty's build reads git tags. Remove or rename any non-`vX.Y.Z` tag:

```sh
git tag -d <tag>
```

## Zig cannot fetch dependencies

```
unable to connect to server: ConnectionTimedOut
```

Zig's client may prefer an unreachable IPv6 route. Retry, use an IPv4 network, or pre-seed
`~/.cache/zig/p` and `zig-pkg/` with `curl -4`. See [building](building.md).

## No window appears when launched over SSH

Steppe, like Ghostty, needs an active GUI session to create and activate a window. Launch it
from the logged-in desktop session or with `open` while the display is awake.
