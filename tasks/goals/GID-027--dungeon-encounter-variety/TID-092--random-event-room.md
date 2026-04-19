# TID-092: Random Event Room

**Goal:** GID-027
**Type:** agent
**Status:** pending
**Depends On:** TID-089

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Random event rooms present a text narrative prompt with 2–3 choices, each with a defined outcome. They add narrative texture to dungeons and create memorable moments — the "what happens if I pick this?" curiosity that keeps players exploring.

## Research Notes

- New data file: `data/dungeon_events.json` (or .tres array) — list of event definitions; each event has:
  - `id`: String
  - `text`: narrative prompt (2–3 sentences of flavour)
  - `choices`: Array of `{label: String, outcome_type: String, outcome_value: Variant}`
- `outcome_type` values: `"gain_coins"`, `"lose_hp"`, `"gain_card"`, `"lose_card"`, `"gain_hp"`, `"nothing"` (a bait option)
- Event is chosen randomly from the pool using the room seed for determinism
- UI: a Panel overlay with the event text at the top and buttons for each choice; after choosing, show the outcome text and a "Continue" button that closes the overlay
- Mark room visited after a choice is made (same visited_rooms pattern)

**Suggested starter event pool (5–8 events):**

| Event | Prompt | Choice A | Choice B | Choice C |
|---|---|---|---|---|
| Wounded stranger | A wounded traveller blocks the path and begs for a card. | Give a card (lose_card, 1) | Refuse and walk past (nothing) | — |
| Ancient altar | An ancient altar glows faintly. An inscription reads: "Offer blood, receive wisdom." | Touch it (lose_hp 5, gain_card 1) | Leave it alone (nothing) | — |
| Coin pile | You find a scattering of coins on the floor. But something feels wrong. | Take the coins (gain_coins 15, lose_hp 3) | Leave them (nothing) | — |
| Mysterious merchant | A cloaked figure offers a card for your coins. | Buy (lose_coins 10, gain_card 1) | Decline (nothing) | — |
| Hidden cache | You notice a loose stone in the wall. Behind it: a small cache. | Take it (gain_coins 20) | Leave (nothing) | — |

- Human can add more events to `dungeon_events.json` without any code changes — data-driven

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
