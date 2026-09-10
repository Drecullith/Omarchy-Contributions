# Research notes — Omarchy Context Snapshot v1

## Existing Omarchy diagnostic path

Current Quattro ships `bin/omarchy-debug`. It can collect `inxi -Farz`, current-boot journal warnings/errors, the installed package set, and optionally `dmesg`; it writes the result to `/tmp/omarchy-debug.log` and can view, save, or upload it.

That is useful as a support dump, so `omcontext` intentionally does not duplicate it.

The gap addressed here is historical context: a compact, local comparison against a user-created known-good baseline, with structured evidence for package, migration, config-fingerprint, service, disk, and bounded sanitized journal changes.

## Ecosystem search

Before implementation, searches were performed in the current Omarchy repository for existing context/baseline/delta collectors and for public repository names/code using `omcontext` / "Omarchy context snapshot" terminology. No equivalent tool was found in the researched scope.

## v1 privacy decisions

The v1 collector deliberately excludes:

- hostname and username;
- network interface/address enumeration;
- hardware serials/UUIDs;
- shell history;
- environment-variable dumps;
- browser/application profiles;
- config contents;
- automatic uploads.

Journal strings are sanitized before storage. Config state is represented by named hashes. State uses private permissions and refuses symlinked state directories.

## Definition of Done

v1 is finished when it can:

1. create a private known-good baseline;
2. capture an incident/latest snapshot;
3. compare baseline and latest state;
4. emit both concise human output and schema-v1 JSON;
5. report package, migration-marker, config-fingerprint, failed-service, Omarchy metadata, disk, and bounded sanitized journal evidence;
6. refuse root;
7. never modify Omarchy/system state or use the network;
8. store only sanitized/fingerprinted diagnostic state with private permissions;
9. pass isolated regression tests and installer smoke tests.

## Out of scope for v1

- daemon/background watcher;
- continuous monitoring or scheduled collection;
- automatic repair;
- service restarts;
- package or migration changes;
- snapshot management;
- AI/model calls;
- network access, telemetry, or uploads;
- arbitrary config-file discovery;
- raw journal export;
- root-only diagnostics.
