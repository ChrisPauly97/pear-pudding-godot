# GID-085: Test Coverage Expansion

## Objective

Add headless test suites for the two highest-risk untested paths (SaveManager persistence, SceneManager state machine) and BattleScene-level keyword integration, and resolve the dead hero freeze/stun code paths.

## Context

`tests/runner.gd` has no suites for `SaveManager` (14 field migrations, dirty-flag flush batching, corrupt-file fallback) or `SceneManager` (scene stack push/pop, overlay interleavings) — the two highest-risk persistence paths in the project. BattleScene-level tests are also absent: Ward/Surge/Shroud keyword interactions and spell resolution are only covered by unit tests on pure logic, not end-to-end. Additionally, `hero freeze/stun` tick handling (BattleScene.gd:1665-1678, PlayerState.gd:65) is currently unreachable — no effect ever applies these to a hero. (BID-011, BID-012)

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-305 | Add test_save_manager.gd suite | agent | pending | — |
| TID-306 | Add test_scene_manager_state.gd suite | agent | pending | — |
| TID-307 | BattleScene keyword integration tests + resolve hero freeze/stun | agent | pending | — |

## Acceptance Criteria

- [ ] `test_save_manager.gd` covers: migration of a v1-shaped dict to current schema, dirty-flag flush timing, corrupt-file fallback behaviour
- [ ] `test_scene_manager_state.gd` covers: push/pop scene stack, overlay interleaving, state integrity across transitions
- [ ] At least one integration test instantiates BattleScene headless and scripts a full Ward, Surge, and Shroud interaction
- [ ] Hero freeze/stun paths are either wired to a real card effect or deleted (decision documented in Changes Made)
- [ ] All tests pass headless; test runner exit code 0
