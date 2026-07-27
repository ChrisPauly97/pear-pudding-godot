# GID-124: Repository Health — CI Test Gate & Reproducible Dev Setup

## Objective

Make the 2209-test suite actually protect the repo, and make a fresh checkout
able to run it without a hidden manual step.

## Context

Research pass (2026-07-26, branch `claude/continuous-improvement-abvtao`) began
by establishing a test baseline and immediately hit two structural problems.

### 1. The test suite never ran in CI

`.github/workflows/` contained exactly one workflow, `android-build.yml`, which
builds an APK on push to `main`/`master`. Nothing ever executed
`tests/runner.gd`. 2209 tests existed with zero automated enforcement — every
"done (headless test run unverified in-sandbox)" status in `tasks/index.md` is a
symptom of the same gap. Several goals (GID-111, GID-115, GID-117, GID-119,
GID-120, GID-121, GID-122) shipped with that caveat.

`tests/runner.gd:62` already calls `quit(1)` on failure, so the suite is
CI-ready as-is — only the workflow was missing.

### 2. A fresh checkout reports 38 false test failures

`.godot/` is gitignored (correctly — it is editor cache). But Godot cannot
`preload()` a `.png` or `.tres` that has never been imported. On an un-imported
checkout, `game_logic/SpriteRegistry.gd` fails to parse (every character-texture
`preload` is a parse error), which aborts `CardRegistry._ensure_loaded()` partway
through its loop. `_loaded` is already `true` by then, so the registry
permanently serves **1 card (`arcane_seal`) instead of 105**, and that cascades:

| Suite | Symptom |
|---|---|
| `test_card_registry` | `expected [105] got [1]` |
| `test_capture_tracker` | all `sig_*` cards missing |
| `test_game_state` | opening hands empty |
| `test_scripted_battle` / `_registry` | validation errors, wrong hero HP |
| `test_basic_ai` | wrong damage numbers |
| `test_auction_transfer` / `test_stash_transfer` / `test_trade_sync` | unique-card guards never trigger |
| `test_puzzle_mode` | empty hand/board |

None of these are real defects. `godot --headless --editor --quit` first, and
the suite is **2209 passed / 0 failed / 1 pending**.

`CLAUDE.md`'s "Running Tests" section documented installing Godot and running
the suite but *not* the import prerequisite, so the trap was undocumented and
highly repeatable — an agent would reasonably start "fixing" 38 phantom bugs.

### 3. Minor

`.DS_Store` was tracked in git despite being listed in `.gitignore`.

## Tasks

| Task | Title | Status |
|------|-------|--------|
| [TID-469](TID-469--ci-test-gate-and-dev-setup.md) | CI test gate, reproducible dev setup, import-trap docs | done |

## Acceptance Criteria

- [x] A CI workflow runs the full test suite on every push and PR.
- [x] CI imports the project and fails loudly on parse/compile errors.
- [x] One idempotent command sets up a fresh checkout end to end.
- [x] The setup runs automatically at session start.
- [x] `CLAUDE.md` documents the import prerequisite and its exact symptom.
- [x] Suite verified green locally: 2209 passed / 0 failed.
