#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
target="${TARGET:-x86_64-unknown-linux-musl}"
if [[ "$target" != x86_64-unknown-linux-musl ]]; then
  echo "This build currently supports x86_64-unknown-linux-musl only." >&2
  exit 1
fi
export STABLE_GIT_COMMIT
STABLE_GIT_COMMIT="$(git -C "$repo_root" rev-parse HEAD)"
release_dir="${repo_root}/codex-rs/target/${target}/release"
dist_dir="${repo_root}/dist/personal"
staging_dir="$(mktemp -d)"
trap 'rm -rf "$staging_dir"' EXIT

cd "${repo_root}/codex-rs"
# Finalize bwrap before hashing it; Codex verifies these exact packaged bytes at runtime.
cargo build --locked --release --target "$target" --bin bwrap
strip --strip-debug --strip-unneeded "${release_dir}/bwrap"
export CODEX_BWRAP_SHA256
CODEX_BWRAP_SHA256="$(sha256sum "${release_dir}/bwrap" | cut -d ' ' -f 1)"

cargo test --locked --release --target "$target" -p codex-tui --lib history_cell::messages::tests
cargo test --locked --release --target "$target" -p codex-tui --lib insert_history::tests
cargo build --locked --release --target "$target" --bin codex --bin codex-code-mode-host

mkdir -p "$dist_dir"
python3 "${repo_root}/scripts/build_codex_package.py" \
  --target "$target" --variant codex --cargo-profile release \
  --entrypoint-bin "${release_dir}/codex" \
  --code-mode-host-bin "${release_dir}/codex-code-mode-host" \
  --bwrap-bin "${release_dir}/bwrap" \
  --strip all \
  --package-dir "${staging_dir}/package" \
  --archive-output "${dist_dir}/codex-personal-${target}.tar.gz" --force

# Smoke-test the archived layout, not just Cargo's output directory.
mkdir "${staging_dir}/extracted"
tar -xzf "${dist_dir}/codex-personal-${target}.tar.gz" -C "${staging_dir}/extracted"
"${staging_dir}/extracted/bin/codex" --version
"${staging_dir}/extracted/codex-resources/bwrap" --version
"${staging_dir}/extracted/codex-path/rg" --version

cd "$dist_dir"
cp "${repo_root}/scripts/personal-codex/install.sh" install.sh
sha256sum "codex-personal-${target}.tar.gz" install.sh > SHA256SUMS
printf '%s\n' "$STABLE_GIT_COMMIT" > SOURCE_COMMIT
