# TID-253: Deck Builder QoL — Filters & Auto-Fill

**Goal:** GID-069
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The collection now spans 46+ card templates with rarities, per-instance rolled stats, dawn/dusk branches, and keywords — but the deck builder only offers a fixed sort (name, then rarity). Finding the right card means scrolling everything; building a fresh deck means ~15+ individual taps. Add collection filters (card type, mana cost, rarity) and an **Auto-Fill** button that completes the deck to a legal size.

## Research Notes

- **Scene:** `scenes/ui/InventoryScene.gd` (705 lines) — collection panel left, deck panel right; existing sort at line 268-269 (`template_id` alphabetical, then rarity tier descending). Crafting recipe list sort at 647-648.
- **Data model:** `SaveManager.owned_cards` holds card *instances* (rarity + rolled stats per instance since GID-028; `add_card_instance(...)` in SaveManager). Deck = `SaveManager.player_deck`. Resolve display data via `CardRegistry.get_template(id)`.
- **Filter dimensions:**
  - *Type:* minion vs spell, and/or branch (neutral / dawn / dusk) — check `CardData` fields (`data/cards/*.tres`, `data/CardData.gd`) for the exact discriminators (`spell_effect != ""` → spell; branch field added in GID-018).
  - *Mana cost:* bucket buttons (0-2 / 3-5 / 6+) rather than a numeric input — better on touch.
  - *Rarity:* the tier list used by `CardDropUtil` / InventoryScene sort.
- **Filter UI:** a horizontal row of toggle buttons above the collection list; filters combine (AND across dimensions, OR within). All buttons viewport-relative (CLAUDE.md fractions); re-apply on `NOTIFICATION_RESIZED`. Avoid LineEdit search — virtual keyboard on Android is heavy; toggles cover the need.
- **Auto-Fill heuristic:** fill the deck from owned, not-already-in-deck instances up to a target size (suggest `IsoConst.DECK_MAX`? No — a tight deck draws better; suggest filling to max(current, 15) or to DECK_MIN if below). Recommended simple heuristic: prioritize higher rarity tier, then a balanced mana curve (greedy: pick the card whose cost bucket is currently most under-represented), respecting any per-card copy limits if they exist (check deck validation from GID-003 — `IsoConst.DECK_MIN`=5 / `DECK_MAX`=30 and any uniqueness rules; `is_unique` handling is flaky per BID-008, don't rely on it).
- **Validation:** reuse the GID-003 validation/feedback so Auto-Fill can never produce an illegal deck; disable Auto-Fill when the collection can't reach DECK_MIN.
- **Interaction with GID-058 (loadouts, pending):** loadouts will multiply deck-building frequency; keep filter/auto-fill logic in functions that operate on "a deck array" rather than hard-coding `SaveManager.player_deck` access everywhere, so loadouts can reuse them.
- **Persistence:** filters are session-only UI state (no SaveManager field needed).
- **Tests:** auto-fill heuristic is pure logic — extract to `game_logic/` (e.g. `DeckAutoFill.gd`) and unit-test headless (legal size, no duplicates beyond owned counts, deterministic given a seeded RNG or sorted input).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
