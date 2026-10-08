# TID-714: Shared pure battle setup

**Goal:** GID-176
**Type:** agent
**Status:** done
**Depends On:** TID-712

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Fight setup is spread across BattleScene._ready, BattleModifiers and BattleRealtime.maybe_start. A sim needs the same setup without the scene.

## Research Notes

- Scene setup to mirror (`scenes/battle/BattleScene.gd` ~480–575): player deck (`build_deck_from_instances` / `build_deck`), `modifiers._apply_combat_unlocks` (techniques always, minions/spells by `learned_abilities`), `_apply_equipment_effects`, `_apply_passive_skills`, opening hand 4; enemy tier = `EnemyRegistry.get_difficulty_tier` (boss → 4) then `_ZoneLevels.scaled_tier(tier, enemy_level)`; `modifiers.trait_deck`; `players[1].build_deck(deck, tier)`; `modifiers._place_enemy_pack`; boss HP; `modifiers._apply_zone_level(enemy_level)`; `_apply_persistent_hp` (sim: full HP); companion start.
- Real-time setup (`BattleRealtime.maybe_start` ~95–125): `enemy_level_for_tier`, `CombatTuning.new(overrides)`, `RealtimeCombat.new(state, [player_level, enemy_level], tuning)`, `heavy_enabled` (kick learned), `set_enemy_minion_cap` / `set_ally_cap` / `trim_hand` via `CombatOnboarding`, `weapon_speed` / `offhand_damage` from gear, `set_passive`.
- Out of scope for the sim: weather, gambits, ambush, blight, spire/siege HP carry-over, co-op. List them as sim parameters later if needed.
- New `game_logic/battle/BattleSetup.gd`: `static func build(cfg: Dictionary) -> Dictionary` returning `{state, rt}`. cfg = {player_level, learned (Array), deck (template ids), weapon, offhand, enemy_type, enemy_level, tuning, seed}. Have the scene call the shared pieces (at least the tier/level math and the RealtimeCombat config) so they can't drift; full scene refactor not required.
- Many BattleModifiers helpers read `SceneManager.save_manager`. Pass values in instead for the pure path.
- Test: `BattleSetup.build` for the starter deck vs `undead_basic` gives the same enemy tier/HP/deck size and caps as the scene (compare against numbers the scene computes in a smoke run).

## Plan

Medium–high complexity, but the design was settled in the task notes, so I proceeded without an approval stop.
1. New pure `BattleSetup` statics for each setup piece.
2. The scene and modifiers call them with save-derived values; the scene keeps banners, gambits, blight, etc.
3. `build(cfg)` for the sim in the scene's order.
4. Equivalence guard in realtime_battle_smoke (mutation-checked) + unit tests.

## Changes Made

- New `game_logic/battle/BattleSetup.gd`: `unlock_filter`, `apply_gear`, `apply_passives`, `offhand_damage_for_item`, `weapon_speed_for_item`, `enemy_tier`, `enemy_level_for_tier`, `setup_enemy`, `mirror_deck`, `place_pack`, `enemy_round`, `configure_realtime`, `apply_live_tuning`, `build`, `starter_deck`.
- `scenes/battle/BattleScene.gd` `_setup_solo_battle`: enemy tier / deck / pack / boss HP / zone HP now come from `BattleSetup.enemy_tier` + `setup_enemy`, then `modifiers.set_trait_source`.
- `scenes/battle/modules/BattleModifiers.gd`: equipment, passives, combat unlocks and enemy traits delegate to BattleSetup. `_place_enemy_pack`, `_apply_zone_level` and `trait_deck` were removed (moved), along with unused preloads.
- `scenes/battle/modules/BattleRealtime.gd`: `maybe_start` calls `configure_realtime`; `_apply_live_tuning`, `enemy_level_for_tier`, `equipped_weapon_speed` and `offhand_damage_for_item` forward to BattleSetup (kept for existing callers and tests). Unused preloads removed.
- Tests: new `tests/unit/test_battle_setup.gd` (7), plus `_check_setup_matches_sim` in `realtime_battle_smoke` comparing the sim build to the live scene (7 values). Mutation-checked: skipping `configure_realtime` produces 3 mismatches.
- Behaviour note: a solo fight whose `enemy_data` has no `enemy_deck` kept GameState's default deck before and still does; an explicitly empty deck now also keeps it (it used to wipe it). No caller passes one.
- Found and fixed (pre-existing since GID-175, not caused here): `battle_input_flow_smoke`'s auto-end-turn check failed intermittently. It zeroed mana to mean "nothing playable", but a drawn 0-cost technique card (Strike) is still playable. Reproduced deterministically by putting Strike in hand; the test now also drops free cards from the hand. The game behaviour (no auto-end while a free card is playable) is correct.
- Validation: full suite PASS with 0 SCRIPT ERROR; all 12 CI smoke tests clean (battle_input_flow re-run after the fix); gdlint and unsafe-hits clean.
- BID-094: progress noted; the remaining scene-only modifiers stay logged there.

## Documentation Updates

combat-model.md → new "BattleSetup — shared fight setup" section.
