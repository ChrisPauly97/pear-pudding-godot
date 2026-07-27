# TID-416: Implement Aggro / Control Persona Decision Logic

**Goal:** GID-112
**Type:** agent
**Status:** done
**Depends On:** TID-415

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

TID-415 adds the persona/lethal-check scaffold with a `"basic"` persona that
reproduces today's exact behavior. This task adds the two new personas that
give enemies real tactical variety: `"aggro"` (races the player's hero, ignores
favorable trades) and `"control"` (values board state, only trades favorably).
Combined with the shared lethal check from TID-415, this is what actually makes
fights feel different from each other.

## Research Notes

- Persona behaviors to implement (all run *after* the shared lethal check from
  TID-415 finds no lethal available):
  - **`"basic"`** (from TID-415, unchanged here): cheapest-card-first play order,
    lowest-HP-target attack order. This is what tier-1/tutorial enemies keep —
    predictable on purpose.
  - **`"aggro"`**: play order favors highest-attack affordable card each step
    (races to more face damage sooner) rather than cheapest-first; attack order
    always prefers the hero directly over trading with a minion, *unless* a Ward
    minion blocks (Ward targeting rule is mandatory, not optional — see
    `game_logic/battle/Keywords.gd` and the existing `ward_targets` filter in
    `ai/BasicAI.gd` lines 33-38, keep that filter intact for every persona).
  - **`"control"`**: attack order only takes a minion trade when it is
    favorable — own minion's `attack >= target.health` (kills it) AND either the
    target doesn't kill back (`target.attack < own.health`) or the target is a
    high-value threat worth trading down for. If no favorable trade exists,
    attack the hero. Play order favors board development over raw stats: hold
    removal/spell-like effects (if in hand) for the biggest current threat
    rather than dumping the cheapest card. Use
    `BattlefieldRules.modify_damage(atk, state.battlefield_biome)` (already used
    elsewhere in `ai/BasicAI.gd` lines 41-51) when computing whether a trade
    kills or survives, since biome rules can change effective damage.
- `CardInstance` fields for trade evaluation: `attack`, `health`, `keywords`
  (`game_logic/battle/CardInstance.gd` lines 9-24).
- Keep the deferred-Callable shape from TID-415/the original `decide_turn` — each
  persona still returns `Array[Callable]`, just with a different ordering
  function feeding the same "one Callable per hand card / one per board slot"
  construction loop.
- `describe_turn` must mirror whichever persona is active so the Enemy Intent
  banner (before TID-418 tones it down for tier ≥ 2) never lies about the
  literal first action the persona would take.
- Do not implement a fourth "lethal_seeker" persona — TID-415's shared lethal
  check already gives every persona lethal-awareness; a separate persona for it
  would be redundant per this goal's scoping discussion.

## Plan

_Written during Plan phase._

## Changes Made

Three additions to `ai/BasicAI.gd`:

**`_pick_attack_target(mc, state, persona)`** — the single targeting decision,
shared by `decide_turn` (execution time) and `describe_turn` (banner text) so
the two can never disagree. Precedence: Ward > lethal > persona.

**`_has_lethal(state)`** — the check the goal identified as missing entirely.
Sums biome-modified attack across every `can_attack()` board minion and compares
against `opponent.hero.armor + health`. Returns `false` outright when any
opposing Ward minion is alive, since the hero is not a legal target and no
persona may bypass that. Re-evaluated per attacker inside each deferred
Callable, so an earlier attack that clears a Ward opens the lethal line
mid-turn.

**`_pick_favorable_trade(mc, state, targets)`** — control's trade filter: the
attack must kill the target, and the attacker must either survive the
counterattack or be trading down into a strictly bigger attacker.

**`_ordered_hand(ai, persona)`** — aggro sorts by attack descending, control
puts minions before spells. Ordering alone produces "hold a card": every play
Callable re-checks `can_play` at execution time, so a card ordered last is
simply unaffordable once earlier plays spend the mana.

The `GameBus.card_played` / `card_attacked` emissions added by GID-124 / TID-468
were preserved through the refactor and still fire exactly once per action.
