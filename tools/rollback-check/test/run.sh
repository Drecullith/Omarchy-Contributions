#!/bin/bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TOOL="$ROOT/bin/omrollback-check"
pass_count=0
fail_count=0

pass() { pass_count=$((pass_count+1)); printf 'ok %02d - %s\n' "$pass_count" "$1"; }
fail() { fail_count=$((fail_count+1)); printf 'not ok - %s\n' "$1" >&2; [[ $# -lt 2 ]] || printf '%s\n' "$2" >&2; }

new_fixture() {
  FIX=$(mktemp -d)
  mkdir -p "$FIX/home/.local/state/omarchy/migrations" "$FIX/omarchy/migrations" "$FIX/system-markers" "$FIX/bin"
  cat > "$FIX/bin/findmnt" <<'SH'
#!/bin/bash
field=""; target=""
while (($#)); do
  case "$1" in
    -o) field=$2; shift 2 ;;
    --target) target=$2; shift 2 ;;
    -n) shift ;;
    *) shift ;;
  esac
done
case "$field:$target" in
  FSTYPE:/) printf '%s\n' "${TEST_ROOT_FSTYPE:-btrfs}" ;;
  FSTYPE:*) printf '%s\n' "${TEST_HOME_FSTYPE:-btrfs}" ;;
  SOURCE:/) printf '%s\n' "${TEST_ROOT_SOURCE:-/dev/test[/@]}" ;;
  SOURCE:*) printf '%s\n' "${TEST_HOME_SOURCE:-/dev/test[/@home]}" ;;
  FSROOT:/) printf '%s\n' "${TEST_ROOT_FSROOT:-/@}" ;;
  FSROOT:*) printf '%s\n' "${TEST_HOME_FSROOT:-/@home}" ;;
  *) exit 1 ;;
esac
SH
  chmod +x "$FIX/bin/findmnt"
}

run_tool() {
  local out status
  local -a env_args=(
    "PATH=$FIX/bin:$PATH"
    "HOME=$FIX/home"
    "OMROLLBACK_ALLOW_ROOT_FOR_TESTS=1"
    "OMROLLBACK_OMARCHY_PATH=$FIX/omarchy"
    "OMROLLBACK_SYSTEM_STATE_DIR=$FIX/system-markers"
  )
  if [[ -n ${OMROLLBACK_TEST_AUDITED_BLOB:-} ]]; then
    env_args+=("OMROLLBACK_TEST_AUDITED_BLOB=$OMROLLBACK_TEST_AUDITED_BLOB")
  fi

  set +e
  out=$(env "${env_args[@]}" "$TOOL" 2>&1)
  status=$?
  set -e
  TOOL_OUT=$out
  TOOL_STATUS=$status
}

make_audited_fixture() {
  local id=${1:-1786380259}
  cat > "$FIX/omarchy/migrations/$id.sh" <<'SH'
#!/bin/bash
# test fixture: never executed
exit 99
SH
  touch "$FIX/home/.local/state/omarchy/migrations/$id.sh"
  OMROLLBACK_TEST_AUDITED_BLOB=$(GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git hash-object --no-filters -- "$FIX/omarchy/migrations/$id.sh")
}

# 1 clean split layout
new_fixture
printf '#!/bin/bash\n' > "$FIX/omarchy/migrations/1786000000.sh"
touch "$FIX/home/.local/state/omarchy/migrations/1786000000.sh"
run_tool
[[ $TOOL_STATUS -eq 0 && $TOOL_OUT == *'no rollback-related inconsistency evidence detected'* ]] && pass 'clean split layout reports no evidence' || fail 'clean split layout' "$TOOL_OUT"
rm -rf "$FIX"

# 2 same rollback unit
new_fixture
printf '#!/bin/bash\n' > "$FIX/omarchy/migrations/1786000000.sh"
touch "$FIX/home/.local/state/omarchy/migrations/1786000000.sh"
TEST_HOME_SOURCE='/dev/test[/@]' TEST_HOME_FSROOT='/@' run_tool
[[ $TOOL_STATUS -eq 0 && $TOOL_OUT == *'does not appear separate'* ]] && pass 'same root/home unit is recognized' || fail 'same rollback unit' "$TOOL_OUT"
rm -rf "$FIX"

