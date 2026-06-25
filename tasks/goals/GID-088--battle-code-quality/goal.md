# GID-088: Battle Code Quality — GameState Decoupling & Native Drag

## Objective

Remove two non-native patterns in the battle layer: inject the GameBus emitter into GameState instead of querying the SceneTree from pure logic code, and migrate drag-to-play to Godot's native Control drag-and-drop API.

## Context

Two code-quality issues found during the GID-064 audit: (BID-010)

1. `GameState.end_turn` (game_logic/battle/GameState.gd:35-39) calls `Engine.get_main_loop().root.get_node("/root/GameBus")` to reach the GameBus singleton from pure logic code. `game_logic/` is supposed to be rendering-free and tree-agnostic per the project architecture. The fix is to inject a signal-emitter Callable at construction.

2. Drag-to-play is hand-rolled via global `_input` mouse tracking with a manual ghost Control (scenes/battle/BattleScene.gd:329-421) instead of Godot's `_get_drag_data` / `_can_drop_data` / `_drop_data`. Native drag works on touch by default, but the long-press-to-inspect interaction must be re-verified on Android.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-312 | Inject GameBus emitter into GameState via Callable | agent | done | — |
| TID-313 | Migrate battle drag-to-play to native Godot drag-and-drop | agent | done | TID-312 |

## Acceptance Criteria

- [ ] `GameState` no longer references `Engine.get_main_loop()` or the SceneTree
- [ ] GameBus signal emission in GameState goes through an injected Callable set at construction by BattleScene
- [ ] Cards can be dragged to board slots using native Godot drag-and-drop
- [ ] Long-press on a card still shows the card inspect overlay (touch re-verified)
- [ ] Drag-and-drop works on both desktop (mouse) and Android (touch)
- [ ] All existing battle tests pass headless
