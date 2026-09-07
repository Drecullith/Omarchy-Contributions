#!/bin/bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TOOL="$ROOT/bin/ommigration-check"
pass_count=0
fail_count=0

pass() { pass_count=$((pass_count+1)); printf 'ok %02d - %s\n' "$pass_count" "$1"; }
fail() { fail_count=$((fail_count+1)); printf 'not ok - %s\n' "$1" >&2; [[ $# -lt 2 ]] || printf '%s\n' "$2" >&2; }

new_fixture() {
  FIX=$(mktemp -d)
  mkdir -p "$FIX/home/.config/hypr"
  cat > "$FIX/home/.config/hypr/hyprland.lua" <<'LUA'
require("default.hypr.omarchy")
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")
LUA
  : > "$FIX/home/.config/hypr/bindings.lua"
  : > "$FIX/home/.config/hypr/monitors.lua"
  : > "$FIX/home/.config/hypr/input.lua"
  : > "$FIX/home/.config/hypr/looknfeel.lua"
  : > "$FIX/home/.config/hypr/autostart.lua"
}

run_tool() {
  local out status
  set +e
  out=$(env HOME="$FIX/home" OMMIGRATION_ALLOW_ROOT_FOR_TESTS=1 "$TOOL" 2>&1)
  status=$?
  set -e
  TOOL_OUT=$out
  TOOL_STATUS=$status
}

new_fixture
run_tool
[[ $TOOL_STATUS -eq 0 && $TOOL_OUT == *'no known legacy Hyprland core .conf files detected'* ]] &&
  pass 'clean Quattro config reports no legacy files' || fail 'clean config' "$TOOL_OUT"
rm -rf "$FIX"

new_fixture
cat > "$FIX/home/.config/hypr/bindings.conf" <<'CONF'
binddr = SUPER, GRAVE, Toggle dictation, exec, voxtype record toggle
CONF
run_tool
[[ $TOOL_STATUS -eq 1 && $TOOL_OUT == *'POSSIBLY_IGNORED:'* && $TOOL_OUT == *'bindings.conf'* ]] &&
  pass 'unreferenced binding config is reported as possibly ignored' || fail 'orphaned bindings' "$TOOL_OUT"
rm -rf "$FIX"

new_fixture
cat > "$FIX/home/.config/hypr/input.conf" <<'CONF'
# old notes only

  # another comment
CONF
run_tool
[[ $TOOL_STATUS -eq 0 && $TOOL_OUT == *'LEGACY:'* && $TOOL_OUT != *'POSSIBLY_IGNORED:'* ]] &&
  pass 'comments-only legacy config remains informational' || fail 'comments only' "$TOOL_OUT"
rm -rf "$FIX"

new_fixture
cat > "$FIX/home/.config/hypr/input.conf" <<'CONF'
input {
  kb_options = compose:caps
}
CONF
cat >> "$FIX/home/.config/hypr/input.lua" <<'LUA'
local legacy = "input.conf"
LUA
run_tool
[[ $TOOL_STATUS -eq 1 && $TOOL_OUT == *'INFO:'* && $TOOL_OUT == *'reference only, not proof'* && $TOOL_OUT == *'POSSIBLY_IGNORED:'* ]] &&
  pass 'Lua mention is reported but does not become false proof of activity' || fail 'Lua mention handling' "$TOOL_OUT"
rm -rf "$FIX"

new_fixture
cat > "$FIX/home/.config/hypr/bindings.conf" <<'CONF'
bind = SUPER, X, exec, xterm
CONF
cat >> "$FIX/home/.config/hypr/bindings.lua" <<'LUA'
-- old compatibility: bindings.conf
LUA
run_tool
[[ $TOOL_STATUS -eq 1 && $TOOL_OUT == *'POSSIBLY_IGNORED:'* ]] &&
  pass 'commented Lua mention does not create false active status' || fail 'commented reference' "$TOOL_OUT"
rm -rf "$FIX"

new_fixture
cat > "$FIX/home/.config/hypr/envs.conf" <<'CONF'
env = LIBVA_DRIVER_NAME,nvidia
CONF
cat > "$FIX/home/.config/hypr/looknfeel.conf" <<'CONF'
misc {
  vrr = 2
}
CONF
run_tool
count=$(grep -c '^POSSIBLY_IGNORED:' <<<"$TOOL_OUT" || true)
[[ $TOOL_STATUS -eq 1 && $count -eq 2 ]] &&
  pass 'multiple orphan candidates are reported in one pass' || fail 'multiple legacy files' "$TOOL_OUT"
rm -rf "$FIX"

new_fixture
cat > "$FIX/home/.config/hypr/hyprsunset.conf" <<'CONF'
profile {
  time = 21:00
}
CONF
cat > "$FIX/home/.config/hypr/xdph.conf" <<'CONF'
screencopy {
  max_fps = 60
}
CONF
run_tool
[[ $TOOL_STATUS -eq 0 && $TOOL_OUT != *'hyprsunset.conf'* && $TOOL_OUT != *'xdph.conf'* ]] &&
  pass 'current standalone conf files are not false-positive legacy findings' || fail 'standalone conf exclusion' "$TOOL_OUT"
rm -rf "$FIX"

FIX=$(mktemp -d)
mkdir -p "$FIX/home/.config/hypr"
cat > "$FIX/home/.config/hypr/hyprland.conf" <<'CONF'
source = ~/.config/hypr/bindings.conf
CONF
run_tool
[[ $TOOL_STATUS -eq 0 && $TOOL_OUT == *'ACTIVE: legacy hyprland.conf exists'* && $TOOL_OUT == *'does not match the Lua-provider migration shape'* ]] &&
  pass 'legacy-only provider shape is handled without false alarm' || fail 'legacy provider' "$TOOL_OUT"
rm -rf "$FIX"

FIX=$(mktemp -d)
mkdir -p "$FIX/home"
run_tool
[[ $TOOL_STATUS -eq 2 && $TOOL_OUT == *'INCOMPLETE:'* ]] &&
  pass 'missing Hyprland config directory is incomplete' || fail 'missing directory' "$TOOL_OUT"
rm -rf "$FIX"

FIX=$(mktemp -d)
mkdir -p "$FIX/home/.config/hypr"
run_tool
[[ $TOOL_STATUS -eq 2 && $TOOL_OUT == *'neither Quattro Lua entry point nor legacy hyprland.conf'* ]] &&
  pass 'missing provider entry point is incomplete' || fail 'missing provider' "$TOOL_OUT"
rm -rf "$FIX"

new_fixture
cat > "$FIX/home/.config/hypr/autostart.conf" <<CONF
exec-once = touch "$FIX/EXECUTED"
CONF
run_tool
[[ $TOOL_STATUS -eq 1 && ! -e "$FIX/EXECUTED" ]] &&
  pass 'legacy config content is never executed' || fail 'execution guard' "$TOOL_OUT"
rm -rf "$FIX"

new_fixture
for name in hyprland.conf envs.conf monitors.conf input.conf bindings.conf looknfeel.conf autostart.conf; do
  printf 'setting = test\n' > "$FIX/home/.config/hypr/$name"
done
run_tool
count=$(grep -c '^POSSIBLY_IGNORED:' <<<"$TOOL_OUT" || true)
[[ $TOOL_STATUS -eq 1 && $count -eq 7 ]] &&
  pass 'all v1 legacy core file classes are audited' || fail 'legacy coverage' "$TOOL_OUT"
rm -rf "$FIX"

out=$("$TOOL" version)
[[ $out == 'ommigration-check 1.0.0' ]] && pass 'version output' || fail 'version output' "$out"

set +e
out=$("$TOOL" nonsense 2>&1); status=$?
set -e
[[ $status -eq 2 && $out == *'Usage:'* ]] && pass 'invalid arguments fail safely' || fail 'invalid arguments' "$out"

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  set +e
  out=$(HOME=/tmp "$TOOL" 2>&1); status=$?
  set -e
  [[ $status -eq 2 && $out == *'Do not run ommigration-check as root'* ]] &&
    pass 'root invocation is refused' || fail 'root refusal' "$out"
else
  pass 'root refusal test skipped when suite is non-root'
fi

printf '\n%d passed, %d failed\n' "$pass_count" "$fail_count"
(( fail_count == 0 ))
