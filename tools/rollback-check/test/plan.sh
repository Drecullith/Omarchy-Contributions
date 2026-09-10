#!/bin/bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PLAN="$ROOT/bin/omrollback-plan"
pass_count=0
fail_count=0
pass() { pass_count=$((pass_count+1)); printf 'ok %02d - %s\n' "$pass_count" "$1"; }
fail() { fail_count=$((fail_count+1)); printf 'not ok - %s\n' "$1" >&2; [[ $# -lt 2 ]] || printf '%s\n' "$2" >&2; }

new_fixture() {
  FIX=$(mktemp -d)
  mkdir -p "$FIX/bin"
  cat > "$FIX/bin/omrollback-check" <<'EOF'
#!/bin/bash
case "${TEST_ROLLBACK_STATUS:-clean}" in
  confirmed)
    echo 'INFO: root and home are separate Btrfs mount/subvolume units; a root-only snapshot restore can leave home migration markers untouched.'
    echo 'CONFIRMED: user marker 1786380259.sh exists, but its audited machine-completion marker is missing.'
    exit 1 ;;
  potential)
    echo 'INFO: root and home are separate Btrfs mount/subvolume units; a root-only snapshot restore can leave home migration markers untouched.'
    echo 'POTENTIAL: user migration ledger reaches 1787000000, newer than the restored Omarchy migration tree.'
    exit 1 ;;
  incomplete)
    echo 'INCOMPLETE: Omarchy migrations directory not found.'
    exit 2 ;;
  *)
    echo 'INFO: root and home are separate Btrfs mount/subvolume units; a root-only snapshot restore can leave home migration markers untouched.'
    echo 'Result: no rollback-related inconsistency evidence detected.'
    exit 0 ;;
esac
EOF
  chmod +x "$FIX/bin/omrollback-check"
}

run_plan() {
  local out status
  set +e
  out=$(env PATH="$FIX/bin:$PATH" OMROLLBACK_PLAN_ALLOW_ROOT_FOR_TESTS=1 "$PLAN" "$@" 2>&1)
  status=$?
  set -e
  PLAN_OUT=$out
  PLAN_STATUS=$status
}

make_context() {
  cat > "$1" <<'JSON'
{
  "schema_version": 1,
  "health": "degraded",
  "changes": {
    "packages_added": ["pkg-added"],
    "packages_removed": [],
    "packages_changed": [{"name":"linux","previous":"1","current":"2"}],
    "migrations_added": ["1787000000"],
    "configs_changed": ["hyprland.lua"],
    "failed_services_new": ["demo.service"],
    "failed_services_cleared": [],
    "omarchy": {"commit":{"previous":"aaa","current":"bbb"}}
  },
  "current": {
    "root_usage_pct": 50,
    "home_usage_pct": 60,
    "journal": [],
    "collection_incomplete": [],
    "privacy_scan": {"status":"PASS","potential_sensitive_patterns":[]}
  }
}
JSON
}

out=$("$PLAN" --version)
[[ $out == 'omrollback-plan 1.0.0' ]] && pass 'version output' || fail 'version output' "$out"

new_fixture
run_plan --no-context
[[ $PLAN_STATUS -eq 0 && $PLAN_OUT == *'OMARCHY GUIDED RECOVERY — CLEAN'* && $PLAN_OUT == *'No changes were made.'* ]] && pass 'clean plan is advisory' || fail 'clean plan' "$PLAN_OUT"
rm -rf "$FIX"

new_fixture
TEST_ROLLBACK_STATUS=confirmed run_plan --no-context
[[ $PLAN_STATUS -eq 1 && $PLAN_OUT == *'GUIDED RECOVERY — CONFIRMED'* && $PLAN_OUT == *'Choose one coherent recovery target'* ]] && pass 'confirmed evidence gets bounded recovery sequence' || fail 'confirmed plan' "$PLAN_OUT"
rm -rf "$FIX"

new_fixture
TEST_ROLLBACK_STATUS=potential run_plan --no-context
[[ $PLAN_STATUS -eq 1 && $PLAN_OUT == *'GUIDED RECOVERY — POTENTIAL'* && $PLAN_OUT == *'Do not replay migrations or delete migration markers from POTENTIAL evidence alone.'* ]] && pass 'potential evidence blocks blind replay' || fail 'potential plan' "$PLAN_OUT"
rm -rf "$FIX"

