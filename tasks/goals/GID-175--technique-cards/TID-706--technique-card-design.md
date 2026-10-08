# TID-706: Design: technique-card rules

**Goal:** GID-175
**Type:** agent
**Status:** done
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
- **Keep hero auto-attack** (user, 2026-10-08): it is weapon-driven, passive and feeds the deck through the mana siphon. Rule: no manual swing or weapon abilities. If auto-attack decides fights, tune its damage down rather than weakening cards.
- Output: a new "Technique cards (GID-175)" section in combat-model.md that supersedes the skill-bar sections (mark those superseded instead of deleting them).

## Plan

Low complexity, so I proceeded without an approval stop. Read the skill bar, momentum, real-time draw, CardData and existing spell effects, then wrote a "Technique cards" section in combat-model.md that settles every open question in the Research Notes.

## Changes Made

- `docs/agent/combat-model.md`: new section "Technique cards (GID-175 / TID-706)" covering the rules table, the 8-technique table (real-time and turn-based values, mapped to existing `spell_effect` ids) and the migration. The skill-bar section is marked superseded.
- TID-707 Research Notes point at the design and name `TechniqueDefs.gd`.
- Decisions beyond the review-gate defaults: max 3 techniques per deck, costs of 0 or 1 unit, techniques don't spend combo or free-procs, `is_unique` (no trading), the old cast times kept via `TechniqueDefs`, enemies get no techniques.

## Documentation Updates

combat-model.md (new section, old section marked superseded).
