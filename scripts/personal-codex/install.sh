#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: bash install.sh /path/to/extracted-package" >&2
  exit 1
fi
package="$(cd "$1" && pwd)"
if [[ ! -f "$package/codex-package.json" || ! -x "$package/bin/codex" ]]; then
  echo "Expected an extracted Codex package with codex-package.json and bin/codex." >&2
  exit 1
fi

# A dedicated launcher preserves the packaged helpers and the existing codex installation.
install_root="${XDG_DATA_HOME:-$HOME/.local/share}/codex-personal"
bin_dir="${CODEX_PERSONAL_BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$install_root" "$bin_dir"
install_dir="$(mktemp -d "${install_root}/build.XXXXXXXX")"
cp -R "$package/." "$install_dir/"
"$install_dir/bin/codex" --version
launcher="$bin_dir/codex-personal"
if [[ -e "$launcher" && ! -L "$launcher" ]]; then
  echo "Refusing to replace the existing non-symlink $launcher" >&2
  exit 1
fi
ln -sfn "$install_dir/bin/codex" "$launcher"
printf 'Installed %s\nRun: %s\n' "$install_dir" "$launcher"
