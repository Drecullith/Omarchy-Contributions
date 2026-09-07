# Research — Omarchy Migration Check v1.0.0

## Problem verified upstream

Omarchy issue [#6933](https://github.com/omacom/omarchy/issues/6933) documents a real 3.x → Quattro migration gap: `~/.config/hypr/bindings.conf` can remain on disk while the new `hyprland.lua` loads `hypr.bindings` instead, silently leaving old bindings inactive.

Follow-up reports in the same issue widen the failure class beyond keybindings:

- `envs.conf` with environment overrides;
- `input.conf` with keyboard/touchpad settings;
- `looknfeel.conf` with VRR, tearing, and animation settings;
- old `hyprland.conf` window rules;
- the original `bindings.conf` case.

The reports span multiple independent upgraded machines, so v1 treats this as a migration-audit problem rather than a single-app workaround.

## Current Quattro config model

At the v1 research point, Omarchy's stock `config/hypr/hyprland.lua` loads these user Lua modules after Omarchy defaults:

```lua
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")
```

Hyprland 0.55+ itself has moved from the old hyprlang `.conf` provider to Lua and recommends `require()` for additional Lua modules.

This matters to the checker: merely preserving an old hyprlang file on disk does not mean the new Lua provider consumes it.

## Why v1 does not scan every `.conf`

Current Omarchy Quattro still ships legitimate non-provider `.conf` files in `config/hypr`, including:

- `hyprsunset.conf`;
- `xdph.conf`.

A generic `find ~/.config/hypr -name '*.conf'` warning would therefore create false positives.

v1 instead audits a bounded list of old Hyprland core config classes tied to the migration reports and the former user-config layout:

```text
hyprland.conf
envs.conf
monitors.conf
input.conf
bindings.conf
looknfeel.conf
autostart.conf
```

Expanding that list requires new evidence, not speculation.

## Why the finding is POSSIBLY_IGNORED, not CONFIRMED_LOST

A non-comment line proves that a legacy file contains configuration-like content. It does **not** prove:

- the line was authored by the user rather than shipped by an older Omarchy version;
- the same intent was not already recreated manually in Lua;
- every legacy directive still has an exact modern equivalent.

So v1 reports `POSSIBLY_IGNORED` and tells the user where to review the wanted settings. It never auto-converts or deletes the source file.

The final v1 classifier intentionally does not inspect Lua files for textual references to legacy filenames. A filename mention is neither necessary nor sufficient to prove that old hyprlang configuration is loaded, so classification is based only on the bounded legacy-file state and the provider shape.

## Existing-solution search

Before implementation, the following were checked:

- current `omacom/omarchy` issue and PR search for the `.conf` → `.lua` orphaning problem;
- current Omarchy Quattro config and upgrade code;
- the Omarchy Plugin Marketplace / registry ecosystem;
- public GitHub repositories matching an Omarchy migration-check / doctor-style tool.

No equivalent standalone post-upgrade config-orphan audit was found.

The community project `duclucky/can-i-omarchy` is a pre-install application compatibility/readiness checker, not a post-migration machine audit, so it does not overlap this scope.

The Omarchy Plugin Marketplace and hosted registry focus on third-party plugin discovery, publication, verification, and installation. This tool is intentionally a standalone local diagnostic and does not duplicate plugin-registry functionality.

## Maintenance audit — 2026-09-08

The v1 assumptions were re-checked against current `quattro`.

- Issue `#6933` remains open.
- A fresh PR search found no upstream fix or equivalent doctor-style audit for the reported `.conf` → Lua orphaning gap.
- Current `config/hypr/hyprland.lua` still loads `hypr.monitors`, `hypr.input`, `hypr.bindings`, `hypr.looknfeel`, and `hypr.autostart` and does not restore the old core `.conf` provider shape.
- Current `config/hypr/` still legitimately contains standalone `hyprsunset.conf` and `xdph.conf`, so excluding them remains necessary to avoid false positives.
- The checker logic already reflects the conservative final design; only stale documentation from the removed Lua-filename heuristic needed correction.

Conclusion: **v1 remains useful and no code change is required as of 2026-09-08.**

## Definition of Done

v1.0.0 is complete when it:

- detects the bounded legacy core file set on a Quattro Lua config;
- reports non-comment legacy content as `POSSIBLY_IGNORED`;
- reports blank/comment-only remnants as `LEGACY`;
- recognizes a legacy-only provider shape without blaming the Quattro orphaning mechanism;
- excludes current standalone `.conf` files from the audit;
- never executes legacy config or Lua code;
- supplies focused isolated tests;
- includes a non-root installer, documentation, research notes, changelog, and CI coverage;
- performs no repair.

Anything beyond that requires a separately justified defect or scope revision.
