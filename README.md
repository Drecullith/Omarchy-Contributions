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

Both installers place their command in `~/.local/bin`. Neither installer uses `sudo`, installs a daemon, or modifies Omarchy's own command files.

## Project boundaries

- Public Omarchy utilities, plugins, fixes, documentation, and upstream-ready experiments belong here.
- Every contribution must have an explicit definition of done before implementation.
- Existing ecosystem solutions are researched before a new tool is started.
- Keep contributions self-contained and free of unrelated confidential or unreleased material.

## License

MIT. See [`LICENSE`](LICENSE).