new_fixture
TEST_ROLLBACK_STATUS=incomplete run_plan --no-context
[[ $PLAN_STATUS -eq 2 && $PLAN_OUT == *'GUIDED RECOVERY — INCOMPLETE'* && $PLAN_OUT == *'Restore access to the Omarchy migration tree'* ]] && pass 'incomplete evidence blocks recovery decision' || fail 'incomplete plan' "$PLAN_OUT"
rm -rf "$FIX"

new_fixture
make_context "$FIX/context.json"
run_plan --context-file "$FIX/context.json"
[[ $PLAN_STATUS -eq 0 && $PLAN_OUT == *'Context Snapshot: available'* && $PLAN_OUT == *'2 package, 1 migration, 1 config, 1 new failed service, 1 Omarchy metadata'* && $PLAN_OUT == *'demo.service'* ]] && pass 'context delta is correlated' || fail 'context correlation' "$PLAN_OUT"
rm -rf "$FIX"

new_fixture
make_context "$FIX/context.json"
run_plan --json --context-file "$FIX/context.json"
if [[ $PLAN_STATUS -eq 0 ]] && printf '%s' "$PLAN_OUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["plan_schema_version"]==1; assert d["automatic_actions_permitted"] is False; assert d["context"]["counts"]["package_changes"]==2; assert "demo.service" in d["context"]["evidence"]["failed_services"]'; then
  pass 'json plan contract is valid'
else
  fail 'json plan contract' "$PLAN_OUT"
fi
rm -rf "$FIX"

new_fixture
printf '{"schema_version":999,"changes":{},"current":{}}\n' > "$FIX/context.json"
run_plan --context-file "$FIX/context.json"
[[ $PLAN_STATUS -eq 0 && $PLAN_OUT == *'Context Snapshot: unavailable (unsupported Context Snapshot schema)'* ]] && pass 'unsupported context schema is rejected' || fail 'unsupported context schema' "$PLAN_OUT"
rm -rf "$FIX"

new_fixture
run_plan --context-file "$FIX/missing.json"
[[ $PLAN_STATUS -eq 0 && $PLAN_OUT == *'Context Snapshot: unavailable'* && $PLAN_OUT == *'No such file or directory'* ]] && pass 'missing context file does not invent evidence' || fail 'missing context file' "$PLAN_OUT"
rm -rf "$FIX"

new_fixture
cat > "$FIX/bin/sudo" <<'EOF'
#!/bin/bash
touch "${PLAN_MUTATION_SENTINEL:?}"
exit 99
EOF
cat > "$FIX/bin/snapper" <<'EOF'
#!/bin/bash
touch "${PLAN_MUTATION_SENTINEL:?}"
exit 99
EOF
chmod +x "$FIX/bin/sudo" "$FIX/bin/snapper"
PLAN_MUTATION_SENTINEL="$FIX/MUTATED" run_plan --no-context
[[ $PLAN_STATUS -eq 0 && ! -e "$FIX/MUTATED" ]] && pass 'planner does not invoke privileged or snapshot commands' || fail 'planner mutation guard' "$PLAN_OUT"
rm -rf "$FIX"

new_fixture
run_plan --json --no-context
if [[ $PLAN_STATUS -eq 0 ]] && printf '%s' "$PLAN_OUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["automatic_actions_permitted"] is False; b=" ".join(d["blocked_automatic_actions"]); assert "snapshot" in b and "migration" in b and "configuration" in b'; then
  pass 'automatic action boundary is machine-readable'
else
  fail 'automatic action boundary' "$PLAN_OUT"
fi
rm -rf "$FIX"

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  set +e
  out=$(PATH="$PATH" "$PLAN" --no-context 2>&1); status=$?
  set -e
  [[ $status -eq 2 && $out == *'Do not run omrollback-plan as root'* ]] && pass 'root invocation is refused' || fail 'root refusal' "$out"
else
  pass 'root refusal test skipped when suite is non-root'
fi

printf '\n%d passed, %d failed\n' "$pass_count" "$fail_count"
(( fail_count == 0 ))
