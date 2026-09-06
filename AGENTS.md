# Repository instructions

This repository contains small, finished public contributions for Omarchy.

## Contribution rules

1. Research the official Omarchy repository, current issues/discussions, the plugin marketplace/registry, and relevant community projects before starting a new contribution.
2. Do not duplicate an existing solution unless there is a clearly documented gap the new contribution solves.
3. Define a hard `Definition of Done` before implementation. Do not invent a roadmap after v1 is complete.
4. Keep each contribution narrow, dependency-light, auditable, and reversible.
5. Keep contributions self-contained. Do not include unrelated confidential, private, or unreleased material.
6. Prefer existing Omarchy interfaces and file formats over parallel frameworks.
7. Never execute third-party plugin code merely to inspect, disable, validate, or recover from it.

## Omarchy Plugin Rescue v1 scope

Finished scope:
- rescue third-party shell plugin references while preserving unrelated shell configuration;
- restore the exact pre-rescue `shell.json`;
- report rescue status;
- optionally restart the Omarchy shell;
- refuse unsafe restore overwrites unless explicitly forced.

Out of scope unless a real defect requires a targeted fix:
- GUI or Quickshell plugin;
- daemon/service;
- AI features;
- telemetry;
- plugin updates or package management;
- automatic diagnosis of which plugin is broken;
- plugin quarantine/deletion;
- Hyprland plugin recovery;
- general system repair.
