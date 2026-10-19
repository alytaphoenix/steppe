# Upstream Ghostty workflows

These are the workflows from the upstream Ghostty checkout. They are kept for reference but
are inactive: GitHub Actions only reads workflows from `.github/workflows/`.

Steppe's active CI is [`.github/workflows/steppe.yml`](../workflows/steppe.yml), which runs the
HerdrKit tests. The macOS app build is intentionally manual because it requires Zig 0.16.0, a
specific Xcode, and the Metal Toolchain.
