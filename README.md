# Omarchy Contributions

Small, finished, public contributions for the Omarchy ecosystem.

The rule for this repository is deliberately strict: **research first, define a hard finish line, build it, test it, ship it.** This is not a parking lot for half-built ideas.

## Contributions

### Omarchy Plugin Rescue — v1.0.0

A TTY-safe recovery utility for Omarchy 4 / Quattro that temporarily removes **only third-party shell-plugin references** from `~/.config/omarchy/shell.json`, preserves the rest of the user's shell configuration, and can restore the exact original file afterward.

See [`tools/plugin-rescue/`](tools/plugin-rescue/README.md).

```bash
omrescue
```

Restore the exact pre-rescue shell configuration with `omrescue restore`.

### Omarchy Rollback Check + Guided Recovery

`omrollback-check` remains the conservative, read-only detector for root/home migration-ledger drift after an Omarchy root snapshot restore.

`omrollback-plan` is the new read-only recovery companion. It turns Rollback Check findings into a bounded inspect → prepare → verify sequence and, when available, correlates them with Omarchy Context Snapshot schema-v1 deltas.

See [`tools/rollback-check/`](tools/rollback-check/README.md).

```bash
omrollback-check
omrollback-plan
```

The planner can emit stable JSON for deterministic tooling and future Lychnos integration, but it explicitly authorizes **no automatic repair actions**. It never restores snapshots, replays migrations, deletes markers, changes packages/configuration, or restarts services.

### Omarchy Migration Check — v1.0.0

A read-only Quattro audit for known legacy Hyprland core `.conf` files that can survive the 3.x → Lua migration with configuration-like content even though the active user config has moved to `hyprland.lua`.

See [`tools/migration-check/`](tools/migration-check/README.md).

```bash
ommigration-check
```

The checker reports conservative `POSSIBLY_IGNORED`, `LEGACY`, `ACTIVE`, and `INCOMPLETE` states, points at the corresponding Lua review target, and never converts, deletes, sources, or executes user configuration.

### Omarchy Context Snapshot — v1.0.0

A local, read-only known-good baseline and incident-delta collector for Omarchy. It correlates package/version changes, migration markers, selected config fingerprints, failed services, disk pressure, Omarchy metadata, and a bounded sanitized journal sample without collecting config contents or uploading anything.

See [`tools/context-snapshot/`](tools/context-snapshot/README.md).

Common commands:

```bash
omcontext baseline
omcontext quick
omcontext incident
omcontext diff
omcontext show baseline
omcontext show latest
```

Machine-readable JSON is also available for the snapshot and delta commands:

```bash
omcontext quick --json
omcontext baseline --json
omcontext incident --json
omcontext diff --json
```

`baseline` stores a known-good reference, `quick` checks the current state without saving a snapshot, `incident` captures and compares the current state to the baseline, `diff` re-renders the latest saved comparison, and `show` inspects the stored sanitized baseline or latest snapshot.

The JSON snapshot/delta contract is schema-versioned for deterministic tooling and future local-assistant consumers while remaining independent of any AI model.

## Install

Clone the repository once:

```bash
git clone https://github.com/Drecullith/Omarchy-Contributions.git
cd Omarchy-Contributions
```

Install Plugin Rescue:

```bash
bash tools/plugin-rescue/install.sh
```

Install Rollback Check + Guided Recovery:

```bash
bash tools/rollback-check/install.sh
```

Install Migration Check:

```bash
bash tools/migration-check/install.sh
```

Install Context Snapshot:

```bash
bash tools/context-snapshot/install.sh
```

All installers place their command(s) in `~/.local/bin`. None installs a daemon or modifies Omarchy's own command files.

## Project boundaries

- Public Omarchy utilities, plugins, fixes, documentation, and upstream-ready experiments belong here.
- Every contribution must have an explicit definition of done before implementation.
- Existing ecosystem solutions are researched before a new tool is started.
- Keep contributions self-contained and free of unrelated confidential or unreleased material.

## License

MIT. See [`LICENSE`](LICENSE).
