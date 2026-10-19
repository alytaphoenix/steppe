# Building

## Requirements

- macOS 14 or newer (the app targets macOS 13 for the terminal, but development uses a newer
  SDK)
- Xcode 26 or newer, with the Metal Toolchain
- Zig **0.16.0** for the pinned Ghostty commit
- Nushell is optional; `scripts/build-macos.sh` does not need it

Install the Metal Toolchain once:

```sh
xcodebuild -downloadComponent MetalToolchain
```

### Zig 0.16.0

Homebrew's `zig` may be newer than 0.16 and Ghostty's build checks the version. Install 0.16.0
under `~/.local/zig`:

```sh
mkdir -p ~/.local/zig
cd ~/.local/zig
curl -fLO https://ziglang.org/download/0.16.0/zig-aarch64-macos-0.16.0.tar.xz
tar -xJf zig-aarch64-macos-0.16.0.tar.xz
```

On an Intel Mac, use `zig-x86_64-macos-0.16.0.tar.xz` instead.

### Zig dependency fetching

Zig's HTTP client can time out reaching `deps.files.ghostty.org` over IPv6. If a clean build
fails with `unable to connect to server: ConnectionTimedOut`, pre-seed the dependency cache
with `curl -4` or try again on an IPv4-only network. The exact workaround used during M1 is in
[`docs/m1-notes.md`](m1-notes.md).

## Build

```sh
export PATH="$HOME/.local/zig/zig-aarch64-macos-0.16.0:$PATH"
scripts/build-macos.sh
```

This builds the Ghostty core/xcframework with Zig, then the macOS app with Xcode. The output is:

```
macos/build/Debug/Steppe.app
```

Build an optimized local release:

```sh
CONFIGURATION=ReleaseLocal scripts/build-macos.sh
```

## Package

```sh
scripts/package-macos.sh
```

Artifacts land in `build-artifacts/`:

- `Steppe-0.1.0.dmg`
- `Steppe-0.1.0-macos.zip`

The default package uses `ReleaseLocal`, which has `disable-library-validation` so the
ad-hoc-signed Sparkle framework can load. For a Developer ID build:

```sh
CONFIGURATION=Release \
SIGN_IDENTITY="Developer ID Application: Name (TEAM)" \
TEAM_ID="TEAM" \
NOTARY_PROFILE="steppe-notary" \
scripts/package-macos.sh
```

`NOTARY_PROFILE` is a `notarytool` keychain profile created with `xcrun notarytool
store-credentials`. If it is omitted, the artifacts are not notarized.

## Tests

```sh
cd steppe-kit
swift test
```

Protocol tests cover snapshot decoding, event decoding, subscription construction, session
discovery, and error envelopes.

## Rebase on upstream

```sh
git fetch upstream
git rebase upstream/main
```

Keep Steppe changes confined to:

- `macos/Sources/Features/Steppe/`
- the sidebar hook in `TerminalController.windowDidLoad`
- `TerminalViewContainer` layout
- the Steppe menu/notification hooks in `AppDelegate`
- `Ghostty.Config.swift` and `src/config/Config.zig` for `steppe-sidebar`
- `steppe-kit/` and docs/scripts

Do not tag the fork with a non-`vX.Y.Z` tag: Ghostty's build reads git tags and aborts on
unexpected formats. Use branch `steppe` for the fork marker.
