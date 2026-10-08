# TID-713: Extract player cast rules into a pure PlayerCaster

**Goal:** GID-176
**Type:** agent
**Status:** pending
**Depends On:** TID-712

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Player-side real-time rules live in scene modules, so a simulator would have to re-implement them and drift. Move them to one pure class that the scene also uses.

## Research Notes

- From TID-712: seed a fight with `seed(n)` (global: shuffles, resolver picks) **before** building decks, plus `rt.rng.seed = n`; set `SpellEffectResolver.silent = true`. RealtimeCombat is at gdlint's 30-public-method cap, so put new logic elsewhere.
- Logic to extract (from `scenes/battle/modules/BattleRealtime.gd`): `run_cast` (cast time from `rt.cast_time_for` / `TechniqueDefs.cast_time`, spell-queue delay `_cast_delay` = remaining GCD, GCD start), `_tick_cast` (pushback via `rt.pushback_for_hit`, fizzle when a unit target left the board, `_resolving_cast` so resolution doesn't restart the GCD), `run_off_gcd`, `on_cooldown()` (queue window), `note_player_play`.
- From `scenes/battle/modules/RealtimeTechniques.gd`: `blocker`, `resolve_reactive` (Kick/Daze), `after_resolve` (builder hit → `rt.on_player_hit`, proc), `casting_enemy`.
- From `scenes/battle/modules/MomentumHud.gd`: `wrap_card` combo spend (`rt.spend_combo`, full combo → instant, free-cast proc), skipping techniques.
- Card play itself: `BattleScene._do_play_card` → `PlayerState.play_card`, then `SpellEffectResolver.resolve_spell`; minions via `play_card_at_slot`. The pure class needs `play(card, target)` covering spells (targeted/untargeted), techniques and minions (first free slot under `max_units`).
- New `game_logic/battle/PlayerCaster.gd` (RefCounted, pure): holds cast state, exposes `try_play(card, target) -> String` (reason or ""), `tick(dt)`, `is_casting()`, and signals or a returned event list for the scene's FX (toast text, lunge, float labels).
- The scene modules keep the visuals (cast bar, toasts, pulses, spotlight) and delegate the rules. `realtime_battle_smoke` + `battle_input_flow_smoke` must stay green, and the BattleRealtime public-method count must stay ≤ 30 (gdlint).
- Keep `_world`/`_battle` module rules (CLAUDE.md "Scene Modules").

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
