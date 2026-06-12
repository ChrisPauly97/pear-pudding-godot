# TID-147: Card Draft Logic + Draft Pick UI

**Goal:** GID-038
**Type:** agent
**Status:** done
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

1. Add `signal spire_card_drafted(card_id: String)` to `GameBus.gd`.
2. Create `game_logic/spire/SpireDraft.gd` — pure static logic:
   - `card_tier(card_id)` assigns each card a tier 0–3 based on card_class + cost.
   - `tier_weights(floor)` returns [t0,t1,t2,t3] weights for a given floor bucket.
   - `generate_picks(floor, rng) -> Array[String]` returns 3 distinct IDs, rarity-weighted.
3. Create `scenes/ui/SpireDraftScene.gd` + minimal `.tscn` — modal with 3 card panels.
   - `setup(floor: int)` called by the floor scene to configure and display picks.
   - On pick: `SceneManager.save_manager.add_drafted_card(id)`, `GameBus.spire_card_drafted.emit(id)`, emit local `picked(id)`.
4. Update `scenes/battle/BattleScene.gd`: when `SceneManager.save_manager.is_spire_active()`, use `spire_run.draft_deck` as the player deck (fall back to 8-card starter when empty).
5. Create `tests/unit/test_spire_draft.gd` — determinism (same seed+floor → same 3 picks) and tier weight bounds.
6. Register new test in `tests/runner.gd`.
7. Update `docs/agent/inventory-and-deck.md` with run-local deck isolation section.

## Changes Made

- **`autoloads/GameBus.gd`** — added `signal spire_card_drafted(card_id: String)`.
- **`game_logic/spire/SpireDraft.gd`** (new) — `card_tier_from_template(tmpl)`, `card_tier(id)`, `tier_weights(floor)`, `generate_picks(floor, rng, pool_templates)`, `_pick_one(...)`. Accepts `pool_templates: Dictionary` from caller so logic stays pure/testable without autoload access.
- **`scenes/ui/SpireDraftScene.gd`** (new) — modal draft overlay; `setup(floor)` builds pool from `CardRegistry`, shows 3 card panels, emits `picked(card_id)` on selection and calls `SaveManager.add_drafted_card` + `GameBus.spire_card_drafted`.
- **`scenes/ui/SpireDraftScene.tscn`** (new) — minimal scene file.
- **`scenes/battle/BattleScene.gd`** — added Spire deck isolation: when `is_spire_active()`, use `draft_deck` (fall back to 8-card starter when empty).
- **`tests/unit/test_spire_draft.gd`** (new) — 37 tests covering `generate_picks` (shape, uniqueness, pool membership, determinism), `card_tier_from_template` (all tier boundaries), `tier_weights` (floor buckets), and tier distribution.
- **`tests/runner.gd`** — registered `test_spire_draft` suite.

## Documentation Updates

- **`docs/agent/inventory-and-deck.md`** — added "Endless Spire: Run-Local Deck Isolation" section covering deck isolation in battle, draft pick flow, tier system, floor-weight table, and `spire_card_drafted` signal.
