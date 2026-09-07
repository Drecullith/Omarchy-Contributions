# Changelog

## 1.0.0 — 2026-09-07

Initial release.

- Add a read-only Quattro audit for known legacy Hyprland core `.conf` files.
- Classify configuration-bearing remnants as `POSSIBLY_IGNORED` without claiming automatic proof of lost user settings.
- Keep blank/comment-only remnants informational as `LEGACY`.
- Recognize the legacy-provider shape when no `hyprland.lua` entry point exists.
- Exclude current standalone configs such as `hyprsunset.conf` and `xdph.conf`.
- Provide manual Lua review targets without converting or deleting anything.
- Add isolated regression tests, installer coverage, research notes, and CI integration.
