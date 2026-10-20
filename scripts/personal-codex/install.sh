#!/usr/bin/env bash

# Keep execution at the end so a truncated curl download cannot run half an installer.
main() (
  set -euo pipefail
  if [[ $# -gt 1 ]]; then
    echo "Usage: bash install.sh [ /path/to/extracted-package | --help ]" >&2
    exit 1
  fi
  if [[ "${1:-}" == --help ]]; then
    cat <<'EOF'
Install or upgrade pcodex from Unturned3/codex-rh's latest release:
  bash install.sh
Install an already-extracted package:
  bash install.sh /path/to/extracted-package
Options (environment variables):
  PCODEX_VERSION=personal-v1    Select a release instead of latest (also for rollback).
  PCODEX_BIN_DIR=/some/bin     Launcher directory (default: ~/.local/bin).
  XDG_DATA_HOME=/some/data     Data directory (default: ~/.local/share).
EOF
    exit 0
  fi

  if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
    echo "pcodex currently supports Linux x86_64 only." >&2
    exit 1
  fi

  # Retain the original storage directory and environment override for existing installs.
  install_root="${XDG_DATA_HOME:-$HOME/.local/share}/codex-personal"
  bin_dir="${PCODEX_BIN_DIR:-${CODEX_PERSONAL_BIN_DIR:-$HOME/.local/bin}}"
  launcher="$bin_dir/pcodex"
  if [[ -e "$launcher" && ! -L "$launcher" ]]; then
    echo "Refusing to replace the existing non-symlink $launcher" >&2
    exit 1
  fi

  scratch_dir=""
  link_stage=""
  pending_install=""
  trap '[[ -z "$scratch_dir" ]] || rm -rf -- "$scratch_dir"
        [[ -z "$link_stage" ]] || rm -rf -- "$link_stage"
        [[ -z "$pending_install" ]] || rm -rf -- "$pending_install"' EXIT

  if [[ $# -eq 1 ]]; then
    package="$(cd "$1" && pwd)"
  else
    for dependency in curl tar sha256sum awk; do
      if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "Install $dependency before running the pcodex installer." >&2
        exit 1
      fi
    done
    repo_url="https://github.com/Unturned3/codex-rh"
    version="${PCODEX_VERSION:-}"
    if [[ -z "$version" ]]; then
      # Resolve latest once, then pin every download to that release.
      release_url="$(curl --proto '=https' --proto-redir '=https' --tlsv1.2 \
        -fsSL --retry 3 -o /dev/null -w '%{url_effective}' "$repo_url/releases/latest")"
      version="${release_url#"$repo_url/releases/tag/"}"
    fi
    if [[ ! "$version" =~ ^personal-v[[:alnum:]][[:alnum:]._-]*$ ]]; then
      echo "Expected a personal-v* release from $repo_url; got: $version" >&2
      exit 1
    fi
    archive="codex-personal-x86_64-unknown-linux-musl.tar.gz"
    download_url="$repo_url/releases/download/$version"
    scratch_dir="$(mktemp -d)"
    printf 'Downloading pcodex %s...\n' "$version"
    for asset in SHA256SUMS "$archive"; do
      curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL --retry 3 \
        "$download_url/$asset" -o "$scratch_dir/$asset"
    done
    checksum="$(awk -v archive="$archive" '$2 == archive { print $1 }' "$scratch_dir/SHA256SUMS")"
    if [[ ! "$checksum" =~ ^[[:xdigit:]]{64}$ ]]; then
      echo "Missing or invalid archive checksum in release $version." >&2
      exit 1
    fi
    (cd "$scratch_dir" && printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check -)
    package="$scratch_dir/package"
    mkdir "$package"
    tar -xzf "$scratch_dir/$archive" -C "$package"
  fi

  if [[ ! -f "$package/codex-package.json" || ! -x "$package/bin/codex" ]]; then
    echo "Expected an extracted Codex package with codex-package.json and bin/codex." >&2
    exit 1
  fi
  mkdir -p "$install_root" "$bin_dir"
  install_root="$(cd "$install_root" && pwd)"
  bin_dir="$(cd "$bin_dir" && pwd)"
  launcher="$bin_dir/pcodex"
  pending_install="$(mktemp -d "${install_root}/build.XXXXXXXX")"
  cp -R "$package/." "$pending_install/"
  "$pending_install/bin/codex" --version

  # Switch only after validation; keep the previous installation for rollback.
  link_stage="$(mktemp -d "$bin_dir/.pcodex.XXXXXXXX")"
  ln -s "$pending_install/bin/codex" "$link_stage/pcodex"
  mv -Tf "$link_stage/pcodex" "$launcher"
  installed_dir="$pending_install"
  pending_install=""

  # Migrate only a launcher owned by our original installer.
  legacy_launcher="$bin_dir/codex-personal"
  if [[ -L "$legacy_launcher" ]]; then
    legacy_target="$(readlink "$legacy_launcher")"
    if [[ "$legacy_target" == "$install_root"/build.*/bin/codex ]]; then
      rm -- "$legacy_launcher"
    fi
  fi
  printf 'Installed %s\nRun: %s\n' "$installed_dir" "$launcher"
  case ":$PATH:" in
    *":$bin_dir:"*) ;;
    *) printf 'Add %s to your PATH to run pcodex by name.\n' "$bin_dir" ;;
  esac
)

main "$@"
