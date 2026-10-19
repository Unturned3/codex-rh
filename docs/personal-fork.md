# Personal Codex

The `rh` branch carries two independent changes: transcript colors and
the personal build/release workflow. User messages use `#DCEEFF`; assistant
messages use `#EEEEEE`, with dark foregrounds. The palette lives in
`codex-rs/tui/src/style.rs`. Assistant styling is confined to message cells in
`codex-rs/tui/src/history_cell/messages.rs`, including the live streaming tail.
Tool output, reasoning, and the input composer retain upstream styling. Truecolor
and 256-color terminals are supported; limited-color terminals retain default
styling. This changes the interactive TUI, not `codex exec` output.

## GitHub setup

The public fork is [Unturned3/codex-rh](https://github.com/Unturned3/codex-rh),
with `rh` as the development branch. The `upstream` remote points to
`https://github.com/openai/codex.git`; `origin` points to
`https://github.com/Unturned3/codex-rh.git`.

Authenticate the GitHub CLI locally with
`gh auth login --hostname github.com --scopes repo,workflow`
and `gh auth setup-git`. The login needs repository creation/write access and
permission to push workflow files. Do not put tokens in source files. The release
workflow uses GitHub's automatic `GITHUB_TOKEN`; no publishing secret is needed.

Enable Actions in the personal repository and disable inherited upstream
workflows in that repository's Actions settings, keeping **Personal Codex**
enabled. This avoids running OpenAI's organization-specific automation. GitHub
Actions usage/billing settings must allow the build to run.

## Builds and releases

Pushes to `rh` and manual runs build Linux x86_64 musl archives. The workflow
reads the upstream Rust toolchain pin, verifies upstream V8 downloads, runs
message rendering and scrollback tests, and builds an optimized CLI. LTO is
disabled and compilation is limited to two jobs to reduce hosted-runner memory
pressure. The first verified release, `personal-v1`, took about 106 minutes for
the cold build/test/package step on a standard hosted runner. Its published
checksums and installation were also verified.

Download the archive from the workflow run's artifacts. To publish a permanent
GitHub Release after a successful branch build:

```bash
git tag -a personal-v2 -m 'Personal Codex release 2'
git push origin personal-v2
```

Use a new `personal-v*` tag for each release. These tags deliberately do not match
upstream's `rust-v*` release trigger. The release records the full source commit.
The package includes `codex`, `codex-code-mode-host`, verified `bwrap`, and pinned
`rg`, using upstream's canonical package layout. The optional voice runtime is
not bundled. macOS/Windows builds are not configured yet.

## Install

Download the `.tar.gz`, `install.sh`, and `SHA256SUMS` release assets into the same directory:

```bash
sha256sum --check SHA256SUMS
mkdir codex-personal-package
tar -xzf codex-personal-x86_64-unknown-linux-musl.tar.gz -C codex-personal-package
bash install.sh ./codex-personal-package
~/.local/bin/codex-personal
```

Keep the complete package together: copying only `bin/codex` loses its helpers.
The installer retains previous installations under
`${XDG_DATA_HOME:-$HOME/.local/share}/codex-personal` and changes only the
`~/.local/bin/codex-personal` symlink. Add `~/.local/bin` to your shell's `PATH` if
needed. The CLI uses your existing Codex configuration and authentication.

## Updating from upstream

Keep each customization as a separate commit and rebase onto upstream `main`.
Preserve a backup branch before rewriting `rh`:

```bash
git fetch upstream main --tags
git switch rh
git branch backup/rh-before-update
git rebase upstream/main
git push --force-with-lease origin rh
```

Choose a fresh backup branch name each time. Resolve any conflicts, inspect the
patch, and wait for the build/tests to succeed before tagging the next personal
release. Re-check inherited workflow settings after updates that add workflows.
