from __future__ import annotations

import datetime as dt
import os
import platform
import re
import shutil
from pathlib import Path
from typing import Any

from omcontext_common import privacy_scan, run, safe_unit_name, sanitize_text, sha256_file

CONFIG_TARGETS = {
    "omarchy_shell": ".config/omarchy/shell.json",
    "hyprland_entry": ".config/hypr/hyprland.lua",
    "hypr_monitors": ".config/hypr/monitors.lua",
    "hypr_input": ".config/hypr/input.lua",
    "hypr_bindings": ".config/hypr/bindings.lua",
    "hypr_looknfeel": ".config/hypr/looknfeel.lua",
    "hypr_autostart": ".config/hypr/autostart.lua",
}


def package_map(incomplete: list[str]) -> dict[str, str]:
    rc, out = run(["pacman", "-Q"], timeout=15)
    if rc != 0:
        incomplete.append("packages: pacman -Q unavailable")
        return {}
    result: dict[str, str] = {}
    for line in out.splitlines():
        parts = line.split(maxsplit=1)
        if len(parts) == 2 and re.fullmatch(r"[A-Za-z0-9@._+\-]+", parts[0]):
            result[parts[0]] = parts[1][:160]
    return dict(sorted(result.items()))


def omarchy_info(incomplete: list[str], home: Path) -> dict[str, Any]:
    package = None
    for candidate in ("omarchy-dev", "omarchy"):
        rc, out = run(["pacman", "-Q", candidate])
        if rc == 0 and out:
            package = sanitize_text(out, home)
            break
    if package is None:
        incomplete.append("omarchy_package: not reported by pacman")

    omarchy_path = Path(os.environ.get(
        "OMCONTEXT_OMARCHY_PATH", os.environ.get("OMARCHY_PATH", "/usr/share/omarchy")
    ))
    commit = None
    if (omarchy_path / ".git").exists():
        rc, out = run(["git", "-C", str(omarchy_path), "rev-parse", "HEAD"])
        if rc == 0 and re.fullmatch(r"[0-9a-f]{40}", out):
            commit = out
        else:
            incomplete.append("omarchy_commit: git revision unavailable")

    theme = None
    theme_path = home / ".local/state/omarchy/current/theme"
    try:
        if theme_path.is_symlink():
            theme = Path(os.readlink(theme_path)).name[:120]
        elif theme_path.is_dir():
            theme = "current"
    except OSError:
        incomplete.append("omarchy_theme: unreadable")
    return {"package": package, "commit": commit, "theme": theme}


def migration_markers(home: Path, incomplete: list[str]) -> list[str]:
    directory = Path(os.environ.get(
        "OMCONTEXT_MIGRATIONS_DIR", str(home / ".local/state/omarchy/migrations")
    ))
    if not directory.exists():
        return []
    try:
        ids = []
        for item in directory.iterdir():
            if item.is_file():
                name = item.name.removesuffix(".sh")
                if re.fullmatch(r"\d{8,}", name): ids.append(name)
        return sorted(set(ids), key=int)
    except OSError:
        incomplete.append("migrations: user migration ledger unreadable")
        return []


def failed_units(user: bool, incomplete: list[str]) -> list[str]:
    cmd = ["systemctl"] + (["--user"] if user else []) + [
        "--failed", "--no-legend", "--plain", "--no-pager"
    ]
    rc, out = run(cmd)
    label = "user" if user else "system"
    if rc not in (0, 1):
        incomplete.append(f"failed_services_{label}: systemctl unavailable")
        return []
    units = []
    for line in out.splitlines():
        if line.strip():
            clean = safe_unit_name(line.split()[0])
            if clean: units.append(clean)
    return sorted(set(units))


def config_fingerprints(home: Path, incomplete: list[str]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for label, rel in CONFIG_TARGETS.items():
        path = home / rel
        entry: dict[str, Any] = {"exists": False, "sha256": None}
        try:
            if path.is_file() and not path.is_symlink():
                entry = {"exists": True, "sha256": sha256_file(path)}
            elif path.is_symlink():
                entry = {"exists": True, "sha256": None, "note": "symlink-not-followed"}
        except OSError:
            incomplete.append(f"config_{label}: unreadable")
        result[label] = entry
    return result


def journal_errors(home: Path, incomplete: list[str]) -> list[str]:
    fixture = os.environ.get("OMCONTEXT_JOURNAL_FIXTURE")
    if fixture is not None:
        source = fixture
    else:
        rc, source = run([
            "journalctl", "-b", "-p", "4..1", "--no-hostname", "--no-pager", "-n", "40", "-o", "cat"
        ], timeout=8)
        if rc not in (0, 1):
            incomplete.append("journal: current-boot warning/error sample unavailable")
            return []
    lines = []
    for raw in source.splitlines():
        clean = sanitize_text(raw.strip(), home)
        if clean and clean not in lines: lines.append(clean)
        if len(lines) >= 40: break
    return lines


def disk_percent(path: Path) -> int | None:
    try:
        usage = shutil.disk_usage(path)
        return round((usage.used / usage.total) * 100) if usage.total else None
    except OSError:
        return None


def collect_snapshot(version: str, schema_version: int) -> dict[str, Any]:
    home = Path.home().resolve()
    incomplete: list[str] = []
    captured = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    snapshot: dict[str, Any] = {
        "schema_version": schema_version,
        "tool": {"name": "omcontext", "version": version},
        "captured_at": captured,
        "system": {
            "kernel": platform.release(), "architecture": platform.machine(),
            "root_usage_pct": disk_percent(Path("/")), "home_usage_pct": disk_percent(home),
        },
        "omarchy": omarchy_info(incomplete, home),
        "packages": package_map(incomplete),
        "migrations": migration_markers(home, incomplete),
        "failed_services": {"system": failed_units(False, incomplete), "user": failed_units(True, incomplete)},
        "configs": config_fingerprints(home, incomplete),
        "journal": journal_errors(home, incomplete),
        "collection": {"incomplete": sorted(set(incomplete))},
    }
    snapshot["privacy_scan"] = privacy_scan(snapshot, home)
    return snapshot
