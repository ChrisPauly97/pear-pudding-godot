# TID-238: Cantrip Framework — Deck-Derived Abilities, HUD Button + Key Binding

**Goal:** GID-065
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

This is the foundation task for the cantrip system. It defines the decision logic (which cantrips are available given the current deck), the input mechanism (HUD button + keyboard key), cooldown management, and persistence. All subsequent cantrip tasks (Ghost Phase, Skeleton Dig) depend on this framework to activate and report their use.

The framework must map card families to cantrip thresholds (e.g., "if player deck contains ≥4 Ghost cards, Ghost Phase is available"). It must track cooldown timestamps and provide simple checks like `is_cantrip_available(cantrip_id: String)`. Mobile parity is mandatory — both a HUD button (visible, touchable) and a key binding must exist.

## Research Notes

**Deck Storage & Card Families:**
- Player's active deck is stored in `SaveManager.player_deck: Array[String]` — these are **instance UIDs**, not template ids.
- Card instances live in `SaveManager.owned_cards: Array[Dictionary]` with shape `{ "uid": String, "template_id": String, "rarity": String, "attack": int, "health": int, "cost": int }` (see comment at SaveManager.gd:14).
- `CardData` (data/CardData.gd) has NO `family` field — its fields are `id`, `card_name`, `cost`, `attack`, `health`, `card_class`, `magic_type`, `magic_branch`, `keywords`, etc. Define cantrip families inside CantripManager as constant sets of template ids (e.g. `GHOST_FAMILY: Array[String] = ["ghost", ...]` — check data/cards/*.tres for the actual ghost/skeleton-themed ids).
- To check "how many Ghost-family cards are in the active deck": iterate `SaveManager.player_deck` UIDs, resolve each to its instance in `owned_cards`, read `template_id`, count matches against the family set.

**Cantrip Availability & Thresholds:**
- A cantrip becomes available when the player has ≥N copies of a specific family card in their deck.
- Suggested thresholds: Ghost Phase ≥4 Ghost cards, Skeleton Dig ≥4 Skeleton cards. These are gameplay tuning parameters; store them in CantripManager as constants.
- Availability must be computed fresh each time the deck changes (card added/removed from the active deck in DeckBuilder) and when the player enters the world.

**CantripManager Design (Suggested):**
- New file: `game_logic/world/CantripManager.gd` (static utility, pure logic, headless-testable).
- Static methods:
  - `available_cantrips(deck: Array[String]) -> Array[String]` — returns list of cantrip IDs (e.g., ["ghost_phase", "skeleton_dig"]) based on deck contents.
  - `is_available(cantrip_id: String, deck: Array[String]) -> bool` — single cantrip check.
  - `get_threshold(cantrip_id: String) -> int` — threshold count for a cantrip.
- Private method to count cards by family in a deck.
- No mutable state; tests can call it headless.

**Cooldowns & Persistence:**
- Each cantrip has a cooldown (e.g., 30 seconds). Track cooldown *expiration* timestamps in SaveManager.
- New SaveManager fields (with migration defaults of 0 or empty dict):
  - `cantrip_cooldowns: Dictionary` — keyed by cantrip_id, value is expiration timestamp (float, seconds since epoch or relative game time).
- On save flush, cooldown dict is persisted. On load, apply migration so old saves get default cooldowns.
- Helper method in CantripManager: `is_on_cooldown(cantrip_id: String, current_time: float) -> bool` — pure check.

**HUD Button & Input Integration:**
- WorldScene's existing `_ready()` or a new HUD manager creates a cantrip button:
  - Position it in the HUD (e.g., bottom-left corner, sized as % of viewport height like other buttons per CLAUDE.md).
  - It's a `Button` with `flat = true`, showing a small icon or label (e.g., "G" for Ghost Phase).
  - `pressed` signal calls a WorldScene method to activate the cantrip.
- Keyboard binding: WorldScene's `_input()` checks for key events (G for Ghost Phase, D for Skeleton Dig, etc., avoid conflicts).
- Both paths (button + key) route to the same activation method to avoid duplication.
- Mobile parity (per CLAUDE.md): the button itself IS the touch target on mobile. VirtualJoystick overlay does not consume cantrip input.

**Cross-System Signal:**
- Add to GameBus: `cantrip_used(cantrip_id: String)` — emitted when a cantrip is activated successfully. Battle, HUD, and other systems can listen.
- The signal carries the cantrip_id so listeners know what just happened (useful for cooldown feedback, achievements, etc.).

**Example Flow:**
1. Player presses G (or taps cantrip button).
2. WorldScene resolves `SaveManager.player_deck` UIDs to template ids and calls `CantripManager.is_available("ghost_phase", template_ids)`.
3. If true and not on cooldown, emit `GameBus.cantrip_used("ghost_phase")`, set cooldown expiration in SaveManager.
4. Listener (TID-239 Ghost Phase task) performs the effect.
5. If unavailable or on cooldown, emit `GameBus.hud_message_requested("Ghost Phase requires 4+ Ghost cards")` or similar.

**Testing Approach:**
- Unit test `CantripManager.available_cantrips()` with mock decks (0 cards, 1 card, 4 Ghost cards, etc.).
- Unit test cooldown logic with fake timestamps.
- Scene test in WorldScene: mock a deck, press key, verify signal fires and cooldown is set.
- Headless test: no Godot scene needed; CantripManager functions work in isolation.

## Plan

Created CantripManager.gd (pure static utility), added GameBus signal, SaveManager fields + migrations, WorldScene HUD buttons + key bindings (G/D).

## Changes Made

- Created `game_logic/world/CantripManager.gd` + `.uid` — static methods: `is_available`, `available_cantrips`, `get_threshold`, `get_cooldown`, `is_on_cooldown`, `cooldown_remaining`
- `autoloads/GameBus.gd` — added `signal cantrip_used(cantrip_id: String)`
- `autoloads/SaveManager.gd` — added `cantrip_cooldowns: Dictionary` and `dug_mounds: Array[String]`; migrations v35→v36 and v36→v37; CURRENT_SAVE_VERSION=37
- `scenes/world/WorldScene.gd` — added CantripManager preload, `[G] Phase` / `[D] Dig` HUD buttons, G/D key handling in `_unhandled_input()`, ghost phase and skeleton dig activation methods
- `tests/unit/test_cantrip_manager.gd` — 20 unit tests covering availability, thresholds, cooldowns

## Documentation Updates

- Created `docs/agent/card-cantrips.md`
- Updated `docs/agent/docsplan.md` to add the new doc
