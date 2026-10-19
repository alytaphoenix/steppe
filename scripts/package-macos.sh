#!/usr/bin/env bash
#
# Build a distributable Steppe zip and DMG.
#
# Local/ad-hoc:
#   scripts/package-macos.sh
#
# Developer ID + notarization:
#   SIGN_IDENTITY="Developer ID Application: Name (TEAM)" \
#   TEAM_ID="TEAM" \
#   NOTARY_PROFILE="steppe-notary" \
#   scripts/package-macos.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
version="${VERSION:-0.1.0}"
configuration="${CONFIGURATION:-ReleaseLocal}"
out="$root/build-artifacts"
app="$root/macos/build/$configuration/Steppe.app"

if [[ -n "${SIGN_IDENTITY:-}" && -z "${CONFIGURATION:-}" ]]; then
  configuration=Release
  app="$root/macos/build/$configuration/Steppe.app"
fi

CONFIGURATION="$configuration" "$root/scripts/build-macos.sh"

if [[ ! -d "$app" ]]; then
  echo "error: expected app at $app" >&2
  exit 1
fi

mkdir -p "$out"
rm -f "$out/Steppe-$version-macos.zip" "$out/Steppe-$version.dmg"

# Preserve resource forks and extended attributes for a runnable app bundle.
ditto -c -k --norsrc --keepParent "$app" "$out/Steppe-$version-macos.zip"

if command -v hdiutil >/dev/null 2>&1; then
  hdiutil create \
    -volname "Steppe" \
    -srcfolder "$app" \
    -ov -format UDZO \
    "$out/Steppe-$version.dmg" >/dev/null
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  for artifact in "$out/Steppe-$version.dmg" "$out/Steppe-$version-macos.zip"; do
    [[ -e "$artifact" ]] || continue
    xcrun notarytool submit "$artifact" \
      --keychain-profile "$NOTARY_PROFILE" \
      --wait
    xcrun stapler staple "$artifact" || true
  done
fi

echo
echo "Artifacts:"
ls -lh "$out"/Steppe-"$version"* 2>/dev/null || true
