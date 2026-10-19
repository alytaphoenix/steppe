#!/usr/bin/env bash
#
# Build the Steppe macOS app. Requires Zig 0.16.0, Xcode 26+, and the Metal
# Toolchain. Override the Zig binary with ZIG=/path/to/zig.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
zig="${ZIG:-$HOME/.local/zig/zig-aarch64-macos-0.16.0/zig}"

if [[ ! -x "$zig" ]]; then
  echo "error: Zig not found at $zig" >&2
  echo "set ZIG=/path/to/zig-0.16.0 or install it under ~/.local/zig" >&2
  exit 1
fi

"$zig" version | grep -q '^0\.16\.' || {
  echo "error: Zig 0.16.x required, got $("$zig" version)" >&2
  exit 1
}

cd "$root"
"$zig" build -Demit-macos-app=false

cd macos
xcodebuild \
  -project Ghostty.xcodeproj \
  -scheme Ghostty \
  -configuration Debug \
  SYMROOT="$PWD/build" \
  build

echo
echo "Built: $root/macos/build/Debug/Ghostty.app"
