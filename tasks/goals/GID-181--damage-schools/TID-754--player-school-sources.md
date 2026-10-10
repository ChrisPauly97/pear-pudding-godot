# TID-754: Player school sources: skill-tree nodes, gear affixes, conversion

**Goal:** GID-181
**Type:** agent
**Status:** done
**Depends On:** TID-749, TID-751

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The horizontal reward: players collect ways to deal and resist different schools rather than bigger flat numbers. Spec identity says progression grants cards, not stat bars — keep sources card-centric where possible.

## Research Notes

- Skill tree: `game_logic/battle/SkillMods.gd` (GID-179) builds per-fight card modifiers from unlocked skills (`add(effect_type, value, filter)`, `matches(card, filter)`). Add effect types `school_power` (+% to cards of a school) and `school_resist`; nodes in skill .tres files under data/skills (preload rule for Android). Real-time only (skill_mods is null in turn-based) — check whether turn-based needs parity.
- Gear: rolls in `game_logic/items/GearRolls.gd` `roll(tier, level, rng)` L37, stored via `autoloads/save_manager/SaveGear.gd` (`roll_of`, `mult`, `grant`); applied in `BattleSetup` equipment effects (~L49–85 `UpgradeDefs.effective_stat(weapon, level, gm)`). Add an affix slot to the roll dict: `{school_dmg: {school, pct}}`, `{school_resist: {school, pct}}`, rare `{convert: school}` (weapon auto-attack / Strike deals that school). Old saves: missing affix = none (SaveMigrations row only if shape changes).
- **User decision 2026-10-10:** school affixes sit **on top of** the existing item-level stat rolls — do not shrink or replace the stat rolls. Levels uncapped, no enemy scaling.
- Gear tooltip/paper doll: `game_logic/character/PaperDollGear.gd`, drop message `SaveGear.drop_message`.

## Plan

1. Outgoing school power: optional `attacker` param on `DamageResolver.deal` / `scaled_amount`, multiplying
   by `1 + school_power`; route spells, real-time swings and local attacks.
2. Skill tree: `school_power` / `school_resist` effect types (`SkillMods.school_nodes`, all fight modes);
   four row-3 nodes, tree grows to four rows.
3. Gear: optional `affix` on the roll (`school_dmg` / `school_resist` / `convert`), chance by tier, after the
   stat roll; normalized in `GearRolls`; applied in `BattleSetup` and `BattleModifiers`; shown in the
   CharacterScene picker and `SaveGear.drop_message`.
4. Tests for each part; balance sim unchanged by default (no sources).

## Changes Made

- **Outgoing power.** `DamageResolver.deal(..., tune, attacker)` and `scaled_amount(..., tune, attacker)`;
  `power_mult(attacker, school)`. `PlayerState.school_power` (school → fraction) and `convert_school` +
  `weapon_school()`. Attacker passed from `SpellEffectResolver` (all player-side arms, emergence),
  `RealtimeCombat._resolve_swing`, `BattleInput._execute_attack`.
- **Convert.** Hero swings hit as `weapon_school()`; `tech_strike` (Strike) hits as `weapon_school()`.
- **Skill nodes.** `SkillMods.school_nodes`; `SkillData` doc. New `.tres` + `.uid`: `ember_kindled_light`,
  `dawn_sunward_ward`, `dusk_umbral_edge`, `bloom_rooted_ward` (row 3, col 3, prerequisite the row-2 col-3
  node). `SkillRegistry` preloads them. `SkillTreeScene._ROWS` 3 → 4.
- **Gear.** `GearRolls`: `AFFIX_CHANCE`, `AFFIX_KINDS`, `AFFIX_KIND_WEIGHTS`, `clean_affix`, `roll(..., weapon)`,
  `affix_label`; `normalize` keeps a valid affix only. `SaveGear.roll_for` (weapon from slot) used by ChestLoot,
  BattleVictory, CoopActivities; `drop_message` names the affix.
- **Battle wiring.** `BattleSetup.apply_school_power`, `school_resist_sources`, `_affix_of`, `_add_school`;
  `build()` (balance sim) applies the same. `BattleModifiers._equipped_items()` carries each roll's affix;
  `_school_resist_sources()` fills the TID-751 seam.
- **UI.** `CharacterScene` gear picker shows the affix line under the item name.
- **Tests.** `tests/unit/test_school_sources.gd` (27 cases).

**Deviations.** (1) The gear tooltip is the CharacterScene picker row; `PaperDollGear` draws sprites and has no
text labels. (2) The affix `pct` is a fraction (0.15 = 15 %), as in the task spec; skill node values are whole
percent. (3) Sources are read at solo battle start only (like equipment), so PvP and co-op fights have none, and
a resumed mid-fight save loses them (same gap as `env_school_mult`, BID-098). (4) `BattleNet` replay passes no
attacker, so PvP replays stay neutral. (5) The `school_resist` skill nodes are placed on a new row 3, so
`SkillTreeScene._ROWS` went from 3 to 4 instead of reusing a slot (all 6 existing slots per branch are taken).

## Documentation Updates

- `docs/agent/damage-schools.md`: "Player School Sources (TID-754)" section, resolver order with attacker power,
  known gap for resumed fights, test list, planned list.
- `docs/agent/skill-trees.md`: school effect types, row-3 school nodes, roster count, `SkillMods.school_nodes`,
  tree row meaning.
- `docs/agent/inventory-and-deck.md`: school affix paragraph in "Equipment System".
