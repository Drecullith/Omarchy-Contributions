#!/bin/bash
set -euo pipefail

[[ $EUID -ne 0 ]] || { echo "Do not run this installer as root." >&2; exit 1; }

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
src="$root/bin/omrescue"
dest="$HOME/.local/bin/omrescue"

[[ -f $src && -r $src ]] || { echo "Missing program file: $src" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required." >&2; exit 1; }

mkdir -p "$HOME/.local/bin"
install -m 0755 "$src" "$dest"

echo "Installed: $dest"
"$dest" version

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "Note: $HOME/.local/bin is not currently in PATH." ;;
esac
