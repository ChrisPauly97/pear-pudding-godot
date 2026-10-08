# TID-706: Design: technique-card rules

**Goal:** GID-175
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Decide the rules for turning the real-time skill bar into technique cards before any code changes. Defaults agreed at the review gate: max 1 copy of each technique per deck; Strike is a normal deck card; techniques work in both turn-based and real-time.

## Research Notes

- Current bar design: `docs/agent/combat-model.md` → "Skill bar — fixed abilities (TID-550)", "Learning abilities & the loadout", "Momentum (GID-139)".
- `game_logic/battle/SkillBar.gd` `ABILITIES`: strike, mend, kick, guard, ember_lance, mana_tap, sweep, daze (cost in mana points, cooldown, cast, effect, value, off_gcd, level_req, learn_cost).
- Real-time draw: `RealtimeCombat` `_draw_timer` / `tune.draw_interval` (6 s) / `hand_cap` (7); `trim_hand()` shrinks the opening hand.
- Questions to settle in the doc: what replaces the cooldown (recycle to the bottom of the draw pile), whether techniques count toward deck size, Kick/Daze when drawn late (they are reactive), turn-based equivalents (interrupt → silence/stun), cost scale (points vs units), the GCD/off_gcd flag on a card, and whether draw tuning must change to keep "always a button" (GID-139).
- Output: a new "Technique cards (GID-175)" section in combat-model.md that supersedes the skill-bar sections (mark those superseded instead of deleting them).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
