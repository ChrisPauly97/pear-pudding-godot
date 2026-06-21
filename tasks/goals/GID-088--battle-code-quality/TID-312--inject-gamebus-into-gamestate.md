# TID-312: Inject GameBus emitter into GameState via Callable

**Goal:** GID-088
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

`GameState.end_turn` (game_logic/battle/GameState.gd:35-39) accesses `Engine.get_main_loop().root.get_node("/root/GameBus")` to emit signals. `game_logic/` is supposed to be rendering-free and tree-agnostic (spec: all cross-system communication via GameBus, but logic classes should receive a reference or emit through an injected callable, not query the tree).

Fix: add a `signal_emitter: Callable` field to `GameState`; `BattleScene` injects a lambda at construction that forwards to GameBus. `GameState` calls `signal_emitter.call(signal_name, args)` instead of looking up the tree.

## Plan

## Changes Made

## Documentation Updates