# 3 future user marker + split layout => potential
new_fixture
printf '#!/bin/bash\n' > "$FIX/omarchy/migrations/1786000000.sh"
touch "$FIX/home/.local/state/omarchy/migrations/1787000000.sh"
run_tool
[[ $TOOL_STATUS -eq 1 && $TOOL_OUT == *'POTENTIAL:'* && $TOOL_OUT != *'CONFIRMED:'* ]] && pass 'newer user ledger is potential drift on split layout' || fail 'future marker potential' "$TOOL_OUT"
rm -rf "$FIX"

# 4 future user marker + same unit => info only, not rollback evidence
new_fixture
printf '#!/bin/bash\n' > "$FIX/omarchy/migrations/1786000000.sh"
touch "$FIX/home/.local/state/omarchy/migrations/1787000000.sh"
TEST_HOME_SOURCE='/dev/test[/@]' TEST_HOME_FSROOT='/@' run_tool
[[ $TOOL_STATUS -eq 0 && $TOOL_OUT != *'POTENTIAL:'* && $TOOL_OUT == *'no rollback finding was emitted'* ]] && pass 'timeline mismatch does not blame rollback without split layout' || fail 'same-unit future marker' "$TOOL_OUT"
rm -rf "$FIX"

# 5 audited machine marker present => consistent
new_fixture
make_audited_fixture 1786380259
touch "$FIX/system-markers/1786380259"
run_tool
[[ $TOOL_STATUS -eq 0 && $TOOL_OUT != *'CONFIRMED:'* ]] && pass 'audited machine completion marker present is consistent' || fail 'audited marker present' "$TOOL_OUT"
unset OMROLLBACK_TEST_AUDITED_BLOB
rm -rf "$FIX"

# 6 audited machine marker missing + exact audited blob => confirmed
new_fixture
make_audited_fixture 1786380259
run_tool
[[ $TOOL_STATUS -eq 1 && $TOOL_OUT == *'CONFIRMED:'* && $TOOL_OUT == *'1786380259'* ]] && pass 'audited missing machine marker is confirmed mismatch' || fail 'audited marker missing' "$TOOL_OUT"
unset OMROLLBACK_TEST_AUDITED_BLOB
rm -rf "$FIX"

# 7 changed audited migration revision => never claim direct proof
new_fixture
make_audited_fixture 1786380259
OMROLLBACK_TEST_AUDITED_BLOB=0000000000000000000000000000000000000000
run_tool
[[ $TOOL_STATUS -eq 0 && $TOOL_OUT != *'CONFIRMED:'* && $TOOL_OUT == *'differs from the v1 audited invariant'* ]] && pass 'changed migration revision disables confirmed proof' || fail 'changed audited revision' "$TOOL_OUT"
unset OMROLLBACK_TEST_AUDITED_BLOB
rm -rf "$FIX"

# 8 conditional machine marker is not assumed to be completion proof
new_fixture
cat > "$FIX/omarchy/migrations/1786482992.sh" <<'SH'
#!/bin/bash
rebuild_marker="${X:-/var/lib/omarchy/migrations/1786482992}"
command -v imaginary-tool >/dev/null || exit 0
touch "$rebuild_marker"
SH
touch "$FIX/home/.local/state/omarchy/migrations/1786482992.sh"
run_tool
[[ $TOOL_STATUS -eq 0 && $TOOL_OUT != *'CONFIRMED:'* ]] && pass 'conditional machine markers cannot create false confirmation' || fail 'conditional marker false positive' "$TOOL_OUT"
rm -rf "$FIX"

# 9 temporary machine-marker suffix is ignored
new_fixture
cat > "$FIX/omarchy/migrations/1788102906.sh" <<'SH'
#!/bin/bash
reload_marker_prefix=/var/lib/omarchy/migrations/1788102906-udev-reload-needed
rm -f "$reload_marker_prefix"
SH
touch "$FIX/home/.local/state/omarchy/migrations/1788102906.sh"
run_tool
[[ $TOOL_STATUS -eq 0 && $TOOL_OUT != *'CONFIRMED:'* ]] && pass 'temporary machine markers cannot create false confirmation' || fail 'temporary marker false positive' "$TOOL_OUT"
rm -rf "$FIX"

