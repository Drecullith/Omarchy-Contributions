# Changelog

## Guided Recovery 1.0.0 — 2026-09-10

- Added `omrollback-plan`, a read-only guided recovery companion to `omrollback-check`.
- Added optional correlation with Omarchy Context Snapshot schema-v1 delta JSON.
- Added stable plan schema v1 for deterministic tools and future local-assistant consumers.
- Added distinct recovery sequences for `CONFIRMED`, `POTENTIAL`, `INCOMPLETE`, and clean rollback evidence.
- Explicitly blocks automatic snapshot restore, migration replay/marker deletion, package changes, config overwrite, and service mutation.
- Added isolated tests for classification, Context Snapshot parsing, JSON output, mutation guards, root refusal, and unsupported schemas.

## Rollback Check 1.0.0 — 2026-09-06

- Added read-only root/home rollback-drift diagnostics for Omarchy 4 / Quattro.
- Added exact-revision auditing for direct machine-completion invariants.
- Added conservative timeline drift detection for split Btrfs root/home layouts.
- Added root refusal, dependency checks, explicit result classes, and stable exit codes.
- Added isolated regression tests covering false positives, changed upstream migration revisions, conditional/temporary machine markers, non-Btrfs layouts, and non-execution of migration scripts.
