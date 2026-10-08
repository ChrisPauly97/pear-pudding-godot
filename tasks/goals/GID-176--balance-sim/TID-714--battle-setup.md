# TID-714: Shared pure battle setup

**Goal:** GID-176
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
