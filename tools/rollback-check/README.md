# Omarchy Rollback Check — v1.0.0

`omrollback-check` is a small, read-only diagnostic for a specific Omarchy 4 / Quattro failure class: a root snapshot restore can rewind the system while the user's migration ledger under `$HOME` survives.

That split can leave Omarchy believing a migration already ran even when some machine-side effect was rolled back.

The tool **does not repair anything**. It reports only evidence it can safely classify and leaves recovery decisions to the user or maintainer.

## Usage

```bash
omrollback-check
omrollback-check version
```

Run it as the normal Omarchy user, not as root.

## Result classes

- **CONFIRMED** — a direct migration-state inconsistency was proven using an audited machine-completion invariant from the installed Omarchy migration revision.
- **POTENTIAL** — the surviving user migration timeline is newer than the restored migration tree while root and home are separate Btrfs rollback units.
- **No evidence detected** — the checker found neither of the above. This does not prove a rollback never happened; it means the safe checks found nothing they can prove or bound.
- **INCOMPLETE** — required Omarchy migration data is unavailable, so the check cannot finish reliably.

Exit codes:

```text
0  no rollback-related inconsistency evidence detected
1  confirmed inconsistency or potential rollback drift detected
2  incomplete check, invalid invocation, or missing required dependency
```

## Safety model

`omrollback-check`:

- never changes snapshots;
- never deletes or edits migration markers;
- never runs `omarchy-migrate`;
- never replays migrations;
- never changes packages, system files, or user configuration;
- never uses `sudo`;
- never sources or executes migration scripts;
- performs no network access and sends no telemetry.

Migration scripts are treated as files to hash/list only. Direct `CONFIRMED` findings are limited to exact upstream script revisions whose machine-completion marker semantics were reviewed for v1. If one of those scripts changes upstream, the direct proof is disabled rather than guessing about the new control flow.

## Why the checker is conservative

Not every `/var/lib/omarchy/migrations/...` marker in an Omarchy migration means "this migration must always have written this marker." Some are conditional; some are temporary. A broad text scan would therefore create false alarms on healthy systems.

v1 intentionally avoids that trap. It uses only audited direct invariants plus a separate, explicitly `POTENTIAL` timeline check.

## Install

From the repository root:

```bash
bash tools/rollback-check/install.sh
```

The installer places `omrollback-check` in `~/.local/bin`.

Dependencies: Bash, `git`, `findmnt`, and standard GNU/Linux userland already expected on Omarchy.

## Scope boundary

v1 is finished when it can safely report the documented evidence without modifying the machine. It is **not** a rollback manager, migration repair utility, snapshot browser, daemon, GUI, AI assistant, or automatic recovery system.

See [`RESEARCH.md`](RESEARCH.md) for the source analysis and false-positive constraints behind the design.
