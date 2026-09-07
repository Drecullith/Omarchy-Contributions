# Omarchy Migration Check — v1.0.0

`ommigration-check` is a small, read-only audit for a Quattro migration failure class: old Hyprland `.conf` files can survive an Omarchy 3.x → 4 / Quattro upgrade even though the active Hyprland configuration has moved to Lua.

That can make old settings look safely preserved on disk while no longer participating in the live configuration.

The tool **does not migrate or repair anything**. It identifies known legacy core config files, distinguishes inert files from files with configuration-like content, and points at the corresponding Quattro Lua location to review.

## Usage

```bash
ommigration-check
ommigration-check version
```

Run it as the normal Omarchy user, not as root.

## What v1 checks

When `~/.config/hypr/hyprland.lua` exists, v1 audits these known pre-Quattro core files if they are still present:

```text
hyprland.conf
envs.conf
monitors.conf
input.conf
bindings.conf
looknfeel.conf
autostart.conf
```

It intentionally does **not** flag every `.conf` file. Current Quattro still legitimately uses standalone configs such as `hyprsunset.conf` and `xdph.conf`.

## Result classes

- **POSSIBLY_IGNORED** — a known legacy core file contains at least one nonblank, non-comment configuration line while the Quattro Lua entry point exists. This is migration evidence, not proof that each line was user-authored or that every setting is currently missing.
- **LEGACY** — a known legacy core file remains, but it contains only blank/comment lines.
- **ACTIVE** — a legacy `hyprland.conf` exists and no Quattro `hyprland.lua` entry point was found. That shape does not match the Lua-provider orphaning mechanism v1 is designed to detect.
- **INCOMPLETE** — the expected Hyprland config directory or provider entry point is missing, so the audit cannot classify the machine reliably.

Exit codes:

```text
0  no possibly ignored legacy core config detected
1  one or more POSSIBLY_IGNORED files detected
2  incomplete check, invalid invocation, or root invocation
```

## Suggested review targets

The checker reports where a wanted setting would normally be reviewed after Quattro:

```text
hyprland.conf  -> hyprland.lua
envs.conf      -> hyprland.lua or another required Lua module
monitors.conf  -> monitors.lua
input.conf     -> input.lua
bindings.conf  -> bindings.lua
looknfeel.conf -> looknfeel.lua
autostart.conf -> autostart.lua
```

This is guidance for manual review, not automatic translation. Hyprland's Lua configuration model is not a line-for-line syntax replacement for the old hyprlang format.

## Safety model

`ommigration-check`:

- never edits, deletes, renames, or migrates configuration;
- never sources or executes legacy `.conf` files;
- never executes the user's Lua config;
- never runs `hyprctl` against the live session;
- never uses `sudo`;
- never installs packages;
- performs no network access and sends no telemetry.

The tool reads regular files under the user's Hyprland config directory and classifies only the narrow evidence documented above.

## Install

From the repository root:

```bash
bash tools/migration-check/install.sh
```

The installer places `ommigration-check` in `~/.local/bin`.

Dependencies: Bash plus standard GNU/Linux `awk`, already expected on Omarchy.

## Scope boundary

v1 is finished when it can safely detect and report the documented legacy core `.conf` state on a Quattro Lua configuration, without modifying the machine.

It is **not** a config converter, automatic repair utility, migration replay tool, daemon, GUI, AI assistant, or general Omarchy doctor.

See [`RESEARCH.md`](RESEARCH.md) for the upstream evidence and false-positive constraints behind the design.
