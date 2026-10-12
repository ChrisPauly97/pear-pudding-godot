# TID-788: Gear stat system (card-framed stats wired into combat)

**Goal:** GID-187
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User (2026-10-11): gear should curve from basic single-stat items (health only / armour only) to items with
secondary stats, "all of the above, perhaps also add new stats like WoW does". Gear should be about **60 % of a
level-30 player's power** (the rest from levelling).

Today an item has one `battle_effect_type` (starting_hp, starting_armor, starting_mana, passive_atk, offhand_atk,
deck_inject) scaled by `GearRolls.mult` (rarity × 2 % per ilvl). Flat values (chainmail +12 HP) vanish against a
level-30 hero (175 HP).

Build pure `game_logic/items/GearStats.gd`: the stat table, how each stat converts to a combat effect, and
rating-per-% that grows with level (WoW-style, so old gear fades). Proposed stats (user to confirm the list):

| Stat | Effect | Bands |
|---|---|---|
| Stamina | + max HP | all |
| Armor | soaks damage (`HeroState.armor`) | all |
| Power | + % outgoing damage (all schools) | Fine+ |
| Crit | + crit chance (`crit_chance` path, swings + spells) | Fine+ |
| Haste | − GCD / cast / swing time | Fine+ |
| Spirit | + mana regen | Fine+ |
| Intellect | + max mana | Fine+ |
| Mastery (school) | + % damage of one school (replaces the `school_dmg` affix) | Superior+ |
| Versatility | + % damage dealt and − % damage taken | Superior+ |
| Leech | heal for % of damage dealt | Superior+ |
| Block | off-hand: chance to halve a hit | Superior+ |
| Resist (school) | − % damage of one school (replaces the `school_resist` affix) | Superior+ |

## Research Notes

- Effects applied in `BattleSetup.apply_gear` (sim + game) and `BattleModifiers._apply_equipment_effects`.
- Hooks: max HP `HeroState.max_health`; armor `HeroState.add_armor`; outgoing `DamageResolver.power_mult`
  (`school_power`, `level_power` — GID-186); crit `PlayerCaster.modify_power` + `RealtimeCombat` swing crit
  (`crit_chance`); timing `RealtimeCombat._gcd_total`, `swing_speed`, cast times in `PlayerCaster`; mana
  `max_mana_for(level, bonus_mana)`, regen `mana_regen`; resist `DamageSchools.capped_resists` (`max_player_resist`).
- Conversion knobs go in `CombatTuning` (rating per 1 % at level L), not constants.
- Turn-based: Stamina / Armor / Power / Intellect / Resist apply; timing stats are real time only.

## Plan

User decision (2026-10-11, spec Identity "not a stat bar"): **stats are boosts to the cards**, not a stat bar —
"haste for draw speed, spell crit for damage by spells, physical crit for damage with weapons / Strike". Stamina /
Armor stay hero stats (the Basic band's "health only / armour only"). Versatility dropped (a pure stat bar);
Command added (Allies are cards).

| Stat | Card effect | Mode |
|---|---|---|
| stamina | + hero max HP (1 HP per point) | both |
| armor | + hero armor | both |
| intellect | + max mana (cost units) | both |
| spell_power | + % power of damage / heal spells and magic techniques | real time |
| attack_power | + % damage of hero swings, Strike and physical damage / heal cards | real time |
| spell_crit | + crit chance of magic damage / heal cards | real time |
| phys_crit | + crit chance of hero swings and physical damage / heal cards | real time |
| haste | faster draws and technique returns (÷ 1 + haste) | real time |
| spirit | + % mana regen | real time |
| command | + % damage of Ally swings | real time |
| leech | heal the hero for % of damage the player side deals | both |
| block | chance to halve a hit on the hero | both |
| mastery:<school> | + % damage of that school (school_power) | both |
| resist:<school> | − % damage of that school taken (capped) | both |

1. Pure `game_logic/items/GearStats.gd`: stat table, `totals(items)`, rating → % at a level
   (`stat_rating_base` × (1 + `stat_rating_growth` × (L − 1)) rating per 1 %, capped `stat_pct_cap`), `apply(player,
   totals, level, tune)` storing converted values on `PlayerState.gear` (Dictionary).
2. `WeaponData.stats` export (hand-made stats; TID-789 fills it). `BattleSetup.apply_gear` reads item `stats` and the
   weapon's `stats`, `apply_school_power` / `school_resist_sources` take mastery / resist stats.
3. Hooks: `PlayerCaster.modify_power` (spell / attack power, crits), `RealtimeCombat._resolve_swing` (attack power,
   phys crit, command), draw interval + technique recycle (haste), `_regen_mult` (spirit), `DamageResolver.deal`
   (leech, block).
4. Tests `test_gear_stats.gd`; docs (`balance-sim.md`, new section in `inventory-and-deck.md`).

## Changes Made

- `game_logic/items/GearStats.gd` (new): stat table (`FLAT`, `PERCENT`, `SCHOOL_KINDS`, `LABELS`), `totals`,
  `rating_per_pct` / `pct` / `convert_ratings`, `apply`, `resist_sources`, `boost`.
- `CombatTuning` "Gear stats" knobs: `stat_rating_base` 1.0, `stat_rating_growth` 0.1, `stat_pct_cap` 0.5,
  `block_mult` 0.5.
- `PlayerState.gear` + `gear_stat(id)` + `leech_carry`; `WeaponData.stats` export.
- `BattleSetup.apply_gear(…, player_level, tune)` applies stats (sim `build` passes its tuning);
  `school_resist_sources(…, gear_conv)` adds `resist:<school>`; `BattleModifiers` passes `sm.level` and the gear.
- Hooks: `PlayerCaster.modify_power` (spell / attack power, spell / physical crit), haste on technique returns;
  `RealtimeCombat` draw timer (haste), `_regen_mult` (spirit), `_resolve_swing` (attack power + physical crit on hero
  swings, command on Ally swings); `DamageResolver.blocked` / `leech`.
- No item has stats yet, so balance is unchanged (bands pass as before).
- Tests: `tests/unit/test_gear_stats.gd` (11 cases).
- Backlog: BID-104 (spec wording, human edit).

## Documentation Updates

- `docs/agent/inventory-and-deck.md` → Gear Stats.