# 10 older orphan marker alone is not treated as drift
new_fixture
printf '#!/bin/bash\n' > "$FIX/omarchy/migrations/1787000000.sh"
touch "$FIX/home/.local/state/omarchy/migrations/1786000000.sh"
run_tool
[[ $TOOL_STATUS -eq 0 && $TOOL_OUT != *'POTENTIAL:'* ]] && pass 'older orphan marker does not false-positive' || fail 'older orphan marker' "$TOOL_OUT"
rm -rf "$FIX"

# 11 nonnumeric marker ignored for chronology
new_fixture
printf '#!/bin/bash\n' > "$FIX/omarchy/migrations/1787000000.sh"
touch "$FIX/home/.local/state/omarchy/migrations/custom-marker"
run_tool
[[ $TOOL_STATUS -eq 0 ]] && pass 'nonnumeric marker ignored for chronology' || fail 'nonnumeric marker' "$TOOL_OUT"
rm -rf "$FIX"

# 12 no user ledger is harmless
new_fixture
rm -rf "$FIX/home/.local/state/omarchy/migrations"
printf '#!/bin/bash\n' > "$FIX/omarchy/migrations/1787000000.sh"
run_tool
[[ $TOOL_STATUS -eq 0 && $TOOL_OUT == *'no user migration ledger found'* ]] && pass 'missing user ledger is harmless' || fail 'no user ledger' "$TOOL_OUT"
rm -rf "$FIX"

# 13 missing migration tree makes check incomplete
new_fixture
rm -rf "$FIX/omarchy/migrations"
run_tool
[[ $TOOL_STATUS -eq 2 && $TOOL_OUT == *'INCOMPLETE:'* ]] && pass 'missing Omarchy migration tree is incomplete' || fail 'missing migration tree' "$TOOL_OUT"
rm -rf "$FIX"

# 14 migration scripts are never executed
new_fixture
cat > "$FIX/omarchy/migrations/1786000000.sh" <<SH
#!/bin/bash
touch "$FIX/EXECUTED"
SH
touch "$FIX/home/.local/state/omarchy/migrations/1786000000.sh"
run_tool
[[ $TOOL_STATUS -eq 0 && ! -e "$FIX/EXECUTED" ]] && pass 'migration scripts are never executed' || fail 'script execution guard' "$TOOL_OUT"
rm -rf "$FIX"

# 15 non-Btrfs root is reported without alarming
new_fixture
printf '#!/bin/bash\n' > "$FIX/omarchy/migrations/1786000000.sh"
touch "$FIX/home/.local/state/omarchy/migrations/1786000000.sh"
TEST_ROOT_FSTYPE=ext4 run_tool
[[ $TOOL_STATUS -eq 0 && $TOOL_OUT == *'root filesystem is not reported as Btrfs'* ]] && pass 'non-Btrfs root is handled' || fail 'non-btrfs root' "$TOOL_OUT"
rm -rf "$FIX"

# 16 version
out=$("$TOOL" version)
[[ $out == 'omrollback-check 1.0.0' ]] && pass 'version output' || fail 'version output' "$out"

# 17 invalid arguments fail safely
set +e
out=$("$TOOL" nonsense 2>&1); status=$?
set -e
[[ $status -eq 2 && $out == *'Usage:'* ]] && pass 'invalid arguments fail safely' || fail 'invalid arguments' "$out"

# 18 normal root invocation is refused (test suite itself runs as root in CI here)
if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  set +e
  out=$(HOME=/tmp "$TOOL" 2>&1); status=$?
  set -e
  [[ $status -eq 2 && $out == *'Do not run omrollback-check as root'* ]] && pass 'root invocation is refused' || fail 'root refusal' "$out"
else
  pass 'root refusal test skipped when suite is already non-root'
fi

printf '\n%d passed, %d failed\n' "$pass_count" "$fail_count"
(( fail_count == 0 ))
