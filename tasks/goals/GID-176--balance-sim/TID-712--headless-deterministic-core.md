# TID-712: Headless-safe, seeded battle core

**Goal:** GID-176
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The simulator must run battle logic without the scene tree or audio, and the same seed must replay the same fight exactly.

## Research Notes

- `RealtimeCombat._init` calls `rng.randomize()` (game_logic/battle/RealtimeCombat.gd ~line 122). Add an optional seed (e.g. `RealtimeCombat.new(state, levels, tuning, seed)` or a `reseed(seed)` method); the scene keeps randomizing.
- Global-RNG calls (`shuffle()`, `randi()`, `randf()`, `pick_random`): about 8 in game_logic/battle/*.gd + scenes/battle/SpellEffectResolver.gd (e.g. `PlayerState.draw_deck.shuffle()` lines ~66/102, `RealtimeCombat.trim_hand` shuffle, AI choices). Either route them through a passed RNG or have the sim call `seed(n)` before each fight. `seed()` is simpler; then prove determinism with a test.
- Autoload calls on the resolve path: `SpellEffectResolver.resolve_spell` → `AudioManager.play_sfx` (lines ~100/142). Guard so it no-ops headless; `-s` scripts can't reference autoloads by name (CLAUDE.md "Unsafe Access"). Use `Engine.get_main_loop().root.get_node_or_null("AudioManager")` + `.call()`, or a static `quiet` flag. Grep `game_logic/battle` and the resolver for other `GameBus` / `SceneManager` / `AudioManager` uses on the fight path.
- `CaptureTracker` (resolver field) is optional; check that a null tracker is safe.
- Test: `tests/unit/test_battle_determinism.gd` builds two identical GameState + RealtimeCombat with the same seed, advances both N ticks at a fixed dt, and asserts identical event logs and HP. A different seed should diverge.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
