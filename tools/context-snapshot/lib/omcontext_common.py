from __future__ import annotations

import hashlib
import json
import os
import re
import stat
import subprocess
import tempfile
from pathlib import Path
from typing import Any

VERSION = "1.0.0"
SCHEMA_VERSION = 1

TOKENISH_RE = re.compile(r"(?i)\b(?:bearer\s+)?[A-Za-z0-9_\-]{40,}\b")
EMAIL_RE = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
IPV4_RE = re.compile(r"(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])")
MAC_RE = re.compile(r"(?i)\b(?:[0-9a-f]{2}:){5}[0-9a-f]{2}\b")
HOME_PATH_RE = re.compile(r"(?<![A-Za-z0-9_])/(?:home/[^/\s]+|root)(?=/|\s|$)")
SECRET_ASSIGN_RE = re.compile(
    r"(?i)\b(password|passwd|token|secret|api[_-]?key|authorization|cookie)\b\s*[:=]\s*([^\s,;]+)"
)


def run(cmd: list[str], timeout: int = 5) -> tuple[int, str]:
    try:
        cp = subprocess.run(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            text=True, timeout=timeout, check=False,
            env={**os.environ, "LC_ALL": "C"},
        )
        return cp.returncode, cp.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return 127, ""


def sanitize_text(value: str, home: Path) -> str:
    text = value.replace(str(home), "$HOME")
    text = HOME_PATH_RE.sub("$HOME", text)
    text = EMAIL_RE.sub("[redacted-email]", text)
    text = MAC_RE.sub("[redacted-mac]", text)
    text = IPV4_RE.sub("[redacted-ip]", text)
    text = SECRET_ASSIGN_RE.sub(lambda m: f"{m.group(1)}=[redacted]", text)
    text = TOKENISH_RE.sub("[redacted-token]", text)
    return text[:800]


def safe_unit_name(value: str) -> str | None:
    pat = r"[A-Za-z0-9_.@:\\-]+\.(?:service|socket|mount|timer|path|target|scope|slice|device|swap|automount)"
    return value if re.fullmatch(pat, value) else None


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def get_state_dir() -> Path:
    override = os.environ.get("OMCONTEXT_STATE_DIR")
    if override:
        return Path(override)
    base = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
    return base / "omcontext"


def ensure_state_dir(path: Path) -> None:
    if path.exists() and path.is_symlink():
        raise RuntimeError(f"Refusing symlinked state directory: {path}")
    path.mkdir(parents=True, mode=0o700, exist_ok=True)
    if stat.S_IMODE(path.stat().st_mode) & 0o077:
        path.chmod(0o700)
    history = path / "history"
    if history.exists() and history.is_symlink():
        raise RuntimeError(f"Refusing symlinked history directory: {history}")
    history.mkdir(mode=0o700, exist_ok=True)
    history.chmod(0o700)


def atomic_json(path: Path, payload: dict[str, Any]) -> None:
    root = path.parent if path.parent.name != "history" else path.parent.parent
    ensure_state_dir(root)
    fd, tmp = tempfile.mkstemp(prefix=".omcontext-", dir=str(path.parent), text=True)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2, sort_keys=True)
            fh.write("\n")
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp, path)
        path.chmod(0o600)
    finally:
        try:
            os.unlink(tmp)
        except FileNotFoundError:
            pass


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as fh:
        data = json.load(fh)
    if data.get("schema_version") != SCHEMA_VERSION:
        raise RuntimeError(f"Unsupported snapshot schema in {path}: {data.get('schema_version')!r}")
    return data


def iter_strings(value: Any, path: tuple[str, ...] = ()):
    if isinstance(value, str):
        yield path, value
    elif isinstance(value, dict):
        for key, child in value.items():
            yield from iter_strings(child, path + (str(key),))
    elif isinstance(value, list):
        for idx, child in enumerate(value):
            yield from iter_strings(child, path + (str(idx),))


def privacy_scan(snapshot: dict[str, Any], home: Path) -> dict[str, Any]:
    findings: list[str] = []
    home_str = str(home)
    for path, text in iter_strings(snapshot):
        if path and path[-1] in {"sha256", "commit"}:
            continue
        if home_str and home_str in text:
            findings.append("home-path")
        if EMAIL_RE.search(text): findings.append("email")
        if MAC_RE.search(text): findings.append("mac")
        if IPV4_RE.search(text): findings.append("ipv4")
        if SECRET_ASSIGN_RE.search(text) and "[redacted]" not in text:
            findings.append("credential-like-assignment")
    unique = sorted(set(findings))
    return {"status": "PASS" if not unique else "REVIEW", "potential_sensitive_patterns": unique}
