#!/bin/bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TOOL="$ROOT/bin/omcontext"
pass_count=0
fail_count=0

pass() { pass_count=$((pass_count+1)); printf 'ok %02d - %s\n' "$pass_count" "$1"; }
fail() { fail_count=$((fail_count+1)); printf 'not ok - %s\n' "$1" >&2; [[ $# -lt 2 ]] || printf '%s\n' "$2" >&2; }

new_fixture() {
  FIX=$(mktemp -d)
  mkdir -p "$FIX/home/.config/omarchy" "$FIX/home/.config/hypr" \
    "$FIX/home/.local/state/omarchy/migrations" "$FIX/bin"
  printf '{"bar":"top"}\n' > "$FIX/home/.config/omarchy/shell.json"
  printf 'require("default.hypr.omarchy")\n' > "$FIX/home/.config/hypr/hyprland.lua"
  for f in monitors input bindings looknfeel autostart; do : > "$FIX/home/.config/hypr/$f.lua"; done

  cat > "$FIX/packages" <<'PKG'
omarchy 4.0.2-1
linux 6.16.1-1
bash 5.3.3-1
PKG
  : > "$FIX/system-failed"
  : > "$FIX/user-failed"

  cat > "$FIX/bin/pacman" <<'CMD'
#!/bin/bash
if [[ $1 == -Q && $# -eq 1 ]]; then
  cat "$OMCONTEXT_TEST_ROOT/packages"
elif [[ $1 == -Q && $# -eq 2 ]]; then
  grep -E "^$2 " "$OMCONTEXT_TEST_ROOT/packages" || exit 1
else
  exit 1
fi
CMD

  cat > "$FIX/bin/systemctl" <<'CMD'
#!/bin/bash
if [[ ${1:-} == --user ]]; then
  cat "$OMCONTEXT_TEST_ROOT/user-failed"
else
  cat "$OMCONTEXT_TEST_ROOT/system-failed"
fi
CMD

  cat > "$FIX/bin/journalctl" <<'CMD'
#!/bin/bash
printf '%s\n' "${OMCONTEXT_JOURNAL_FIXTURE:-}"
CMD

  chmod +x "$FIX/bin"/*
}

run_tool() {
  local out status
  set +e
  out=$(env \
    HOME="$FIX/home" \
    PATH="$FIX/bin:/usr/bin:/bin" \
    OMCONTEXT_TEST_ROOT="$FIX" \
    OMCONTEXT_STATE_DIR="$FIX/state" \
    OMCONTEXT_OMARCHY_PATH="$FIX/omarchy" \
    OMCONTEXT_ALLOW_ROOT_FOR_TESTS=1 \
    "$TOOL" "$@" 2>&1)
  status=$?
  set -e
  TOOL_OUT=$out
  TOOL_STATUS=$status
}

new_fixture
run_tool quick
[[ $TOOL_STATUS -eq 0 && $TOOL_OUT == *'OMARCHY CONTEXT QUICK'* && $TOOL_OUT == *'Status: OK'* ]] &&
  pass 'quick snapshot reports healthy fixture' || fail 'quick snapshot' "$TOOL_OUT"

run_tool baseline
[[ $TOOL_STATUS -eq 0 && -f "$FIX/state/baseline.json" && $TOOL_OUT == *'Privacy scan: PASS'* ]] &&
  pass 'baseline is saved with passing privacy scan' || fail 'baseline creation' "$TOOL_OUT"

mode=$(stat -c '%a' "$FIX/state")
file_mode=$(stat -c '%a' "$FIX/state/baseline.json")
[[ $mode == 700 && $file_mode == 600 ]] &&
  pass 'state directory and snapshots use private permissions' || fail 'state permissions' "$mode / $file_mode"

python3 - "$FIX/state/baseline.json" <<'PY'
import json, sys
p=json.load(open(sys.argv[1]))
assert p['schema_version'] == 1
assert p['tool']['version'] == '1.0.0'
assert 'hostname' not in p
assert p['packages']['linux'] == '6.16.1-1'
PY
pass 'baseline JSON uses schema v1 without hostname'

printf 'omarchy 4.0.2-1\nlinux 6.16.2-1\nbash 5.3.3-1\nripgrep 14.1.1-1\n' > "$FIX/packages"
touch "$FIX/home/.local/state/omarchy/migrations/1788999999.sh"
printf '{"bar":"bottom"}\n' > "$FIX/home/.config/omarchy/shell.json"
printf 'example.service loaded failed failed Example\n' > "$FIX/user-failed"
run_tool incident
[[ $TOOL_STATUS -eq 1 && $TOOL_OUT == *'Status: DEGRADED'* && \
   $TOOL_OUT == *'linux: 6.16.1-1 -> 6.16.2-1'* && \
   $TOOL_OUT == *'ripgrep'* && \
   $TOOL_OUT == *'1788999999'* && \
   $TOOL_OUT == *'omarchy_shell'* && \
   $TOOL_OUT == *'example.service'* ]] &&
  pass 'incident correlates package, migration, config, and service changes' || fail 'incident delta' "$TOOL_OUT"

run_tool diff --json
[[ $TOOL_STATUS -eq 1 ]] || fail 'json diff exit status' "$TOOL_OUT"
python3 -c 'import json,sys; p=json.loads(sys.stdin.read()); assert p["health"]=="degraded"; assert p["changes"]["packages_changed"][0]["name"]=="linux"' <<<"$TOOL_OUT"
pass 'diff emits machine-readable Lychnos-ready JSON'

run_tool show latest
python3 -c 'import json,sys; p=json.loads(sys.stdin.read()); assert p["schema_version"]==1; assert p["failed_services"]["user"]==["example.service"]' <<<"$TOOL_OUT"
pass 'show latest returns the stored sanitized snapshot'

rm -rf "$FIX"
new_fixture
export OMCONTEXT_JOURNAL_FIXTURE='login failed for /home/alice at 192.168.1.44 user alice@example.com token=supersecretvalue aa:bb:cc:dd:ee:ff'
run_tool quick --json
unset OMCONTEXT_JOURNAL_FIXTURE
[[ $TOOL_STATUS -eq 0 ]] || fail 'privacy fixture collection' "$TOOL_OUT"
[[ $TOOL_OUT != *'/home/alice'* && $TOOL_OUT != *'192.168.1.44'* && $TOOL_OUT != *'alice@example.com'* && $TOOL_OUT != *'supersecretvalue'* && $TOOL_OUT != *'aa:bb:cc:dd:ee:ff'* && \
   $TOOL_OUT == *'[redacted-ip]'* && $TOOL_OUT == *'[redacted-email]'* && $TOOL_OUT == *'[redacted-mac]'* ]] &&
  pass 'journal sample redacts home/IP/email/MAC identifiers' || fail 'journal redaction' "$TOOL_OUT"

run_tool baseline
printf 'authorization=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\n' > "$FIX/home/.config/hypr/input.lua"
run_tool incident --json
[[ $TOOL_OUT != *'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'* ]] &&
  pass 'config contents are fingerprinted rather than copied' || fail 'config content leakage' "$TOOL_OUT"

rm -rf "$FIX"
new_fixture
mkdir -p "$FIX/real-state"
ln -s "$FIX/real-state" "$FIX/state"
run_tool quick
[[ $TOOL_STATUS -eq 2 && $TOOL_OUT == *'Refusing symlinked state directory'* ]] &&
  pass 'symlinked state directory is refused' || fail 'state symlink refusal' "$TOOL_OUT"

rm -rf "$FIX"
new_fixture
set +e
out=$(env HOME="$FIX/home" PATH="$FIX/bin:/usr/bin:/bin" OMCONTEXT_STATE_DIR="$FIX/state" "$TOOL" quick 2>&1)
status=$?
set -e
if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  [[ $status -eq 2 && $out == *'Do not run omcontext as root'* ]] &&
    pass 'root invocation is refused' || fail 'root refusal' "$out"
else
  pass 'root refusal test skipped when suite is non-root'
fi

run_tool --version
[[ $TOOL_STATUS -eq 0 && $TOOL_OUT == 'omcontext 1.0.0' ]] && pass 'version output' || fail 'version output' "$TOOL_OUT"

run_tool incident
[[ $TOOL_STATUS -eq 2 && $TOOL_OUT == *'No baseline found'* ]] && pass 'incident requires a known-good baseline' || fail 'missing baseline' "$TOOL_OUT"

run_tool diff
[[ $TOOL_STATUS -eq 2 && $TOOL_OUT == *'Need both baseline and latest snapshots'* ]] && pass 'diff requires baseline and latest' || fail 'missing diff state' "$TOOL_OUT"

rm -rf "$FIX"
printf '\n%d passed, %d failed\n' "$pass_count" "$fail_count"
(( fail_count == 0 ))
