# TID-749: Single school-aware damage resolver

**Goal:** GID-181
**Type:** agent
**Status:** pending
**Depends On:** TID-748

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

School multipliers must apply everywhere damage happens, identically in turn-based, real-time, PvP/co-op and the balance sim. Today damage is applied directly in ~30 places, so a per-site bolt-on would drift.

## Research Notes

- `take_damage` call sites (grep): `scenes/battle/SpellEffectResolver.gd` (12 — `resolve_spell` L168, `resolve_enemy_play` L50, `resolve_emergence`), `game_logic/battle/RealtimeCombat.gd` (6 — `_resolve_swing` ~L664 already applies `BattlefieldRules.modify_damage` + `_gap_scaled` + crit; poison ticks L373/396; heavy L799), `scenes/battle/modules/BattleInput.gd` (4), `scenes/battle/net/BattleNet.gd` (4), `scenes/battle/BattleFx.gd` (2), `game_logic/battle/PlayerState.gd` (1), `BattleModifiers.gd` (1).
- Balance sim runs through `SpellEffectResolver` (BalanceBot.act takes one) and RealtimeCombat, so covering those covers the sim.
- Approach: one pure entry, e.g. `DamageSchools.apply(target, amount, school, source_side, state)` or a `GameState.deal_damage(...)` that resolves the target's profile (enemy hero/units → enemy type profile on GameState; player side → hero resist from TID-751, stub {} now) and returns `{dealt, outcome}` for UI. Keep `take_damage` as the raw HP op.
- Poison/burn DoTs: carry the school of the card that applied them, or treat as the status's own school — decide in Plan and document.
- GameState needs the enemy type id (check what BattleSetup.configure stores) to look up the profile; profile itself arrives in TID-750 — default {} = neutral, so this task is behaviour-neutral. Verify with balance bands unchanged (`tests/balance_bands.gd`).
- Add a guardrail test that greps for new direct `take_damage(` calls outside the resolver (pattern: test_hud_registry_guardrail.gd).
- Run `scripts/unsafe-hits.sh`, world/battle smoke tests and PvP smoke tests after (CLAUDE.md → Scene Modules).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
