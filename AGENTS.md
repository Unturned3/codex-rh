# Maintaining the personal Codex fork

This is **Unturned3/codex-rh**, with development/default branch **rh**.
Read [docs/personal-fork.md](docs/personal-fork.md) before changing the fork,
updating upstream, or publishing a release. It contains the executable runbook.
Honor any more specific AGENTS.md in the directories you edit.

## Preserve these decisions

- User transcript messages are light blue; assistant text is light gray,
  including streaming and reflow. Keep this patch localized to the TUI.
- The installed command is **pcodex**. The packaged executable remains
  `bin/codex`; retain the complete package and its helpers.
- Install/upgrade uses the curl installer and **this fork's GitHub releases**.
  Do not implement a custom Rust updater, switch to upstream installation, or
  replace the user's separate `codex` installation.
- The current source version is `0.0.0`, which suppresses upstream startup
  update checks. Re-check that behavior on upstream rebases; report a change
  rather than silently introducing upstream updates.
- Linux x86_64 musl is the supported release target. Keep custom commits
  focused so future rebases remain manageable.

## When asked to update and release

Carry the authorized task through fetch, backup, rebase, validation, push,
build, release, and verification. Use the runbook; do not stop at suggesting
commands. Do not assume this file alone authorizes a push or release.

- Check the working tree, remotes, active GitHub identity, and branch first.
  Preserve unrelated edits. `origin` is the personal fork; `upstream` is
  `openai/codex`. Never push personal changes to upstream.
- Fetch both remotes before rebasing. Save a fresh backup branch and the exact
  remote `rh` SHA. Inspect conflicts and the final patch; use an explicit
  force-with-lease against that saved SHA when publishing rebased history.
- Keep **Personal Codex** as the fork's only enabled Actions workflow unless
  the user requests more. Re-check this after upstream adds workflows.
- Use a fresh **personal-v*** tag; never move an existing release tag or
  overwrite its published assets. Never push upstream `rust-v*` tags.
- Wait for the relevant build/release result. Verify downloaded checksums and
  an isolated installation before reporting success. Cold hosted builds have
  taken about 106 minutes; an active build is not proof it is hung.
- Installer/docs-only work does not require rebuilding Rust. Test locally,
  then use a `[skip ci]` commit when appropriate; the public installer comes
  directly from `rh`. Do not skip CI for Rust, build, or packaging changes.
  A rebase may retain an old skip marker: explicitly dispatch the required
  branch/tag workflow in that case, as documented in the runbook.

## Validation and credentials

Run `bash -n`, `shellcheck` when available, and
`python3 -m unittest discover -s scripts/personal-codex -p 'test_*.py'`
for installer changes. Use `actionlint` for workflow changes. The runbook lists
the focused Rust tests and real-package smoke checks.

Use an authenticated GitHub CLI for **Unturned3** with repository write and
workflow scope (or equivalent fine-grained permissions). Never store tokens
in the repository or print them. Credentials and temporary directories from
previous agent sessions are not guaranteed to exist. If authentication or
network access is missing, report the exact blocker and request only what is
needed; do not claim the push or release happened.
