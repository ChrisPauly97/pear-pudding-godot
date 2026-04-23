# TID-092: Random Event Room

**Goal:** GID-027
**Type:** agent
**Status:** done
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

- Event room NPC (npc_type = "event_room") spawned by DungeonGen; after_dialogue stores room_key.
- `WorldScene._show_event_panel()` loads `data/dungeon_events.json`, selects event deterministically via room_key hash, and shows Panel with event text and choice buttons.
- `_apply_event_outcome()` handles all outcome_type values: gain_coins, lose_hp, gain_card, lose_card, lose_hp_gain_card, gain_coins_lose_hp, lose_coins_gain_card, nothing.
- Room marked used after any choice is pressed.
- 5 starter events matching task spec written to `data/dungeon_events.json`.

## Changes Made

- `data/dungeon_events.json`: Created with 5 events (wounded_stranger, ancient_altar, coin_pile, mysterious_merchant, hidden_cache).
- `scenes/world/WorldScene.gd`: Added `_show_event_panel()` and `_apply_event_outcome()`.
- `game_logic/world/DungeonGen.gd`: "event" match arm spawns event_room NPC.

## Documentation Updates

See TID-089 docs update.
