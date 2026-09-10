# Omarchy Context Snapshot — v1.0.0

`omcontext` is a local, read-only context and delta collector for Omarchy.

It is designed for the question that ordinary debug dumps do not answer well:

> What changed since this machine was known-good?

The tool records a private baseline, can capture a later incident snapshot, and produces a compact human report or stable JSON delta suitable for troubleshooting tools and future local assistants such as Lychnos.

## What it collects

`omcontext` deliberately collects a bounded set of evidence:

- Omarchy package version and, when available, checkout commit;
- kernel and architecture;
- root/home disk usage percentages;
- installed package names and versions for local baseline comparison;
- numeric Omarchy user migration markers;
- failed system and user systemd unit names;
- SHA-256 fingerprints for a small, named set of Omarchy/Hyprland config files;
- up to 40 current-boot warning/error journal messages after sanitization.

It does **not** collect hostname, shell history, environment variables, hardware serial numbers, IP/MAC configuration, browser data, SSH material, API keys, passwords, or config-file contents.

## Commands

Create the known-good baseline after the machine is working normally:

```bash
omcontext baseline
```

Get a current read-only health summary without writing a snapshot:

```bash
omcontext quick
```

When something goes wrong, capture the current state and compare it to the baseline:

```bash
omcontext incident
```

Re-render the most recent saved comparison:

```bash
omcontext diff
```

Machine-readable output is available for the snapshot/delta commands:

```bash
omcontext quick --json
omcontext baseline --json
omcontext incident --json
omcontext diff --json
```

Inspect a stored sanitized snapshot:

```bash
omcontext show baseline
omcontext show latest
```

## State

State is stored under:

```text
${XDG_STATE_HOME:-~/.local/state}/omcontext/
├── baseline.json
├── latest.json
└── history/
```

The state directory is forced to mode `0700`; snapshot files are written atomically at mode `0600`. A symlinked state/history directory is refused.

Snapshots use schema version `1`. See [`SCHEMA.md`](SCHEMA.md).

## Privacy model

Sanitization happens before journal strings enter a snapshot. The collector replaces home-directory identities, email addresses, IPv4 addresses, MAC addresses, credential-like assignments, and long token-like strings. Config files are fingerprinted, never copied.

Every snapshot carries a `privacy_scan` result. A `PASS` means the built-in post-collection checks found no supported sensitive patterns; it is not a mathematical guarantee that arbitrary log text can never contain identifying information. Review any report before sharing it outside your machine.

There is no network code and no upload command.

## Exit status

- `0` — collection succeeded and no newly degraded condition was detected;
- `1` — an incident/diff contains a newly failed service or >=95% tracked disk usage;
- `2` — usage/state/collection error, including running as root.

A changed package, config fingerprint, migration marker, Omarchy version, or theme is evidence of change, not automatically a fault.

## Install

From this repository:

```bash
bash tools/context-snapshot/install.sh
```

The installer places `omcontext` in `~/.local/bin` and does not use `sudo`.

## Safety boundary

`omcontext` never repairs anything. It does not restart services, replay migrations, edit configs, install/remove packages, alter snapshots, or call the network.
