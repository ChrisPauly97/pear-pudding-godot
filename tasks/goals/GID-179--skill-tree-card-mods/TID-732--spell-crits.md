# TID-732: Spells and techniques can crit (real time)

**Goal:** GID-179
**Type:** agent
**Status:** done
**Depends On:** TID-731

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal.md (user request 2026-10-09).

## Research Notes

- Swing crits: `RealtimeCombat._resolve_swing` (seeded `rng`, tune `crit_chance` / `crit_mult`).
- Spell power computed at `SpellEffectResolver.resolve_spell` (TechniqueDefs.power). Resolver is shared by scene (BattleTargeting/BattleInput) and sim (PlayerCaster.play).

## Plan

Roll crit for damage / heal spells and techniques in the real-time power pass, same seeded rng and `crit_chance` / `crit_mult` as swings.

## Changes Made

- `PlayerCaster.modify_power(card, caster_pid, power)`: `mod_power`, then crit roll (`crit_chance` + `mod_crit`), on-crit triggers, "crit" event.
- `SpellEffectResolver.power_hook` (Callable) wraps the power line; set by `BattleRealtime` and `BalanceFight` (sim counts spell crits in `crits_dealt`).
- `BattleRealtime`: "Critical <card>!" toast + hit feel.
- Balance: one-level-up cells moved (scout L9+1 60 → 75 %); bands pass; baseline rewritten.

## Documentation Updates

- `combat-model.md` → "Skill tree modifies cards" (crit rule); `balance-sim.md` note.
