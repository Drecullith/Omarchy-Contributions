# Omarchy Plugin Rescue

**Version 1.0.1 — complete scope**

`omrescue` is a small external recovery utility for **Omarchy 4 / Quattro shell plugins**.

It is intentionally **not a shell plugin**. If a third-party Quickshell plugin has frozen or broken the shell, the recovery tool must not depend on that shell being healthy.

## The problem

Omarchy's normal plugin management is shell-driven:

- `omarchy plugin list` asks the running shell for its plugin registry.
- `omarchy plugin disable <id>` calls the running shell over IPC.

That is great during normal operation, but it is the wrong dependency when the long-running Quickshell process is precisely what a bad third-party plugin has broken.

Omarchy also provides `omarchy refresh shell`, but that resets the user's shell configuration to defaults. Plugin Rescue instead changes only third-party plugin references and keeps unrelated bar, idle, and first-party configuration intact.

## What rescue mode does

Running:

```bash
omrescue
```

or explicitly:

```bash
omrescue rescue
```

will:

1. Validate the user's `~/.config/omarchy/shell.json` as JSON.
2. Save an owner-only snapshot under `$XDG_STATE_HOME/omrescue/` (or `~/.local/state/omrescue/`).
3. Read third-party manifests **as data only**; it never executes plugin code.
4. Find third-party IDs referenced by the shell config, including stale references whose plugin directory is already gone.
5. Remove third-party service/panel/menu/overlay entries.
6. Remove third-party bar widgets.
7. Fall back from a third-party full bar to the built-in Omarchy bar.
8. When a genuine Omarchy clone declares `omarchy.clonedFrom`, temporarily restore the corresponding first-party widget/bar while preserving inline widget settings.
9. Leave plugin files on disk untouched.
10. Restart the Omarchy shell when possible.

Restore the exact original configuration with:

```bash
omrescue restore
```

Check state with:

```bash
omrescue status
```

## Safety behavior

- Refuses to run as root.
- Uses owner-only state directories and snapshots.
- Serializes rescue/restore state changes with a non-blocking `flock`, so two recovery operations cannot mutate the same state at once.
- Uses atomic replacement for `shell.json`.
- Re-checks the original `shell.json` immediately before installing the safe copy and aborts if another process changed it during rescue.
- Does not delete, move, source, import, or execute plugin files.
- Trusts clone metadata only when `clonedFrom` points into Omarchy's reserved `omarchy.*` first-party namespace.
- Preserves a byte-for-byte copy of the original `shell.json`.
- If `shell.json` is edited after rescue, normal restore refuses to overwrite those edits. Use `restore --force` only when intentionally discarding them.
- If shell restart fails or reports a false negative, the safe config remains applied and the tool tells the user to retry `omarchy restart shell`.

## Install

From this repository:

```bash
bash tools/plugin-rescue/install.sh
```

The installer copies one executable to:

```text
~/.local/bin/omrescue
```

No sudo, daemon, package manager, or plugin installation is involved.

You can also install it manually:

```bash
install -Dm755 tools/plugin-rescue/bin/omrescue \
  ~/.local/bin/omrescue
```

## Usage

```text
omrescue [rescue] [--no-restart]
omrescue restore [--force] [--no-restart]
omrescue status
omrescue version
```

`--no-restart` is useful for inspection, tests, or recovery steps where the user wants to restart the shell manually.

## Requirements

- Omarchy 4 / Quattro
- Bash
- `jq` (already used by Omarchy's own shell/plugin tooling)
- `flock` from util-linux
- Core GNU userland (`cp`, `mv`, `mktemp`, `cmp`, `chmod`, `awk`, `sort`)

## Test

```bash
bash -n tools/plugin-rescue/bin/omrescue
bash tools/plugin-rescue/test/run.sh
```

The test suite uses isolated temporary HOME/state directories. It covers normal third-party widgets/services/bars, stale IDs, clone restoration, exact restore, restore conflict protection, malformed manifests, no-op behavior, hostile clone metadata, and concurrent-operation locking.

## What it deliberately does not do

This is **not** a general Omarchy repair suite. It does not:

- delete or quarantine plugins;
- diagnose which plugin is faulty;
- repair first-party Omarchy/Quickshell bugs;
- reset the whole shell;
- repair Hyprland plugins;
- update plugins;
- add a GUI, daemon, telemetry, AI, or cloud component.

If the failure exists with third-party shell plugins removed, use Omarchy's normal diagnostics/recovery path.

## Definition of Done

> From a terminal or TTY, a user can make an existing Omarchy shell configuration temporarily free of third-party shell-plugin references without losing unrelated customization, restart into that safe configuration, and later restore the exact original config.

That remains the complete v1 scope. Version 1.0.1 only hardens state/concurrency handling; it does not expand the tool's mission.
