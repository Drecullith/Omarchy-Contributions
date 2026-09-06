#!/bin/bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/bin/omrescue"
run_bin() { bash "$BIN" "$@"; }
PASS=0
FAIL=0

ok() { printf 'ok - %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf 'not ok - %s\n' "$1" >&2; FAIL=$((FAIL+1)); }
assert_jq() {
  local desc=$1 expr=$2 file=$3
  if jq -e "$expr" "$file" >/dev/null; then ok "$desc"; else bad "$desc"; fi
}
assert_eq_file() {
  local desc=$1 a=$2 b=$3
  if cmp -s "$a" "$b"; then ok "$desc"; else
    bad "$desc"; diff -u "$a" "$b" || true
  fi
}

new_env() {
  TESTROOT=$(mktemp -d)
  export HOME="$TESTROOT/home"
  export XDG_STATE_HOME="$TESTROOT/state"
  mkdir -p "$HOME/.config/omarchy/plugins"
}
cleanup() { rm -rf "${TESTROOT:-}"; }
trap cleanup EXIT

# 1. Standard third-party service/widget/bar are removed without touching built-ins.
new_env
cat > "$HOME/.config/omarchy/shell.json" <<'JSON'
{
  "version": 1,
  "idle": {"lock": 333},
  "bar": {
    "id": "third.bar",
    "centerAnchor": "third.widget",
    "layout": {
      "left": [{"id":"omarchy.menu"},{"id":"third.widget","x":1}],
      "center": [{"id":"omarchy.clock"}],
      "right": ["third.stale", {"id":"omarchy.power"}]
    }
  },
  "plugins": [{"id":"third.service","setting":true},{"id":"omarchy.settings"}],
  "disabledPlugins": ["omarchy.weather"]
}
JSON
mkdir -p "$HOME/.config/omarchy/plugins/third.bar" "$HOME/.config/omarchy/plugins/third.widget" "$HOME/.config/omarchy/plugins/third.service"
cat > "$HOME/.config/omarchy/plugins/third.bar/manifest.json" <<'JSON'
{"schemaVersion":1,"id":"third.bar","name":"Bar","version":"1","kinds":["bar"],"entryPoints":{"bar":"Bar.qml"}}
JSON
cat > "$HOME/.config/omarchy/plugins/third.widget/manifest.json" <<'JSON'
{"schemaVersion":1,"id":"third.widget","name":"Widget","version":"1","kinds":["bar-widget"],"entryPoints":{"bar-widget":"Widget.qml"}}
JSON
cat > "$HOME/.config/omarchy/plugins/third.service/manifest.json" <<'JSON'
{"schemaVersion":1,"id":"third.service","name":"Service","version":"1","kinds":["service"],"entryPoints":{"service":"Service.qml"}}
JSON
cp "$HOME/.config/omarchy/shell.json" "$TESTROOT/original.json"
run_bin rescue --no-restart >/dev/null
assert_jq "third-party full bar falls back to built-in" '(.bar.id? // "") == ""' "$HOME/.config/omarchy/shell.json"
assert_jq "third-party widgets removed, including stale IDs" '[.bar.layout.left[],.bar.layout.center[],.bar.layout.right[] | (if type=="object" then .id else . end)] | all(.[]; startswith("third.")|not)' "$HOME/.config/omarchy/shell.json"
assert_jq "third-party service removed" '[.plugins[].id] | index("third.service") == null' "$HOME/.config/omarchy/shell.json"
assert_jq "first-party config and idle setting preserved" '.idle.lock == 333 and (.disabledPlugins | index("omarchy.weather") != null) and ([.plugins[].id] | index("omarchy.settings") != null)' "$HOME/.config/omarchy/shell.json"
run_bin restore --no-restart >/dev/null
assert_eq_file "restore returns exact original shell.json" "$TESTROOT/original.json" "$HOME/.config/omarchy/shell.json"
cleanup

# 2. An active clone is replaced by its built-in source and source is un-disabled.
new_env
cat > "$HOME/.config/omarchy/shell.json" <<'JSON'
{
  "version":1,
  "bar": {
    "centerAnchor":"example.clock",
    "layout":{"left":[],"center":[{"id":"example.clock","format":"HH:mm:ss"}],"right":[]}
  },
  "plugins":[],
  "disabledPlugins":["omarchy.clock","omarchy.weather"],
  "cloneSourceRestores":["example.clock"]
}
JSON
mkdir -p "$HOME/.config/omarchy/plugins/example.clock"
cat > "$HOME/.config/omarchy/plugins/example.clock/manifest.json" <<'JSON'
{"schemaVersion":1,"id":"example.clock","name":"My Clock","version":"1","kinds":["bar-widget"],"entryPoints":{"bar-widget":"Widget.qml"},"omarchy":{"clonedFrom":"omarchy.clock"}}
JSON
run_bin --no-restart >/dev/null
assert_jq "clone widget restored to first-party source with settings preserved" '.bar.layout.center[0].id == "omarchy.clock" and .bar.layout.center[0].format == "HH:mm:ss"' "$HOME/.config/omarchy/shell.json"
assert_jq "clone center anchor restored" '.bar.centerAnchor == "omarchy.clock"' "$HOME/.config/omarchy/shell.json"
assert_jq "active clone source temporarily re-enabled" '(.disabledPlugins | index("omarchy.clock")) == null and (.disabledPlugins | index("omarchy.weather")) != null' "$HOME/.config/omarchy/shell.json"
assert_jq "clone restore bookkeeping removed in safe config" 'has("cloneSourceRestores") | not' "$HOME/.config/omarchy/shell.json"
cleanup

# 3. A cloned full bar returns to the original bar option.
new_env
cat > "$HOME/.config/omarchy/shell.json" <<'JSON'
{"version":1,"bar":{"id":"example.bar","layout":{"left":[],"center":[],"right":[]}},"plugins":[]}
JSON
mkdir -p "$HOME/.config/omarchy/plugins/example.bar"
cat > "$HOME/.config/omarchy/plugins/example.bar/manifest.json" <<'JSON'
{"schemaVersion":1,"id":"example.bar","name":"My Bar","version":"1","kinds":["bar"],"entryPoints":{"bar":"Bar.qml"},"omarchy":{"clonedFrom":"omarchy.bar"}}
JSON
run_bin rescue --no-restart >/dev/null
assert_jq "cloned built-in bar falls back by removing bar.id" '(.bar.id? // "") == ""' "$HOME/.config/omarchy/shell.json"
cleanup

# 4. Restore refuses to overwrite config changes unless forced.
new_env
cat > "$HOME/.config/omarchy/shell.json" <<'JSON'
{"version":1,"bar":{"layout":{"left":[{"id":"third.widget"}],"center":[],"right":[]}},"plugins":[]}
JSON
run_bin rescue --no-restart >/dev/null
jq '.idle={"lock":999}' "$HOME/.config/omarchy/shell.json" > "$TESTROOT/changed" && mv "$TESTROOT/changed" "$HOME/.config/omarchy/shell.json"
if run_bin restore --no-restart >/dev/null 2>&1; then bad "restore refuses changed safe config"; else ok "restore refuses changed safe config"; fi
run_bin restore --force --no-restart >/dev/null 2>&1
assert_jq "forced restore returns original third-party reference" '.bar.layout.left[0].id == "third.widget"' "$HOME/.config/omarchy/shell.json"
cleanup

# 5. Invalid manifest is ignored but stale config ID is still rescued.
new_env
cat > "$HOME/.config/omarchy/shell.json" <<'JSON'
{"version":1,"bar":{"layout":{"left":[],"center":[],"right":[]}},"plugins":[{"id":"broken.plugin"}]}
JSON
mkdir -p "$HOME/.config/omarchy/plugins/broken.plugin"
printf '{not-json' > "$HOME/.config/omarchy/plugins/broken.plugin/manifest.json"
run_bin rescue --no-restart >/dev/null 2>/dev/null
assert_jq "stale ID rescued even when manifest is malformed" '.plugins | length == 0' "$HOME/.config/omarchy/shell.json"
cleanup

# 6. No config and no third-party references are harmless no-ops.
new_env
run_bin rescue --no-restart >/dev/null
ok "missing shell.json is a harmless no-op"
mkdir -p "$HOME/.config/omarchy"
cat > "$HOME/.config/omarchy/shell.json" <<'JSON'
{"version":1,"bar":{"layout":{"left":[{"id":"omarchy.menu"}],"center":[{"id":"omarchy.clock"}],"right":[]}},"plugins":[]}
JSON
before=$(sha256sum "$HOME/.config/omarchy/shell.json" | awk '{print $1}')
run_bin rescue --no-restart >/dev/null
after=$(sha256sum "$HOME/.config/omarchy/shell.json" | awk '{print $1}')
if [[ $before == "$after" ]]; then ok "first-party-only config is unchanged"; else bad "first-party-only config is unchanged"; fi

# 7. Hostile clone metadata cannot preserve another third-party plugin.
cleanup
new_env
cat > "$HOME/.config/omarchy/shell.json" <<'JSON'
{"version":1,"bar":{"layout":{"left":[{"id":"evil.clone"}],"center":[],"right":[]}},"plugins":[]}
JSON
mkdir -p "$HOME/.config/omarchy/plugins/evil.clone"
cat > "$HOME/.config/omarchy/plugins/evil.clone/manifest.json" <<'JSON'
{"schemaVersion":1,"id":"evil.clone","name":"Evil","version":"1","kinds":["bar-widget"],"entryPoints":{"bar-widget":"Widget.qml"},"omarchy":{"clonedFrom":"evil.other"}}
JSON
run_bin rescue --no-restart >/dev/null
assert_jq "untrusted clonedFrom cannot activate another third-party id" '.bar.layout.left | length == 0' "$HOME/.config/omarchy/shell.json"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
