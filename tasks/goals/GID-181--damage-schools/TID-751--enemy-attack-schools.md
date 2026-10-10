# TID-751: Enemy attack schools + hero school resistances

**Goal:** GID-181
**Type:** agent
**Status:** done
**Depends On:** TID-749, TID-750

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Resistance only matters both ways if enemies hit with a school and the player can resist it. Sets up the defensive half that TID-754 feeds.

## Research Notes

- Enemy unit hits: school from the attacking card (`CardInstance.magic_type`, else physical); enemy hero swings/heavy (`RealtimeCombat.heavy_damage` L747, main_hand_damage L495): add optional `attack_school` per enemy type in EnemyRegistry (default physical).
- Player profile: `HeroState` gets a `school_resist: Dictionary` (school → fraction 0..0.75 cap) filled at battle start by `BattleModifiers` (equipment/skills/companion live there); the TID-749 resolver reads it for player-side targets. Allies (player minions) use their own card school? — decide in Plan; default neutral.
- Cap total resist in CombatTuning (`max_player_resist`).
- Co-op/PvP: HeroState is serialized via to_dict/from_dict — add the field there (see CLAUDE.md: reconnect signals when replacing from_dict state).
- **Also in scope (coordinator, late):** nothing fills `PlayerState.school_profile` yet. At battle setup (BattleSetup / BattleModifiers) set the enemy side's `school_profile = EnemyRegistry.get_school_profile(type_id)` and swap to phase 2 when the boss phase changes; set the player side's from the hero resists. Resolver: `game_logic/battle/DamageResolver.gd`. Balance bands move once profiles are live: regenerate the baseline if only drift fails.

## Plan

1. Enemy profiles: `BattleSetup.setup_enemy` fills `school_profile` (phase 1). This covers the solo scene and the balance sim. `BattleScene._check_boss_phase2` swaps to phase 2. A resumed fight re-derives the profile from `_enemy_type`, which is now saved.
2. Enemy attack school: optional `attack_school` per enemy type (`EnemyRegistry.get_attack_school`, default physical). `RealtimeCombat.enemy_attack_school` applies it to enemy hero swings and heavy blows only. Enemy minions keep their card school (TID-749).
3. Player resists: `HeroState.school_resist` (fraction per school), serialized. Filled at solo battle start by `BattleModifiers._apply_school_resists` from `_school_resist_sources()`, which is empty until TID-754. Capped by the `max_player_resist` knob. Applied in `DamageResolver` after the profile scaling.
4. Player profile: left empty. Resist tags would stack the `resist_mult` knob on top of the fraction, so the fraction is the only player-side number. This departs from the coordinator's "set the player side's profile from hero resists" and is noted in `docs/agent/damage-schools.md`.
5. Allies: they keep their card school (TID-749 already does this). Nothing new.
6. Balance: run `tests/balance_bands.gd`, tune minimally if an absolute band fails, then regenerate the baseline if only drift fails.

## Changes Made

- `autoloads/EnemyRegistry.gd`: `attack_school` on 22 enemy types (undead/dark spectres = dark; forest shades, bog hags, imbued stags, mimics = verdant; rift echoes, roaming terrors, ember cultists, Isfig rivals = rift). New `get_attack_school()` validated through `DamageSchools.is_school`. Balance tunes: forest shade's `physical` resist removed (kept `verdant`); bog hag's `physical` weakness removed.
- `game_logic/battle/BattleSetup.gd`: `setup_enemy` fills the enemy profile; `configure_realtime` sets `rt.enemy_attack_school`.
- `game_logic/battle/RealtimeCombat.gd`: `enemy_attack_school`; enemy hero swings (`_resolve_swing` with no attacker) and `_land_heavy` use it.
- `game_logic/battle/HeroState.gd`: `school_resist` field, in `to_dict` / `from_dict`.
- `game_logic/battle/DamageSchools.gd`: `capped_resists()` and `resist_of()`.
- `game_logic/battle/DamageResolver.gd`: `scaled_amount` multiplies in the hero resist fraction; `resist_fraction()`; `deal` reports `"resist"` for a school only a hero resist touches.
- `game_logic/battle/CombatTuning.gd`: `max_player_resist` knob (0.75, 0–0.95).
- `scenes/battle/modules/BattleModifiers.gd`: `_apply_school_resists` and the `_school_resist_sources()` seam (empty).
- `scenes/battle/BattleScene.gd`: resist applied at solo battle start; enemy phase 2 profile at the boss turn; `_enemy_type` saved, and the profile re-derived on resume.
- Tests: `tests/unit/test_damage_resolver.gd` (hero resist scaling, stacking, clamp, round-trip); `tests/unit/test_enemy_school_profiles.gd` (attack schools valid, undead and forest strike with their school, `setup_enemy` fills the profile).
- `tests/data/balance_baseline.json`: regenerated. Only the wolf pack medians changed (+0 30.1 → 19.9 s, +1 34.3 → 24.0 s).

**Validation:** parse check clean; `scripts/unsafe-hits.sh` clean; gdlint clean; `tests/runner.gd` exit 0, 3277 passed, 0 failed, 0 SCRIPT ERROR; all 24 `tests/*smoke*.gd` exit 0 with 0 SCRIPT ERROR; `tests/balance_bands.gd` PASS.

**Balance (same level / one level up):**
- forest_shade 6: 100/100 before → 95/0 wired untuned → 100/100 after tuning.
- bog_hag 7: 100/77.5 before → 100/100 wired untuned → 100/77.5 after tuning.
- wolf_pack 5: 100/100 unchanged; median 30.1 s → 19.9 s (+0).
- One-level-up mean: 74% untuned, 86% with only forest fixed, 83% after both tunes (band 65–85%).

## Documentation Updates

- `docs/agent/damage-schools.md`: intro updated; new section "Enemy Attack Schools and Hero Resistances (TID-751)" covering the setup wiring, phase 2, resume, the attack-school table, the hero resist fraction and its reason, the balance table, and tests. Enemy table rows for forest_shade and bog_hag and the armoured bullet updated. Integrations and the Planned list updated.
- `CLAUDE.md` already lists the doc (line 744).
