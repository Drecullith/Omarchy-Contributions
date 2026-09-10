# Omarchy Rollback Check + Guided Recovery

This contribution now ships two read-only commands:

- `omrollback-check` v1.0.0 — conservative detection of root/home migration-ledger drift after an Omarchy root snapshot restore.
- `omrollback-plan` v1.0.0 — a guided recovery planner that combines Rollback Check evidence with an optional Omarchy Context Snapshot delta.

The checker remains the proof/heuristic boundary. The planner does **not** broaden that evidence and does **not** execute repairs.

## Usage

Run the diagnostic:

```bash
omrollback-check
```

Generate a human recovery plan:

```bash
omrollback-plan
```

If `omcontext` is installed and has a baseline/latest delta, the planner consumes `omcontext diff --json` automatically. You can also provide an explicit schema-v1 delta:

```bash
omrollback-plan --context-file /path/to/context-delta.json
```

Machine-readable planning output for deterministic tooling and future Lychnos integration:

```bash
omrollback-plan --json
```

Disable Context Snapshot correlation:

```bash
omrollback-plan --no-context
```

Run both commands as the normal Omarchy user, not as root.

## Rollback Check result classes

- **CONFIRMED** — a direct migration-state inconsistency was proven using an audited machine-completion invariant from the installed Omarchy migration revision.
- **POTENTIAL** — the surviving user migration timeline is newer than the restored migration tree while root and home are separate Btrfs rollback units.
- **No evidence detected** — the safe checks found nothing they can prove or bound.
- **INCOMPLETE** — required migration evidence is unavailable.

`omrollback-check` exit codes remain:

```text
0  no rollback-related inconsistency evidence detected
1  confirmed inconsistency or potential rollback drift detected
2  incomplete check, invalid invocation, or missing required dependency
```

`omrollback-plan` preserves the diagnostic exit status so automation can distinguish clean, finding, and incomplete states without parsing prose.

## What Guided Recovery adds

The planner keeps recovery in three phases:

1. **Inspect** — preserve the rollback finding and Context Snapshot delta, then correlate migration markers, package changes, config fingerprints, failed services, and Omarchy metadata.
2. **Prepare** — choose a coherent recovery target and prepare a narrowly scoped response appropriate to `CONFIRMED`, `POTENTIAL`, `INCOMPLETE`, or clean evidence.
3. **Verify** — after a separately approved recovery action, re-run `omrollback-check` and `omcontext incident`.

Its JSON contract is schema version `1` and explicitly reports rollback status, evidence, context counts, advisory steps, `automatic_actions_permitted: false`, and the automatic actions the planner blocks.

## Safety model

Neither command restores/creates/deletes snapshots, edits migration markers, runs/replays migrations, changes packages, edits configuration, restarts/disables services, uses `sudo`, executes migration scripts, uploads data, or performs network access.

`omrollback-plan` executes only the read-only `omrollback-check` command and, when available, `omcontext diff --json`. Context Snapshot schema versions other than `1` are rejected rather than guessed at.

A plan is **advice**, not authorization. Future consumers such as Lychnos must still use their own permission/action mediation before any machine change.

## Install

From the repository root:

```bash
bash tools/rollback-check/install.sh
```

The installer places both commands in `~/.local/bin`.

Dependencies: Bash, `git`, `findmnt`, Python 3, and standard GNU/Linux userland already expected on Omarchy. Context Snapshot is optional; without it, the planner works from Rollback Check evidence alone.

See [`RESEARCH.md`](RESEARCH.md) for the evidence model and the recovery-planning safety boundary.
