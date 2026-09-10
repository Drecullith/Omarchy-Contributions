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

### Omarchy Rollback Check — v1.0.0

A read-only diagnostic for the root/home migration-ledger drift that can follow an Omarchy root snapshot restore. It reports conservative evidence classes and never changes snapshots, migration markers, packages, system files, or user configuration.

See [`tools/rollback-check/`](tools/rollback-check/README.md).

```bash
omrollback-check
```

`CONFIRMED` findings are limited to exact upstream migration revisions with audited machine-completion invariants. Broader timeline evidence is reported only as `POTENTIAL` on a matching split Btrfs root/home layout.

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

```bash
omcontext baseline
omcontext incident
```

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

Install Rollback Check:

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

All installers place their command in `~/.local/bin`. None uses `sudo`, installs a daemon, or modifies Omarchy's own command files.

## Project boundaries

- Public Omarchy utilities, plugins, fixes, documentation, and upstream-ready experiments belong here.
- Every contribution must have an explicit definition of done before implementation.
- Existing ecosystem solutions are researched before a new tool is started.
- Keep contributions self-contained and free of unrelated confidential or unreleased material.

## License

MIT. See [`LICENSE`](LICENSE).
