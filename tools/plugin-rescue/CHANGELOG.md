# Changelog

## 1.0.1 — 2026-09-10

- Serialize rescue/restore state mutation with a non-blocking `flock`.
- Abort rescue if `shell.json` changes after the snapshot but before the safe configuration is installed.
- Add regression coverage for concurrent-operation locking.
- Document the new safety behavior and `flock` dependency.

## 1.0.0 — 2026-09-06

- Initial release.
- TTY-safe third-party shell-plugin rescue without requiring Quickshell IPC.
- Exact `shell.json` snapshot and restore.
- First-party clone restoration when trusted `omarchy.clonedFrom` metadata is available.
- Stale third-party config-reference cleanup even when plugin files are absent or malformed.
- Restore conflict detection with explicit `--force` escape hatch.
- Best-effort Omarchy shell restart with readiness retry.
- Isolated regression test suite.
