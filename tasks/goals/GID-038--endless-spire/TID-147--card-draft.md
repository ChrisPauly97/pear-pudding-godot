# TID-147: Card Draft Logic + Draft Pick UI

**Goal:** GID-038
**Type:** agent
**Status:** pending
**Depends On:** TID-146

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The draft is the heart of the Spire loop: after each floor victory, the player picks one of three cards to add to their run-local deck. Depth-weighted rarity makes climbing feel like power growth.

## Research Notes

- **Draft pool logic** (pure GDScript, `game_logic/spire/SpireDraft.gd`):
  - `generate_picks(floor: int, rng: RandomNumberGenerator) -> Array[CardData]` — 3 distinct cards from `CardRegistry`, rarity-weighted by floor: floors 1–3 mostly common, 4–6 uncommon-leaning, 7+ rare/legendary chances rise. Use the rarity field from GID-028 (`CardRegistry` / `CraftingRegistry.gd` for rarity tiers).
  - Seed the RNG from `spire_run.seed + floor` so re-opening the draft after an app kill shows the same 3 picks (no reroll scumming).
- **Draft UI:** New `scenes/ui/SpireDraftScene.tscn` + `.gd` — a modal showing 3 card panels side by side. Reuse the card panel rendering from `InventoryScene.gd` or the card visuals from GID-008/GID-036 (check how `CardData` is rendered into a panel — there may be a shared card-widget scene from the mobile-first UI redesign).
  - Mobile-first sizing per CLAUDE.md: card panels sized as fractions of viewport, tap to select, confirm button ≥5% vh.
  - On pick: `SaveManager.add_drafted_card(card_id)` (TID-146), emit `GameBus.spire_card_drafted(card_id)`, close.
- **Deck isolation in battle:** `game_logic/battle/PlayerState.gd` — find where the player deck is built from `SaveManager` (likely `build_deck`). Add an override path: when a spire run is active, build from `spire_run.draft_deck` instead. The starting draft deck on floor 1 is a small fixed starter (e.g. 8 basic cards) so battles work before any drafting.
- `autoloads/GameBus.gd` — add `spire_card_drafted(card_id: String)` signal.
- **Tests:** Headless test for `generate_picks` determinism (same seed+floor → same picks) and rarity weighting bounds.
- `docs/agent/inventory-and-deck.md` — document run-local deck isolation.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
