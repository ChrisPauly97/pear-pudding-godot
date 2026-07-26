# BID-010: Battle drag-to-play is hand-rolled; GameState reaches into the SceneTree

**Category:** code-smell
**Discovered During:** GID-064 audit

## Description

Two non-native patterns in the battle layer, both working but fighting the engine:

1. Drag-to-play is hand-rolled global `_input` mouse tracking with a manual ghost
   Control (scenes/battle/BattleScene.gd:329-421) instead of Godot's
   `_get_drag_data` / `_can_drop_data` / `_drop_data` (or at least `_gui_input` on the
   hand panel).
2. `GameState.end_turn` (game_logic/battle/GameState.gd:35-39) reaches into the
   SceneTree to find the GameBus node from pure logic code — game_logic/ is supposed to
   be rendering-free and tree-agnostic (spec: all cross-system communication via
   GameBus, but logic classes should receive a reference or emit through an injected
   callable, not query the tree).

## Evidence

See file:line references above.

## Suggested Resolution

Migrate drag-to-play to native Control drag-and-drop in a dedicated task (touch
behaviour on Android must be re-verified — native drag uses touch by default but the
long-press-inspect interaction needs rechecking). For GameState, inject a signal-emitter
Callable at construction instead of tree lookup.
