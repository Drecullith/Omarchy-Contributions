# Omarchy Contributions

Small, finished, public contributions for the Omarchy ecosystem.

The rule for this repository is deliberately strict: **research first, define a hard finish line, build it, test it, ship it.** This is not a parking lot for half-built ideas.

## Contributions

### Omarchy Plugin Rescue — v1.0.0

A TTY-safe recovery utility for Omarchy 4 / Quattro that temporarily removes **only third-party shell-plugin references** from `~/.config/omarchy/shell.json`, preserves the rest of the user's shell configuration, and can restore the exact original file afterward.

See [`tools/plugin-rescue/`](tools/plugin-rescue/README.md).

Install it once, then recover from a terminal or TTY with:

```bash
omrescue
```

Restore the exact pre-rescue shell configuration with `omrescue restore`.

## Install Plugin Rescue

```bash
git clone https://github.com/Drecullith/Omarchy-Contributions.git
cd Omarchy-Contributions
bash tools/plugin-rescue/install.sh
```

The installer places `omrescue` in `~/.local/bin` and does not use `sudo`, install a daemon, or modify Omarchy's own command files.

## Project boundaries

- Public Omarchy utilities, plugins, fixes, documentation, and upstream-ready experiments belong here.
- Every contribution must have an explicit definition of done before implementation.
- Existing ecosystem solutions are researched before a new tool is started.
- Private or unreleased work from unrelated projects must never be copied, referenced, or exposed here.

## License

MIT. See [`LICENSE`](LICENSE).
