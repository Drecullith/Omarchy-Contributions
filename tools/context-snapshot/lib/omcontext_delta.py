from __future__ import annotations

from typing import Any


def diff_snapshots(base: dict[str, Any], current: dict[str, Any], schema_version: int) -> dict[str, Any]:
    bp, cp = base.get("packages", {}), current.get("packages", {})
    added = sorted(n for n in cp if n not in bp)
    removed = sorted(n for n in bp if n not in cp)
    changed = [
        {"name": n, "previous": bp[n], "current": cp[n]}
        for n in sorted(set(bp) & set(cp)) if bp[n] != cp[n]
    ]
    migration_added = sorted(set(current.get("migrations", [])) - set(base.get("migrations", [])), key=int)

    bc, cc = base.get("configs", {}), current.get("configs", {})
    configs_changed = [n for n in sorted(set(bc) | set(cc)) if bc.get(n) != cc.get(n)]

    bf = set(base.get("failed_services", {}).get("system", [])) | set(base.get("failed_services", {}).get("user", []))
    cf = set(current.get("failed_services", {}).get("system", [])) | set(current.get("failed_services", {}).get("user", []))
    failed_new, failed_cleared = sorted(cf - bf), sorted(bf - cf)

    omarchy = {}
    for field in ("package", "commit", "theme"):
        before = base.get("omarchy", {}).get(field)
        after = current.get("omarchy", {}).get(field)
        if before != after: omarchy[field] = {"previous": before, "current": after}

    root_pct = current.get("system", {}).get("root_usage_pct")
    home_pct = current.get("system", {}).get("home_usage_pct")
    degraded = bool(failed_new) or any(v is not None and v >= 95 for v in (root_pct, home_pct))
    any_change = any((added, removed, changed, migration_added, configs_changed, failed_new, failed_cleared, omarchy))
    health = "degraded" if degraded else ("changed" if any_change else "healthy")

    return {
        "schema_version": schema_version,
        "baseline_captured_at": base.get("captured_at"), "current_captured_at": current.get("captured_at"),
        "health": health,
        "changes": {
            "packages_added": added, "packages_removed": removed, "packages_changed": changed,
            "migrations_added": migration_added, "configs_changed": configs_changed,
            "failed_services_new": failed_new, "failed_services_cleared": failed_cleared, "omarchy": omarchy,
        },
        "current": {
            "root_usage_pct": root_pct, "home_usage_pct": home_pct,
            "journal": current.get("journal", []),
            "collection_incomplete": current.get("collection", {}).get("incomplete", []),
            "privacy_scan": current.get("privacy_scan", {}),
        },
    }


def render_report(delta: dict[str, Any]) -> str:
    c = delta["changes"]
    lines = ["OMARCHY CONTEXT", f"Status: {delta['health'].upper()}", "", "Changes since baseline:"]
    emitted = False
    for field, item in c["omarchy"].items():
        lines.append(f"  ~ Omarchy {field}: {item['previous']} -> {item['current']}"); emitted = True
    if c["packages_changed"]:
        lines.append(f"  ~ {len(c['packages_changed'])} package version(s) changed")
        for item in c["packages_changed"][:12]:
            lines.append(f"      {item['name']}: {item['previous']} -> {item['current']}")
        emitted = True
    if c["packages_added"]:
        lines.append(f"  + {len(c['packages_added'])} package(s) added: {', '.join(c['packages_added'][:12])}"); emitted = True
    if c["packages_removed"]:
        lines.append(f"  - {len(c['packages_removed'])} package(s) removed: {', '.join(c['packages_removed'][:12])}"); emitted = True
    if c["migrations_added"]:
        lines.append(f"  + migration marker(s): {', '.join(c['migrations_added'])}"); emitted = True
    if c["configs_changed"]:
        lines.append(f"  ~ config fingerprint(s): {', '.join(c['configs_changed'])}"); emitted = True
    if c["failed_services_new"]:
        lines.append(f"  ! new failed service(s): {', '.join(c['failed_services_new'])}"); emitted = True
    if c["failed_services_cleared"]:
        lines.append(f"  ✓ cleared failed service(s): {', '.join(c['failed_services_cleared'])}"); emitted = True
    if not emitted: lines.append("  ✓ no tracked changes")

    lines += ["", "Current health:"]
    for label, key in (("root", "root_usage_pct"), ("home", "home_usage_pct")):
        value = delta["current"][key]
        if value is not None: lines.append(f"  {'!' if value >= 95 else '✓'} {label} disk usage: {value}%")
    if not c["failed_services_new"]: lines.append("  ✓ no newly failed tracked services")

    journal = delta["current"].get("journal", [])
    if journal:
        lines += ["", "Recent sanitized warnings/errors:"] + [f"  - {x}" for x in journal[:12]]
    incomplete = delta["current"].get("collection_incomplete", [])
    if incomplete:
        lines += ["", "Incomplete checks:"] + [f"  ? {x}" for x in incomplete]
    privacy = delta["current"].get("privacy_scan", {})
    lines += ["", f"Privacy scan: {privacy.get('status', 'UNKNOWN')}",
              f"Potential sensitive patterns: {len(privacy.get('potential_sensitive_patterns', []))}"]
    return "\n".join(lines) + "\n"


def render_quick(snapshot: dict[str, Any]) -> str:
    failed = snapshot["failed_services"]["system"] + snapshot["failed_services"]["user"]
    root_pct, home_pct = snapshot["system"].get("root_usage_pct"), snapshot["system"].get("home_usage_pct")
    degraded = bool(failed) or any(v is not None and v >= 95 for v in (root_pct, home_pct))
    lines = ["OMARCHY CONTEXT QUICK", f"Status: {'DEGRADED' if degraded else 'OK'}",
             f"Omarchy: {snapshot['omarchy'].get('package') or 'unknown'}", f"Failed services: {len(failed)}"]
    lines += [f"  ! {x}" for x in failed[:12]]
    if root_pct is not None: lines.append(f"Root disk: {root_pct}%")
    if home_pct is not None: lines.append(f"Home disk: {home_pct}%")
    lines.append(f"Privacy scan: {snapshot['privacy_scan']['status']}")
    if snapshot["collection"]["incomplete"]:
        lines.append(f"Incomplete checks: {len(snapshot['collection']['incomplete'])}")
    return "\n".join(lines) + "\n"
