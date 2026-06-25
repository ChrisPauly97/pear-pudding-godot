# TID-312: Inject GameBus emitter into GameState via Callable

**Goal:** GID-088
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

`GameState.end_turn` (game_logic/battle/GameState.gd:35-39) accesses `Engine.get_main_loop().root.get_node("/root/GameBus")` to emit signals. `game_logic/` is supposed to be rendering-free and tree-agnostic (spec: all cross-system communication via GameBus, but logic classes should receive a reference or emit through an injected callable, not query the tree).

Fix: add a `signal_emitter: Callable` field to `GameState`; `BattleScene` injects a lambda at construction that forwards to GameBus. `GameState` calls `signal_emitter.call(signal_name, args)` instead of looking up the tree.

The actual `Engine.get_main_loop()` call is in `PlayerState._emit_fatigue()`, not in `GameState.end_turn()` itself. So the chain is:
- `PlayerState._emit_fatigue(dmg)` → `Engine.get_main_loop()` → GameBus
- Fix: `PlayerState.gamebus_emitter: Callable` injected from `GameState.inject_gamebus_emitter()`
- `BattleScene` calls `_state.inject_gamebus_emitter(...)` after each state creation.

## Plan

1. `PlayerState.gd`: add `var gamebus_emitter: Callable = Callable()` field; change `_emit_fatigue` to use it (fall back to silent no-op when not set, preserving test behaviour)
2. `GameState.gd`: add `var gamebus_emitter: Callable = Callable()`; add `inject_gamebus_emitter(emitter)` that propagates to all `players`; call propagation at end of `from_dict()` so newly created PlayerState objects also get the emitter
3. `BattleScene.gd`: add helper `_wire_gamebus_emitter()` that calls `_state.inject_gamebus_emitter(func(pid, dmg): GameBus.fatigue_damage.emit(pid, dmg))`; call it after every `_state = GameState.new()` or `_state.from_dict()` site

## Changes Made

- `game_logic/battle/PlayerState.gd`: added `var gamebus_emitter: Callable = Callable()` field; changed `_emit_fatigue` to call it instead of `Engine.get_main_loop()`. Falls back to no-op when not set (preserves test isolation).
- `game_logic/battle/GameState.gd`: added `var gamebus_emitter: Callable = Callable()`; added `inject_gamebus_emitter(emitter)` and `_propagate_emitter()` which pushes the callable to all PlayerState instances; called `_propagate_emitter()` at end of `from_dict()` so newly deserialized PlayerState objects inherit it.
- `scenes/battle/BattleScene.gd`: added `_wire_gamebus_emitter()` helper emitting `GameBus.fatigue_damage`; called it after every site that creates or deserialises a GameState (`_ready`, `_show_puzzle_fail`, `_setup_pvp_battle`, `_on_pvp_state`).

## Documentation Updates

None required — `docs/agent/battle-system.md` already documents the GameBus decoupling pattern.
