# Personal Codex (pcodex)

This is [Unturned3/codex-rh](https://github.com/Unturned3/codex-rh), with `rh`
as its development and default branch. `origin` points to this fork;
`upstream` points to `https://github.com/openai/codex.git`.

## Install or upgrade

On **Linux x86_64**, run the same command for installation and upgrades:

```bash
curl -fsSL https://raw.githubusercontent.com/Unturned3/codex-rh/rh/scripts/personal-codex/install.sh | bash
```

Then run `pcodex`, or `~/.local/bin/pcodex` if that directory is not on your PATH.
No GitHub login, Node, Rust compiler, or sudo is needed. The installer needs
Bash, curl, tar, sha256sum, and ordinary Linux utilities. Other platforms are
rejected before downloading.

The script resolves this fork's latest release once, downloads its Linux
archive and checksum file, verifies the archive, and smoke-tests the installed
CLI before switching the launcher. An unsuccessful download, checksum check,
or executable check leaves the previous installation active. The full package
includes the CLI, code-mode host, bubblewrap, and ripgrep; the optional voice
runtime is not bundled.

The command is **pcodex**, but the internal executable remains `bin/codex`.
The installer keeps packages under
`${XDG_DATA_HOME:-$HOME/.local/share}/codex-personal` and creates the
`~/.local/bin/pcodex` symlink. The original `codex-personal` symlink is removed
only if it points into that installer's storage. Other launchers and your
existing `codex` installation are left alone. Previous packages remain for
rollback. The CLI uses your existing Codex configuration and authentication.

Set `PCODEX_BIN_DIR` on the **bash side of the pipe** to choose a different
launcher directory. The original `CODEX_PERSONAL_BIN_DIR` override remains
supported as a fallback. For a pinned release or rollback:

```bash
curl -fsSL https://raw.githubusercontent.com/Unturned3/codex-rh/rh/scripts/personal-codex/install.sh \
  | PCODEX_VERSION=personal-v1 bash
```

For an already-downloaded and checksum-verified package, the current installer
also accepts `bash scripts/personal-codex/install.sh /path/to/extracted-package`.
Do not copy just the binary; it needs its packaged helpers.

The public installer is served from `rh`, independently of compiled releases.
It works with the existing `personal-v1` archive. The `install.sh` attached to
that old release is the original offline installer; use the command above for
the current installer. Published release assets are not rewritten.

## Updates are through the installer

Re-run the curl command to update an installed binary. It uses only releases
from **Unturned3/codex-rh**, never upstream releases. It does not fetch source,
rebase patches, or build a new release; those are maintainer operations below.

We intentionally have no custom Rust updater. Do not use `pcodex update` to
upgrade this fork. The current binary reports `0.0.0`; upstream's
`tui/src/update_versions.rs` and `tui/src/updates.rs` suppress startup update
checks for that source version. In our normal installation location,
`InstallMethod::Other` also provides no built-in update action. The underlying
upstream updater still exists, so re-check these assumptions when rebasing,
changing version stamping, or changing the installation layout.

## Custom patch map

- `codex-rs/tui/src/style.rs`: user background `#DCEEFF`, assistant background
  `#EEEEEE`, and readable dark foregrounds.
- `codex-rs/tui/src/history_cell/messages.rs`: message styling, including
  streaming, markdown, and reflow. `messages_tests.rs` tests it.
- `scripts/personal-codex/install.sh`: downloading, validation, and `pcodex`
  installation. `test_install.py` exercises upgrades and failure cases.
- `scripts/personal-codex/build-release.sh`: focused tests, compilation,
  canonical package layout, checksums, and executable smoke checks.
- `.github/workflows/personal-release.yml`: CI artifacts and tagged releases.
- Root `AGENTS.md`, this guide, and the opening README section: fork guidance.

Tool output, reasoning, and the input composer retain upstream styling.
Truecolor and 256-color terminals are supported; limited-color terminals retain
default styling. This affects the interactive TUI, not `codex exec` output.
Keep customization commits focused; avoid unrelated upstream cleanup.

## Agent prerequisites

A fresh agent should read root `AGENTS.md` and this guide. It needs a writable
checkout, network access, Git, and GitHub CLI credentials for **Unturned3**.
Repository write access and `workflow` scope (or equivalent fine-grained
permissions) are needed for pushing workflow files. Check:

```bash
git status --short --branch
git remote -v
gh auth status
gh api user --jq .login
```

If needed, the user can authenticate with
`gh auth login --hostname github.com --scopes repo,workflow` and
`gh auth setup-git`. A read-only credential directory may require a writable
`GH_CONFIG_DIR`; never commit credentials or assume a previous session's
temporary credential directory still exists.

The release workflow uses GitHub's automatic `GITHUB_TOKEN`; it needs no
publishing secret. Keep **Personal Codex** as the only enabled workflow in this
fork. Inspect this after rebasing, especially if upstream added workflows:

```bash
gh api repos/Unturned3/codex-rh/actions/workflows --paginate \
  --jq '.workflows[] | [.id, .name, .state] | @tsv'
```

Disable newly inherited automation with
`gh workflow disable WORKFLOW_ID -R Unturned3/codex-rh`, preserving
`personal-release.yml`. Never disable workflows in `openai/codex`.

## Rebase runbook

When authorized to update the fork, first ensure a clean working tree and
confirm the remotes above. Preserve unrelated edits instead of discarding or
silently committing them. Fetch both remotes and inspect incoming fork changes:

```bash
git switch rh
git fetch origin rh --tags
git fetch upstream main
git log --oneline --left-right rh...origin/rh
git merge-base --is-ancestor origin/rh HEAD
```

If the last command fails, reconcile the remote fork changes before proceeding.
Record the remote tip and preserve a unique backup before rewriting history:

```bash
remote_rh_before="$(git rev-parse origin/rh)"
old_base="$(git merge-base HEAD upstream/main)"
backup_branch="backup/rh-$(date -u +%Y%m%dT%H%M%SZ)"
git branch "$backup_branch"
git rebase upstream/main
```

Resolve conflicts while preserving the patch map and update policy above.
Inspect the result, including upstream changes that could invalidate helpers,
color rendering, source-version behavior, or build requirements:

```bash
git range-diff "$old_base..$backup_branch" "upstream/main..HEAD"
git diff --stat upstream/main...HEAD
git diff --check upstream/main...HEAD
```

Run the relevant validation below. Push rebased history with the saved remote
SHA as the lease, so another person's concurrent work cannot be overwritten:

```bash
git push --force-with-lease="refs/heads/rh:$remote_rh_before" origin HEAD:refs/heads/rh
```

For ordinary changes without a rebase, use a normal `git push origin rh`.
Do not force-push upstream or move published tags.

## Validation

Installer-only work:

```bash
bash -n scripts/personal-codex/install.sh
shellcheck scripts/personal-codex/install.sh
python3 -m unittest discover -s scripts/personal-codex -p 'test_*.py'
git diff --check
```

Use `actionlint .github/workflows/personal-release.yml` for workflow changes.
For TUI work, use the upstream-pinned Rust toolchain and build prerequisites,
including its verified V8 artifacts; consult the personal workflow for setup.
From `codex-rs`, relevant focused tests are:

```bash
cargo test --locked --profile ci-test -p codex-tui --lib history_cell::messages::tests
cargo test --locked --profile ci-test -p codex-tui --lib insert_history::tests
cargo test --locked --profile ci-test -p codex-tui --lib transcript_view::text::prompt_style_tests
```

The release script also runs the first two filters on the release target. Do
not claim a test passed if a renamed filter matched zero tests. Broaden tests
when conflicts or upstream changes warrant it.

For installer/docs-only changes, local tests and a real-release smoke test
suffice. Use a `[skip ci]` commit to avoid an unnecessary Rust rebuild. This
also applies to release-note text changes in the workflow. Do not skip CI for
Rust, build, or packaging behavior changes. Pushing the installer to `rh`
publishes it immediately at the curl URL; no release tag is needed.

## Build, publish, and verify

Pushes to `rh` build downloadable Actions artifacts (retained for 14 days).
Pushing a fresh `personal-v*` tag runs the same build and publishes permanent
GitHub Release assets on success. Manual builds are available with:

```bash
gh workflow run personal-release.yml --ref rh -R Unturned3/codex-rh
```

**Rebase trap:** an existing `[skip ci]` message survives a rebase, even when
the underlying upstream source changed. It can suppress the new branch/tag
push builds. Always inspect `git log -1 --format=%B` and check that a run was
created. If a skip marker remains, use the manual command above for a branch
build, or, after pushing a new release tag:

```bash
gh workflow run personal-release.yml --ref "$release_tag" -R Unturned3/codex-rh
```

Dispatching on the tag runs both the build and release jobs.
[Skip markers affect push/PR events, not manual dispatch](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/skip-workflow-runs).
Never use an old skip marker as a reason to omit validation of a new upstream
revision.

For an authorized release, inspect existing tags and choose the next unused
`personal-v*` name. For example, use `personal-v2` only if it does not exist:

```bash
gh release list -R Unturned3/codex-rh
git tag --list 'personal-v*'
release_tag=personal-v2
git tag -a "$release_tag" -m "Personal Codex $release_tag"
git push origin "refs/tags/$release_tag"
```

Never reuse a published tag or upload replacement assets to an old release.
These tag names deliberately differ from upstream's `rust-v*` tags.

A branch push and a tag push each start a build. For a combined update/release,
after local validation you may push `rh` and the new tag together and cancel
only the redundant **branch** run at the same source SHA; retain the tag run,
which performs all release tests before publishing. Otherwise wait for the
branch build before tagging, accepting the second build.

Monitor the exact run/ref/SHA you triggered:

```bash
gh run list -R Unturned3/codex-rh --workflow personal-release.yml --limit 10
gh run view RUN_ID -R Unturned3/codex-rh
gh run view RUN_ID -R Unturned3/codex-rh --log-failed
```

The workflow uses Linux x86_64 musl, two compile jobs, and no release LTO to fit
standard hosted runners. It caches Cargo downloads, not compiled targets.
The first successful cold build/test/package step took about **106 minutes**;
the job timeout is 360 minutes. Avoid restarting a slow build without evidence
of failure. The combined build step may not expose logs until it finishes.
Report a pending build as pending, never as a verified release.

After success, verify the release assets and install them in an isolated
directory. Do not replace the user's installation just to test a release:

```bash
gh release view "$release_tag" -R Unturned3/codex-rh
verify_dir="$(mktemp -d)"
gh release download "$release_tag" -R Unturned3/codex-rh --dir "$verify_dir"
(cd "$verify_dir" && sha256sum --check SHA256SUMS)
test "$(cat "$verify_dir/SOURCE_COMMIT")" = "$(git rev-parse "$release_tag^{commit}")"
PCODEX_VERSION="$release_tag" XDG_DATA_HOME="$verify_dir/data" \
  PCODEX_BIN_DIR="$verify_dir/bin" bash scripts/personal-codex/install.sh
"$verify_dir/bin/pcodex" --version
"$verify_dir/bin/pcodex" --help
```

Also exercise the public curl command after publishing installer changes.
Report the source commit, release/run links, tests actually run, and any
limitations. The installer follows the latest published fork release; merging
or pushing source alone does not upgrade users' compiled binaries.
