# Research notes — Omarchy Rollback Check + Guided Recovery

Original checker research: 2026-09-06. Guided Recovery audit: 2026-09-10.

## Problem source

Omarchy issue `#9828` documents the migration-ledger drift class: a root snapshot restore can rewind machine-side state while the per-user migration ledger under `$HOME/.local/state/omarchy/migrations` survives on a separate Btrfs home subvolume.

`omrollback-check` is intentionally conservative. It never assumes every machine marker mentioned by a migration is a permanent completion invariant, because current Omarchy includes conditional and temporary machine markers.

## Direct machine-completion invariants

`CONFIRMED` remains limited to these exact audited migration script revisions:

| Migration | Git blob | Machine marker |
| --- | --- | --- |
| `1786380259.sh` | `ebe9af2c31c58ce91d4cfb01b647225f1c34b6f3` | `/var/lib/omarchy/migrations/1786380259` |
| `1787815267.sh` | `b3f9282a9664e9fb195e74ad99e2efa3665e0f44` | `/var/lib/omarchy/migrations/1787815267` |
| `1788025225.sh` | `295b71ba916003ac965bf3cc13f84af9f8c5f472` | `/var/lib/omarchy/migrations/1788025225` |

The checker hashes the installed script with `git hash-object --no-filters` while disabling global/system Git configuration. If an audited script changes, direct proof is disabled rather than extended to new control flow.

## Why Guided Recovery is a companion, not automatic repair

Automatic replay remains unsafe. Omarchy migrations can perform package transactions, mix root/home effects, be hardware/state conditional, and fail-fast. A `POTENTIAL` timeline mismatch is evidence, not proof.

For that reason `omrollback-plan` is a separate advisory layer instead of changing the proof logic in `omrollback-check`. It consumes the checker's existing output and optionally correlates it with `omcontext diff --json` schema v1.

The planner deliberately does not restore snapshots, replay migrations or delete markers, change packages, overwrite configuration, restart/disable services, use `sudo`, or infer causality from Context Snapshot changes.

It only builds an inspect → prepare → verify sequence and marks all automatic repair actions as blocked in both human and JSON output.

## Context Snapshot contract

Guided Recovery accepts only Omarchy Context Snapshot delta schema `1`. It uses bounded fields already sanitized/normalized by `omcontext`: package changes, added numeric migration markers, changed selected config fingerprints, newly failed services, Omarchy metadata changes, collection completeness, and privacy-scan status.

A newer/unknown schema is reported unavailable rather than parsed heuristically.

## Upstream maintenance audit — 2026-09-10

Current `omacom/omarchy:quattro` at audit time: `8ea51516390320f8e768808b230098e67bdaa82c`.

Since the previous PR-stack audit head `5ead870507dfb68db696b3ddb948cc3d178e8d62`, upstream changed only Hermes desktop installer/font/test paths. No migration files or rollback/migration-ledger paths changed in those three commits, so the previously re-audited invariant set remains current.

Omarchy itself ships Python-based utilities, so Python 3 is an existing platform dependency rather than a new runtime foreign to the distribution. Guided Recovery still keeps Context Snapshot optional.

## Definition of Done — Guided Recovery 1.0

The enhancement is complete when:

1. the existing checker proof/heuristic behavior is unchanged;
2. recovery planning is a separate read-only command;
3. `CONFIRMED`, `POTENTIAL`, `INCOMPLETE`, and clean evidence produce distinct bounded advice;
4. Context Snapshot schema-v1 deltas can be correlated without treating correlation as causation;
5. JSON plan schema v1 exposes the same safety boundary to future tooling;
6. automatic machine-changing actions are explicitly blocked;
7. root invocation is refused;
8. tests prove the planner never invokes privileged/snapshot mutation commands;
9. no network, telemetry, daemon, GUI, or AI/model call is introduced.
