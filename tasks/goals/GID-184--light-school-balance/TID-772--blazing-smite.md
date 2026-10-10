# TID-772: Blazing Draw → light smite + draw (`smite_draw` effect)

**Goal:** GID-184
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal.md. BID-101: light matched fill is pyroblast + blazing_draw; blazing_draw deals no damage.

## Research Notes

- Resolver: `scenes/battle/SpellEffectResolver.gd` (`deal_damage_single` arm, `ENEMY_TARGETED_EFFECTS`). Hero-target checks
  for `deal_damage_single` are hard-coded in `BattleTargeting.gd` (94, 163), `BattleInput.gd` (153), `BalanceBot.gd` (140).
- Labels `game_logic/battle/SpellEffectLabels.gd`; skill mods `SkillMods.DAMAGE_EFFECTS`; real-time power `TechniqueDefs` (`rt_value`).
- Builder hits come from `PlayerCaster._after_technique` (dealt > 0), so any damaging effect is a builder.
- Bands: `BalanceBands.check_schools` / `report_schools`, `SCHOOL_BAND` 25, `SCHOOL_FIGHTS` 14. TID-771 after-table
  (default/light/dark/verdant/rift): grass 79/57/71/100/79, forest 50/14/50/43/21, desert 64/29/100/100/71,
  scorched 43/14/64/64/29, mountains 50/21/64/57/14.

## Plan

1. New `smite_draw` effect (single-target damage, then draw 1) sharing the `deal_damage_single` arm.
2. One `HERO_TARGETABLE_EFFECTS` list instead of four hard-coded checks.
3. Blazing Draw uses it; labels, SkillMods damage list, skill text; unit test.

## Changes Made

- `scenes/battle/SpellEffectResolver.gd`: `smite_draw` in `ENEMY_TARGETED_EFFECTS`, new `HERO_TARGETABLE_EFFECTS`, arm draws one after the hit.
- `BattleTargeting.gd`, `BattleInput.gd`, `BalanceBot.gd`: use `HERO_TARGETABLE_EFFECTS`.
- `SpellEffectLabels.gd`, `SkillMods.DAMAGE_EFFECTS`: `smite_draw`.
- `data/cards/tech_blazing_draw.tres` (smite_draw, power 3), `data/skills/ember_blazing_draw.tres` text.
- `tests/unit/test_technique_cards.gd`: `test_blazing_draw_smites_and_draws`.
- Validation: editor parse clean, `unsafe-hits.sh` clean, gdlint clean, runner 3460 pass / 0 fail / 0 SCRIPT ERROR.

## Documentation Updates

- `docs/agent/combat-model.md` skill-tree technique table, `docs/agent/skill-trees.md` Ember row.
