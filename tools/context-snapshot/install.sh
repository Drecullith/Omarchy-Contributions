#!/bin/bash
set -euo pipefail
[[ ${EUID:-$(id -u)} -ne 0 ]] || { echo "Do not run this installer as root." >&2; exit 1; }
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
[[ -x $root/bin/omcontext ]] || { echo "Missing executable: $root/bin/omcontext" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required." >&2; exit 1; }
mkdir -p "$HOME/.local/bin" "$HOME/.local/share/omcontext"
install -m 0755 "$root/bin/omcontext" "$HOME/.local/bin/omcontext"
install -m 0644 "$root/lib/omcontext_common.py" "$root/lib/omcontext_collect.py" "$root/lib/omcontext_delta.py" "$HOME/.local/share/omcontext/"
echo "Installed: $HOME/.local/bin/omcontext"
"$HOME/.local/bin/omcontext" --version
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "Note: $HOME/.local/bin is not currently in PATH." ;; esac
