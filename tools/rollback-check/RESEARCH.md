# Research notes — Omarchy Rollback Check

Research date: 2026-09-06.

## Problem source

Omarchy issue `#9828` documents and reproduces a migration-ledger drift class after Snapper rollback.

Current Omarchy behavior relevant to the problem:

- `bin/omarchy-migrate` stores the per-user migration ledger under `$HOME/.local/state/omarchy/migrations` by default.
- User markers use the migration filename, including `.sh`.
- A migration runs only when that user marker is absent.
- Omarchy's root snapshot flow restores the root Snapper unit; `$HOME` can live on a separate Btrfs subvolume and survive that restore.
- `omarchy snapshot restore` delegates to `limine-snapper-restore`; there is no user-facing post-restore reconciliation of the per-user migration ledger.

The result can be mixed state: root-side effects may be rewound while home-side state and the per-user completion marker survive.

## Why automatic replay is out of scope

The issue investigation explicitly warns that replaying migrations wholesale is not a safe generic recovery strategy. Migrations can:

- run package transactions;
- fail-fast and block later migrations;
- combine root-side and home-side effects;
- be conditional on the machine's current state.

Accordingly, v1 is diagnostic only.

## Direct machine-completion invariants

A first draft considered scanning every migration script for literal `/var/lib/omarchy/migrations/...` paths and treating a missing machine marker plus a surviving user marker as proof.

That approach was rejected during adversarial testing because it is false-positive prone.

Examples in current Omarchy source include:

- `1786482992.sh`: the machine marker is written only when a Limine rebuild is actually required; a healthy no-op run can legitimately leave the marker absent.
- `1786605598.sh`: the rebuild marker is conditional on NVIDIA/initramfs state.
- `1788009111.sh`: the migration can exit successfully when `cups-browsed` is not installed, without writing its machine marker.
- `1788102906.sh`: uses a suffixed marker as temporary reload bookkeeping rather than permanent completion evidence.

Therefore v1 emits `CONFIRMED` only for exact migration script revisions audited to have a permanent machine-completion invariant on successful execution:

| Migration | Git blob | Machine marker |
| --- | --- | --- |
| `1786380259.sh` | `ebe9af2c31c58ce91d4cfb01b647225f1c34b6f3` | `/var/lib/omarchy/migrations/1786380259` |
| `1787815267.sh` | `b3f9282a9664e9fb195e74ad99e2efa3665e0f44` | `/var/lib/omarchy/migrations/1787815267` |
| `1788025225.sh` | `295b71ba916003ac965bf3cc13f84af9f8c5f472` | `/var/lib/omarchy/migrations/1788025225` |

The checker compares the installed script using `git hash-object --no-filters` with global/system Git configuration disabled. If upstream changes one of these scripts, the direct proof is disabled instead of extending old assumptions to new code.

## Potential timeline signal

Omarchy migration filenames are numeric chronological IDs. If the user's surviving ledger contains a numeric marker newer than every migration script in the current Omarchy tree, that is useful evidence that home has seen a newer migration timeline than root.

This is **not proof** because migrations can be removed/superseded and development installs can have unusual histories. v1 emits this only as `POTENTIAL`, and only when `findmnt` shows root and home as separate Btrfs mount/subvolume units consistent with the rollback mechanism in `#9828`.

## Novelty / duplication check

Before implementation, searches covered:

- the current Omarchy repository;
- open Omarchy issues and pull requests around snapshot restore, migrations, rollback reconciliation, and migration-state checking;
- GitHub repository search for Omarchy rollback/migration checker utilities;
- GitHub code search for the command name `omrollback-check`.

No obvious current public equivalent was found. This is intentionally narrower than a general backup, snapshot, dotfile, or repair tool.

## Definition of Done

v1 is complete when the command:

1. runs as the normal Omarchy user and refuses root;
2. never modifies snapshots, markers, packages, system files, or user config;
3. never sources or executes migration scripts;
4. reports direct inconsistency only from audited exact-revision invariants;
5. reports newer-home timeline evidence only as `POTENTIAL` on a matching split Btrfs layout;
6. reports incomplete checks explicitly instead of guessing;
7. has isolated regression coverage for the known false-positive classes;
8. contains no network, telemetry, daemon, GUI, AI, or repair behavior.
