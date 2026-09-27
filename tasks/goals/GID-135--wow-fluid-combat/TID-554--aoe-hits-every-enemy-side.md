# TID-554: AoE Spells Must Hit Every Enemy Side, Not Just opponent()

**Goal:** GID-135
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Reported: in an adds/team fight, board-wide AoE spells (deal damage to all enemy minions, poison all,
freeze all, etc.) only hit the lowest-HP enemy side instead of every living enemy side.

## Research Notes

`SpellEffectResolver.resolve_spell()` resolves every multi-target ("_all") effect against
`_state.opponent()`, which by design (`GameState.opponent()`) returns a *single* `PlayerState` — the
enemy-team member with the lowest hero HP in a team battle, or the single alive ally with the lowest HP
when the co-op boss casts. That's the correct auto-target for a *single-target* effect (mirrors the
existing attack-targeting rule), but every effect that loops `opponent.board.get_cards()` to hit the
whole board inherits the same single-side narrowing — so a team fight's AoE only ever hits one enemy, and
a co-op boss's AoE only ever hits one ally instead of the whole party.

`GameState` had no existing "every member of the opposing side" accessor — only `opponent()` (one) and
its private helpers `_get_lowest_hp_enemy_team_member()` / `_get_lowest_hp_ally()`. 2-player duels are
unaffected either way (`opponent()` there is already "the only enemy").

Real-time combat (`RealtimeCombat.gd`, GID-135/TID-551) already supports a second enemy joining a fight as
an "add": `add_enemy()` sets `state.team_battle = true` with `player_teams = [0, 1, 1, …]` (you vs. every
enemy), reusing the same `team_battle` mechanism turn-based 2v2 duels use. So this bug is live today in
real time as soon as an add is present, not just in turn-based team duels / co-op.

`_explicit_opponent()` (added for real-time explicit-target picks — tapping a specific enemy's minion or
hero) is unrelated and untouched: it decides which single enemy a *single-target* spell aims at when
several exist. This task only touches the board-wide ("_all"/"low HP"/"debuff") arms, which have no
per-target pick to make — every living enemy side is the answer, not one.

## Plan

1. Add `GameState.enemy_sides(caster_pid) -> Array[PlayerState]`: every alive member of the side
   opposing `caster_pid` — the other player (2-player), every alive enemy-team member (team battle,
   including a real-time add), or the boss / every alive ally (co-op, by whose turn it is). Falls back to
   `[opponent()]` if the whole opposing side is (impossibly) dead.
2. Change every AoE/board-wide match arm in `SpellEffectResolver.resolve_spell()` to loop
   `_state.enemy_sides(caster_pid)` instead of the single `opponent`: `deal_damage_all` /
   `deal_damage_all_full` (damage + hero damage + dead-sweep), `apply_poison_all`, `freeze_all`,
   `debuff_attack`, `destroy_low_hp`. Single-target effects (`foe`/`friend`, `deal_damage_single`,
   `deal_damage_random`, etc.) are unchanged — they keep the existing single auto-target / explicit-target
   rule via `_explicit_opponent()`.
3. Scope: this expands co-op boss AoE from "hits the lowest-HP ally" to "hits every alive ally" — a
   deliberate behaviour change, since it's the same underlying bug (an AoE effect narrowed to one side)
   and the correct fix for a "boss vs. the whole party" AoE. 2-player PvP/PvE duels are unaffected
   (`enemy_sides()` there is always `[opponent()]`, identical to before).
4. Unit tests for `enemy_sides()` directly and for each changed match arm, in team battle and co-op
   contexts, plus a 2-player regression test proving the single-enemy case is unchanged.

## Changes Made

- `game_logic/battle/GameState.gd`: added `enemy_sides(caster_pid) -> Array[PlayerState]`.
- `scenes/battle/SpellEffectResolver.gd`: `deal_damage_all`/`deal_damage_all_full`, `apply_poison_all`,
  `freeze_all`, `debuff_attack`, `destroy_low_hp` now loop `_state.enemy_sides(caster_pid)` instead of the
  single `opponent`.
- `tests/unit/test_spell_effect_resolver_aoe.gd` (new): `enemy_sides()` coverage (2-player, team battle
  incl. a dead team member, co-op ally turn vs. boss turn incl. a downed ally), and per-effect coverage
  that a team battle's two enemy boards are both hit, that a co-op boss's AoE now hits every ally (not
  just the lowest-HP one), and a 2-player regression case.
- Full suite (2651 → 2661 after TID-547/555 landed alongside), gdlint and `scripts/unsafe-hits.sh` clean;
  `world_scene_smoke`, `realtime_battle_smoke`, `in_world_battle_smoke`, `net_attack_replay_smoke`,
  `coop_pve_ai_turn_smoke` all pass with zero SCRIPT ERROR.

## Documentation Updates

- `docs/agent/combat-model.md` → "Adds — a second enemy joins (TID-551)": that section already named this
  exact bug ("Untargeted AoE spells still hit the lowest-HP enemy's side only") as a known limitation.
  Updated it to describe the fix: `GameState.enemy_sides(caster_pid)` and the list of board-wide effects
  that now use it, noting the same fix also covers co-op boss AoE against the whole party.
