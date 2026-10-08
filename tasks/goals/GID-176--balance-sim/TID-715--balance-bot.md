# TID-715: Simulated player (fixed policy)

**Goal:** GID-176
**Type:** agent
**Status:** pending
**Depends On:** TID-713, TID-714

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The simulator needs a predictable stand-in for the player that drives PlayerCaster each tick.

## Research Notes

- From TID-713: drive the player with `PlayerCaster` (`game_logic/battle/PlayerCaster.gd`). Per tick: `caster.tick(DT)` then `rt.advance(DT)`; act with `caster.play(card, resolver, target)`, where target is `{}`, `{"type":"minion","card":c}` or `{"type":"hero"}`; check legality with `caster.play_blocker(card)`; `caster.notify` gives combo / proc / interrupt / fizzled / resolved{dealt} / technique events for stats. A resolver is `SpellEffectResolver.new()` + `setup(state)`.
- New `game_logic/battle/BalanceBot.gd` (pure): `decide(state, rt, caster) -> {card, target}` or nothing, called each tick when `caster` can act.
- Policy, in order:
  1. Kick if an enemy is casting and Kick is in hand.
  2. Daze on a heavy-blow telegraph (`RealtimeCombat.is_heavy`).
  3. Mend / heal cards below 40 % HP.
  4. Summon an Ally if a slot is free and affordable.
  5. Highest-value affordable damage card: target enemy minions with Ward first, else the lowest-HP minion, else the hero.
  6. Strike.
- Value = spell_power (`TechniqueDefs.power` in real time) per mana unit. Keep it simple and documented, not clever.
- Policy knobs (aggression, heal threshold) as a dict so sweeps can compare playstyles.
- Test: the bot never attempts an illegal play (`PlayerCaster.try_play` reason always ""), and it Kicks a scripted enemy cast.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
