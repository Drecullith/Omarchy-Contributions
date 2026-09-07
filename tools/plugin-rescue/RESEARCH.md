# Research record — Omarchy Plugin Rescue

**Research date:** 2026-09-06

## Question

Does the current Omarchy ecosystem already provide a targeted, reversible, TTY-safe way to recover from a broken third-party **Omarchy Quickshell shell plugin** while preserving the rest of `shell.json`?

## Sources checked

- Official Omarchy Quattro shell-plugin manual and shell documentation.
- Official `omarchy-plugin-list`, `omarchy-plugin-disable`, `omarchy-shell`, and `omarchy-refresh-shell` implementations.
- Current Omarchy GitHub issues/discussions around Quickshell/plugin failures and reload races.
- Omarchy community plugin marketplace / registry.
- Broad GitHub/web searches for Omarchy plugin rescue, plugin safe mode, third-party plugin recovery, and disable-all recovery.
- Reddit/community search for the same concepts.

## Relevant official behavior

### Normal plugin disable needs a healthy shell

The official `omarchy-plugin-disable` command calls:

```text
omarchy-shell shell setPluginEnabled <id> false
```

The official `omarchy-plugin-list` similarly calls the running shell's `listPlugins` IPC method. These are normal-management tools, not dead-shell recovery tools.

### The built-in full recovery is broader than this problem

Official `omarchy-refresh-shell` resets `omarchy/shell.json`, resets the bar to defaults, and restarts the shell. That is appropriate when a full shell reset is wanted, but it is intentionally broader than “temporarily neutralize third-party plugin references and preserve everything else.”

### The failure mode is real

Current public issues document third-party/plugin reload failures including:

- third-party bars that can leave the desktop without a bar;
- Quickshell crashes during local-plugin hot reload;
- plugin remove/update races with the plugin-directory watcher;
- shell restart reporting failure while recovery is still occurring;
- third-party/user plugin hot-reload problems.

## Novelty conclusion

No equivalent targeted utility surfaced in the official Omarchy commands, current marketplace/registry, GitHub searches, or community search performed on 2026-09-06.

That is **evidence of an unfilled public gap, not a mathematical guarantee that no private or unindexed implementation exists anywhere**.

The specific gap this project fills is:

> Offline/config-level, third-party-only shell-plugin safe mode with exact reversible restore, without requiring the broken Quickshell IPC process and without resetting unrelated shell customization.

## Maintenance audit — 2026-09-08

The upstream assumptions behind v1 were re-checked against current `quattro`.

- `omarchy-plugin-disable` still forwards to the running shell over IPC, so it is not a dead-shell recovery path.
- `omarchy-refresh-shell` still refreshes `shell.json`, restores bar defaults, and restarts the shell, so it remains broader than Plugin Rescue.
- The current plugin registry still records active third-party references through the selected bar id, bar layout entries, and `plugins[]`; clone restore and disabled-plugin state remain compatible with the rescue sanitizer.
- The official CLI plugin validator still enforces the same safe plugin-id shape used by Plugin Rescue: `^[A-Za-z0-9][A-Za-z0-9._-]*$`, excluding the reserved `omarchy.*` namespace.
- Recent upstream plugin capability/authentication hardening reduces what third-party plugins can access, but it does not provide an offline third-party-only safe mode or remove the availability/recovery failure class.
- A fresh PR search found no equivalent targeted rescue feature.

Conclusion: **v1 remains useful and no code change is required as of 2026-09-08.**

## References

- Omarchy shell plugins: https://github.com/omacom/omarchy/blob/quattro/manual/32-shell-plugins.md
- Omarchy shell internals: https://github.com/omacom/omarchy/blob/quattro/shell/README.md
- Plugin disable: https://github.com/omacom/omarchy/blob/quattro/bin/omarchy-plugin-disable
- Plugin list: https://github.com/omacom/omarchy/blob/quattro/bin/omarchy-plugin-list
- Shell refresh: https://github.com/omacom/omarchy/blob/quattro/bin/omarchy-refresh-shell
- Plugin reload crash issue #7362: https://github.com/omacom/omarchy/issues/7362
- Third-party bar failure issue #7253: https://github.com/omacom/omarchy/issues/7253
- Plugin reload/update race issue #8583: https://github.com/omacom/omarchy/issues/8583
- User plugin hot-reload issue #8202: https://github.com/omacom/omarchy/issues/8202
- Restart readiness issue #8568: https://github.com/omacom/omarchy/issues/8568
- Community marketplace: https://github.com/omacom/omarchy-plugin-marketplace
