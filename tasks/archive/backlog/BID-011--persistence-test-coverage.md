# BID-011: No test coverage for SaveManager or SceneManager

**Category:** doc-gap
**Discovered During:** GID-064 audit

## Description

`tests/runner.gd:14-29` registers no suites covering SaveManager (14 field migrations,
dirty-flag flush batching, atomic write/backup fallback once TID-227 lands) or
SceneManager's state machine (scene stack push/pop, overlay interleavings) — the two
highest-risk persistence paths in the project, and the source of several GID-064 high
findings (split-brain instances, save wipe on corrupt JSON).

## Evidence

- tests/runner.gd:14-29 — suite list.
- GID-064 findings: SaveManager.gd:113-115, 458-460; SceneManager.gd:69, 144-146.

## Suggested Resolution

Add `test_save_manager.gd` (migration of a v1-shaped dict, dirty-flag flush timing,
corrupt-file fallback) and `test_scene_manager_state.gd` (state transitions, stack
integrity). Best written immediately after TID-226/TID-227 so the new behaviour is
locked in.
