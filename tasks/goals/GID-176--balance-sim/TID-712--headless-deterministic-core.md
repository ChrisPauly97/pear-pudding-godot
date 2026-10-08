# TID-712: Headless-safe, seeded battle core

**Goal:** GID-176
**Type:** agent
**Status:** done
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

Low complexity, so I proceeded without an approval stop.
1. Give RealtimeCombat a settable rng seed.
2. Rely on `seed()` for the global RNG instead of threading an RNG through every shuffle (smaller change, same determinism).
3. Add a static `silent` flag to the resolver for audio.
4. Determinism test, mutation-checked.

## Changes Made

- `game_logic/battle/RealtimeCombat.gd`: documented `rng` as the seed hook (`rt.rng.seed = n`). A `reseed()` method was dropped because RealtimeCombat is at gdlint's 30-public-method cap.
- `scenes/battle/SpellEffectResolver.gd`: `static var silent`, plus an `_sfx()` wrapper for both `AudioManager.play_sfx` calls.
- New `tests/unit/test_battle_determinism.gd`: a 60 s, 12-card real-time fight with enemy AI and procs. The same seed gives an identical per-tick trace (HP, mana, hand, board, deck, combo, procs); different seeds diverge. Mutation check: dropping `seed()` or the rng seed each makes the test fail.
- Audit: the only randomness on the fight path is global `shuffle()` / `randi()` (PlayerState, RealtimeCombat.trim_hand, resolver) and `rt.rng`. No `Time` / `OS` reads. The only autoload on the path is AudioManager. CaptureTracker is null-safe.
- Validation: full suite PASS with 0 SCRIPT ERROR; realtime / coop / input smoke tests clean; gdlint and unsafe-hits clean.

## Documentation Updates

combat-model.md → new "Determinism (GID-176 / TID-712)" section.
