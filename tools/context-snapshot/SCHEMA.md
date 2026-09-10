# Omarchy Context Snapshot schema v1

Schema version `1` is the stable machine-readable contract for Omarchy Context Snapshot v1.

A snapshot contains these top-level keys:

```text
schema_version
captured_at
tool
system
omarchy
packages
migrations
failed_services
configs
journal
collection
privacy_scan
```

Important semantics:

- `packages` is a map of package name to installed version. It is used for local delta generation.
- `migrations` contains only numeric user-ledger marker IDs; migration scripts are never sourced or executed.
- `failed_services` contains sanitized system/user systemd unit names only.
- `configs` contains existence state and SHA-256 fingerprints for the fixed v1 config set. Config contents are not part of the schema.
- `journal` is a bounded list of already-sanitized current-boot warning/error strings.
- `collection.incomplete` records collectors that could not produce evidence. Missing evidence must not be interpreted as a healthy result.
- `privacy_scan` records the built-in post-collection scan result.

A baseline/current delta contains:

```text
schema_version
baseline_captured_at
current_captured_at
health
changes
current
```

`health` is one of:

- `healthy` — no tracked delta;
- `changed` — tracked state changed, but no v1 degradation rule fired;
- `degraded` — a new failed service appeared or tracked root/home disk usage reached at least 95%.

The `changes` object separates package additions/removals/version changes, added migration markers, changed config fingerprints, new/cleared failed services, and Omarchy metadata changes.

Consumers such as Lychnos should treat all findings as diagnostic evidence. Schema v1 does not authorize repair actions.
