# GID-071: Battle Layer Decomposition

## Objective

Decompose the 1,966-line BattleScene.gd god file into focused modules, eliminate internal duplication, decouple game_logic/battle from the SceneTree, and wire the never-emitted GameBus battle signals.

## Context

BattleScene.gd (scenes/battle/BattleScene.gd, 1,966 lines) carries approximately 10 distinct responsibilities identified by a June 2026 simplification audit. This goal extracts the four largest clusters into separate scripts, removes repeated code patterns, fixes the GameState→SceneTree coupling (the logic half of backlog item BID-010 — the native drag-and-drop half of BID-010 remains open), and wires the never-emitted GameBus battle signals (resolves BID-006). Per the spec, game_logic/ must stay rendering-free and all cross-system communication goes through GameBus. Tasks are sequential because they all touch BattleScene.gd. Coordinate with GID-064 battle tasks (TID-232..234) — if those land first, re-verify line numbers.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-262 | Extract battle animation & feedback module | agent | done | — |
| TID-263 | Extract card & hero view builders | agent | done | TID-262 |
| TID-264 | Extract spell resolver; decouple GameState; wire GameBus signals | agent | pending | TID-263 |
| TID-265 | Extract pause & victory overlay managers | agent | pending | TID-264 |

## Acceptance Criteria

- [ ] BattleScene.gd shrinks to roughly 600–900 lines of orchestration
- [ ] No behavior changes (battles, duels, boss fights, pause/resume all work as before)
- [ ] game_logic/battle contains no Engine.get_main_loop()/SceneTree access
- [ ] GameBus card_played/card_attacked/battle_ended fire at real action sites
- [ ] All tests pass headless (`godot --headless --path . -s tests/runner.gd`)
