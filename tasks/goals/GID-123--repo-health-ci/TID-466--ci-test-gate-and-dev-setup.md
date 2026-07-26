# TID-466: CI Test Gate, Reproducible Dev Setup & Import-Trap Docs

Goal: [GID-123](goal.md)
Type: agent
Status: done

## Context

See `goal.md`. Two structural gaps: the test suite never ran in CI, and a fresh
checkout silently produces 38 false test failures because the project has not
been imported.

## Plan

1. Add `.github/workflows/tests.yml` — import, parse-error gate, test suite,
   plus an advisory `gdlint` job.
2. Add `scripts/setup-dev-env.sh` — idempotent Godot install + project import.
3. Wire it as a `SessionStart` hook in `.claude/settings.json`.
4. Document the import prerequisite in `CLAUDE.md`.
5. Untrack `.DS_Store`.

## Changes Made

### `.github/workflows/tests.yml` (new)

Two jobs.

`test` — runs on push to any branch, PRs to `main`/`master`, and manual
dispatch:

- Caches the Godot binary on `godot-4.6-stable-linux-x86_64` so only the first
  run pays the download.
- `concurrency` group cancels superseded in-flight runs per ref.
- **Import step** (`godot --headless --editor --quit`), teed to `/tmp/import.log`.
  Kept non-fatal so the next step can produce a clearer message.
- **Parse-error gate** — greps the import log for `Parse Error` / `Compile Error`
  / `Failed to load script`, filtering the known-benign `imported/` and
  `Make sure resources` noise, exactly as `CLAUDE.md` prescribes. Emits a
  `::error::` annotation and fails the job. Separated from the test step because
  a parse error breaks every scene that preloads the file and deserves its own
  signal rather than being buried in test output.
- **Test suite** — `godot --headless --path . -s tests/runner.gd`. `runner.gd`
  already exits 1 on failure, so no wrapper is needed.
- 30-minute job timeout.

`lint` — installs `gdtoolkit` and runs `gdlint` over `git ls-files '*.gd'`.
Marked `continue-on-error: true` because the existing tree carries pre-existing
lint debt; flipping it off is a follow-up (see BID-053). Included now so the
debt is visible on every run instead of invisible.

### `scripts/setup-dev-env.sh` (new, executable)

Idempotent, and deliberately non-fatal (`set -uo pipefail`, no `-e`) so a
transient network failure degrades to a warning rather than blocking a session.

1. Skips the Godot download if `godot` is already on `PATH`.
2. Falls back to `~/.local/bin` when `/usr/local/bin` is not writable.
3. Skips the import when `.godot/imported` already exists.
4. Runs the same parse-error grep as CI and reports the result.

`GODOT_VERSION` and `GODOT_INSTALL_DIR` are overridable via environment.

Verified idempotent: a second invocation no-ops both steps.

### `.claude/settings.json` (new)

`SessionStart` hook (`matcher: "startup"`) invoking the setup script with a
900-second timeout. Scoped to `startup` so resume/clear/compact do not re-run
it — the script would no-op anyway, but the hook should not add latency to
those events.

### `CLAUDE.md`

Rewrote the "Running Tests" section:

- Replaced the four-line manual `wget`/`unzip`/`cp`/`chmod` block with the
  single setup command.
- Added a **"You MUST import before the first test run"** subsection stating the
  exact symptom (~38 failures, `CardRegistry` serving 1 card instead of 105) so
  the next agent recognises it instead of debugging phantom bugs.
- Pointed at the CI workflow.

### `.DS_Store`

Untracked (`git rm --cached`) and deleted; already in `.gitignore`.

## Verification

- `godot --headless --editor --quit` — clean, zero parse/compile errors.
- `godot --headless --path . -s tests/runner.gd` — **2209 passed, 0 failed,
  1 pending, RESULT: PASS**.
- `scripts/setup-dev-env.sh` re-run — both steps correctly no-op.
- Both workflow YAML files parse under `yaml.safe_load`.
- `.claude/settings.json` parses as JSON.

### `.gdlintrc`

Two rules contradicted the project's own mandated conventions, so compliant code
was being penalised. Fixing them cut reported problems from >1000 to 638:

- `constant-name` had been overridden to `[A-Z][A-Z0-9_]*`, dropping the
  optional leading underscore gdlint allows by default — private constants like
  `AudioManager._POOL_SIZE` were flagged.
- `load-constant-name` was never set, so the default rejected
  `const _SpriteRegistry = preload(...)` — the exact pattern **CLAUDE.md
  requires** over bare `class_name` references.
- `function-preload-variable-name` / `function-load-variable-name` widened to
  allow the same leading underscore.

### Backlog reconciliation (absorbs BID-046, BID-047)

`tasks/backlog/` had drifted badly from the index. Reconciled:

- **BID-047** — deleted the orphaned duplicate
  `GID-023/TID-081--background-music-loop.md` (the `-integration` file is the
  real, completed one).
- **Duplicate BID-018** — renumbered the test-runner item to **BID-054** so IDs
  are globally unique again.
- **BID-018 / BID-054 / BID-019 / BID-021 archived as resolved.** All three
  described unexplained headless test failures, and all three were the *same*
  root cause this task fixes: no prior editor scan. Verified: full suite is
  2209/0 after import. BID-018 (enemy-registry `DirAccess`) was separately
  confirmed fixed at HEAD — `grep -c "DirAccess\|ResourceLoader.load"
  autoloads/EnemyRegistry.gd` → 0.
- **10 further items** (BID-001, 002, 005, 008, 010, 011, 012, 013, 017, 020)
  were struck through in the index as resolved or promoted but their files had
  never been moved to `tasks/archive/backlog/`. Archived.
- Backlog went from 30 files to **12 genuinely open**.
- Rewrote the index's Backlog and Resolved Backlog tables from the filesystem so
  every row's link points at where the file actually lives, dropping the
  now-meaningless `~~strikethrough~~` markers from the open table.

### Stale verification caveats

11 goal rows in `tasks/index.md` carried
`done (… unverified in-sandbox — see goal.md note)`. That caveat existed
precisely because no one could get a trustworthy test run — the thing this goal
fixes. With a clean import and 2209/0 verified at this commit, all 11 were
reduced to plain `done`. The per-goal `goal.md` notes were left untouched as a
historical record; this task's verification supersedes them.

## Documentation Updates

- `CLAUDE.md` — Running Tests section rewritten (above).
- `tasks/index.md` — GID-123 row added; Backlog/Resolved tables rebuilt;
  stale verification caveats cleared.

## Backlog Discovered

- **BID-053** — `gdlint` job is advisory-only due to 638 pre-existing problems.

## Backlog Resolved

- **BID-046** — backlog index drift (duplicate ID, unindexed items, stale rows).
- **BID-047** — orphaned duplicate TID-081 file.
- **BID-054** (ex-duplicate BID-018), **BID-019**, **BID-021** — all three were
  the missing-import root cause.
