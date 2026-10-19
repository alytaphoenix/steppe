#!/usr/bin/env bash
#
# The macOS app target uses a synchronized Sources group, so it compiles a
# checked-in copy of HerdrKit. The source of truth is the standalone kit.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
src="$root/steppe-kit/Sources/HerdrKit"
dst="$root/macos/Sources/Features/Steppe/HerdrKit"

mkdir -p "$dst"
find "$dst" -maxdepth 1 -name '*.swift' -delete
cp "$src"/*.swift "$dst"/

echo "Synced HerdrKit:"
echo "  $src -> $dst"
