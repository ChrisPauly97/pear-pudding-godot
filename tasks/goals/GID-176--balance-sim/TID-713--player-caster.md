# TID-713: Extract player cast rules into a pure PlayerCaster

**Goal:** GID-176
**Type:** agent
**Status:** done
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

High complexity, but the design was settled in the task notes, so I proceeded without an approval stop. It's a behaviour-preserving extraction, guarded by the existing realtime/input smoke tests and a new unit suite.
1. New pure `PlayerCaster` holding cast state, the GCD gate, combo wrap and technique rules, emitting feedback through a `notify` Callable.
2. `BattleRealtime` forwards `run_cast` / `run_off_gcd` / `on_cooldown` / `note_player_play` / `is_casting` / `_cast_info` and maps events to toasts, stats and quests.
3. `MomentumHud.wrap_card` and the `RealtimeTechniques` rules move into the caster.
4. A `play()` / `play_blocker()` path for the simulator.
5. Unit tests, mutation-checked.

## Changes Made

- New `game_logic/battle/PlayerCaster.gd` (pure, RefCounted): `on_cooldown`, `is_casting`, `casting_card`, `cast_state`, `note_play`, `begin`, `run_off_gcd`, `tick` (pushback from HP drop since the last tick, fizzle via `rt.owner_of`), `is_off_gcd`, `technique_blocker`, `resolve_reactive`, `casting_enemy`, `_after_technique`, `_with_combo`, plus sim entry points `play_blocker` / `play(card, resolver, target)`. Feedback goes through `notify(kind, data)`.
- `scenes/battle/modules/BattleRealtime.gd`: the cast state vars, `_tick_cast` and `_target_on_board` are gone. It owns `caster` and forwards to it; the new `_on_caster_event` maps events to toasts, hit feel, `momentum.on_proc`, FightStats and `use_skill` quest progress. Still ≤ 30 public methods.
- `scenes/battle/modules/MomentumHud.gd`: `wrap_card` removed (now `PlayerCaster._with_combo`).
- `scenes/battle/modules/RealtimeTechniques.gd`: presentation only (`control_for`, `pulse_reactive`).
- `scenes/battle/modules/BattleInput.gd`: technique rules called on `realtime.caster`.
- Tests: new `tests/unit/test_player_caster.gd` (7: queue + GCD + recycle, Mend cast time + pushback, fizzle keeps the card, Kick off-GCD interrupt, combo spend, technique builds without spending, minion slot). Mutation-checked: removing pushback and removing the combo wrap each fail it.
- Behaviour notes: identical except (1) the cast bar's cost readout no longer honours the removed skill-bar `cost_points` meta (dead since TID-710); (2) hit tracking for pushback now lives in `caster.tick` instead of `_process`, which is the same order (before `rt.advance`).
- Validation: full suite PASS with 0 SCRIPT ERROR; all 12 CI smoke tests clean; gdlint and unsafe-hits clean.

## Documentation Updates

combat-model.md: new "PlayerCaster" section; technique / momentum / bark references repointed. CLAUDE.md BattleRealtime row. starter-zone and story docs: `use_skill` source.
