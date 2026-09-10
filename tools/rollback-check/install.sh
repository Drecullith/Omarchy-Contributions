#!/bin/bash
set -euo pipefail

[[ ${EUID:-$(id -u)} -ne 0 ]] || { echo "Do not run this installer as root." >&2; exit 1; }

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
check_src="$root/bin/omrollback-check"
plan_src="$root/bin/omrollback-plan"
bin_dir="$HOME/.local/bin"

[[ -x $check_src ]] || { echo "Missing executable: $check_src" >&2; exit 1; }
[[ -x $plan_src ]] || { echo "Missing executable: $plan_src" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "git is required." >&2; exit 1; }
command -v findmnt >/dev/null 2>&1 || { echo "findmnt is required." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required for omrollback-plan." >&2; exit 1; }

mkdir -p "$bin_dir"
install -m 0755 "$check_src" "$bin_dir/omrollback-check"
install -m 0755 "$plan_src" "$bin_dir/omrollback-plan"

echo "Installed: $bin_dir/omrollback-check"
echo "Installed: $bin_dir/omrollback-plan"
"$bin_dir/omrollback-check" version
"$bin_dir/omrollback-plan" --version

case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) echo "Note: $bin_dir is not currently in PATH." ;;
esac
