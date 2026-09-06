#!/bin/bash
set -euo pipefail

[[ ${EUID:-$(id -u)} -ne 0 ]] || { echo "Do not run this installer as root." >&2; exit 1; }

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
src="$root/bin/omrollback-check"
dest="$HOME/.local/bin/omrollback-check"

[[ -x $src ]] || { echo "Missing executable: $src" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "git is required." >&2; exit 1; }
command -v findmnt >/dev/null 2>&1 || { echo "findmnt is required." >&2; exit 1; }

mkdir -p "$HOME/.local/bin"
install -m 0755 "$src" "$dest"

echo "Installed: $dest"
"$dest" version

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "Note: $HOME/.local/bin is not currently in PATH." ;;
esac
