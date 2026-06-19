# TID-210: Loadout Model — SaveManager + Migration + Pruning

**Goal:** GID-058
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The persistence and lifecycle layer: multiple named loadouts stored in SaveManager, one active at a time, with seamless migration from the existing single-deck representation and automatic pruning when cards are sold/scrapped/combined.

## Research Notes

- **Current deck representation (post-GID-028):**
  - `autoloads/SaveManager.gd` line 18: `var player_deck: Array[String] = []` — each entry is a **card instance UID** (String, e.g. `"ghost_1717832500100_1"`), **not** a template ID.
  - Line 14: `var owned_cards: Array[Dictionary] = []` — each dict has `"uid"`, `"template_id"`, `"rarity"`, `"attack"`, `"health"`, `"cost"` fields.
  - At battle time (BattleScene.gd line 118–119): `SceneManager.save_manager.get_deck_template_ids()` translates all UIDs in `player_deck` to their template IDs via `get_instance_by_uid()`, so the battle engine gets template IDs only.

- **New loadout shape:**
  - Add to SaveManager: `var loadouts: Array[Dictionary] = []` where each dict is `{ "name": String, "cards": Array[String] }` (cards are UIDs, same as current `player_deck`).
  - Add to SaveManager: `var active_loadout: int = 0` (index into `loadouts` array, 0-indexed).
  - Keep `player_deck: Array[String]` as a **compatibility shim** (see "Shim" section below).
  - Cap at 5 loadouts: `const MAX_LOADOUTS: int = 5` (new const in SaveManager or IsoConst).

- **Migration v14 → v15:**
  - Pattern (cite: SaveManager.gd line 314–318, the v13→v14 migration): add `_migrate_v14_to_v15()` in the migration chain.
  - Wrap existing `player_deck` into a loadout named "Deck 1": 
    ```gdscript
    var existing_deck: Array[String] = data.get("player_deck", [])
    data["loadouts"] = [{ "name": "Deck 1", "cards": existing_deck }]
    data["active_loadout"] = 0
    data["version"] = 15
    ```
  - Do **not** remove `player_deck` from the save file; leave it as the current active deck (see "Shim" section).

- **Compatibility shim — `player_deck` property/getter:**
  - After migration, `player_deck` must **always** match `loadouts[active_loadout].cards` so all call sites keep working without change.
  - Implement as a property (not a direct variable) that returns `loadouts[active_loadout].cards` if `active_loadout` is valid, else `[]`.
  - On `save()`, serialize `player_deck` property value into the JSON (via a `_get_active_deck()` helper function called in `save()`, line 417).
  - All existing code that reads/writes `player_deck` (e.g. BattleScene line 118, InventoryScene line 34, line 500) **continues to work unchanged** because the property intercepts those accesses.

- **Call sites that reference `player_deck` (verified via grep in SaveManager.gd):**
  1. BattleScene.gd line 118: `if SceneManager.save_manager.player_deck.size() > 0` — reads size before building the battle deck.
  2. BattleScene.gd line 119: `player_deck = SceneManager.save_manager.get_deck_template_ids()` — resolves UIDs to template IDs.
  3. SceneManager.gd (deck validation, per TID-008 pattern): checks `player_deck.size() < IsoConst.DECK_MIN` before engagement.
  4. InventoryScene.gd line 34: `_working_deck.assign(SceneManager.save_manager.player_deck)` — copies into local working copy.
  5. InventoryScene.gd line 500: `player_deck.assign(new_deck)` — SaveManager method that writes the deck.
  6. SaveManager.gd line 540: `player_deck.remove_at()` inside `remove_card_instance()` when pruning on sell/scrap/combine.

- **Pruning on sell/scrap/combine — extend existing logic:**
  - Current code (SaveManager.gd line 532–541): `remove_card_instance(uid)` removes uid from both `owned_cards` and `player_deck`.
  - **New logic:** loop all loadouts and remove the uid from each `loadouts[i].cards`:
    ```gdscript
    for i in range(loadouts.size()):
        if loadouts[i].cards.has(uid):
            loadouts[i].cards.erase(uid)
    ```
  - Current call chain for pruning (cite lines):
    - `sell_card_instance()` (line 544–551): calls `remove_card_instance(uid)`.
    - `scrap_card_instance()` (line 553–565): calls `remove_card_instance(uid)`.
    - `combine_cards()` (line 576–599): loops `to_remove` UIDs and calls `remove_card_instance(uid)` for each (via the line `remove_card_instance(uid)` at line 591).
  - No change needed to `sell_card_instance()` or `scrap_card_instance()`; they already call `remove_card_instance()` which will handle the new pruning.

- **Validation — invalid loadouts:**
  - After pruning, a loadout is **invalid** if `cards.size() < IsoConst.DECK_MIN` (currently 8).
  - Add helper: `func is_loadout_valid(index: int) -> bool` returns `loadouts[index].cards.size() >= IsoConst.DECK_MIN and loadouts[index].cards.size() <= IsoConst.DECK_MAX`.
  - If `active_loadout` index is invalid after pruning, the next battle engagement is blocked with the same UX as GID-003 (SceneManager.gd TID-008 pattern: `GameBus.hud_message_requested.emit("Active loadout is invalid...")` and return early).
  - InventoryScene UI must show a **red badge** or **red outline** on invalid loadouts (via tab button modulation, similar to deck count label color at line 291–294).

- **Headless tests:**
  - Migration: load a v14 save with `player_deck: ["a", "b", "c"]`, verify it becomes `loadouts: [{"name": "Deck 1", "cards": ["a", "b", "c"]}]` and `active_loadout: 0`.
  - Prune-all-loadouts: create 3 loadouts, sell a card uid that appears in all 3, verify it's removed from all 3.
  - Accessor: `player_deck` property returns the active loadout's cards after switching active index.
  - Invalid-deck battle block: set `active_loadout` to point to a loadout with 4 cards (< 8), try engagement, verify battle does not start.
  - Last-loadout delete guard: delete all but one loadout, try to delete the last one via the new UI action, verify it's kept.

## Plan

1. Add `const MAX_LOADOUTS: int = 5`, `var loadouts: Array[Dictionary] = []`, `var active_loadout: int = 0` to SaveManager.
2. Add migration `_migrate_v33_to_v34()`: wrap existing `player_deck` into `loadouts = [{"name": "Deck 1", "cards": existing_deck}]`, `active_loadout = 0`; bump `CURRENT_SAVE_VERSION` to 34.
3. In `load_save()`: load `loadouts` and `active_loadout` from JSON; sync `player_deck` from `loadouts[active_loadout].cards` after loading.
4. In `save()`: before serialising, write `player_deck` back to `loadouts[active_loadout]["cards"]`; include `loadouts` and `active_loadout` in the data dict.
5. Update `new_game()` to initialise `loadouts = [{"name": "Deck 1", "cards": []}]`, `active_loadout = 0`, and sync after building the starting deck.
6. Update `set_active_deck()` to mirror changes into `loadouts[active_loadout]["cards"]`.
7. Update `remove_card_instance()` to prune the UID from every loadout's cards array (not just `player_deck`).
8. Add helpers: `is_loadout_valid(index)`, `get_loadout_names()`, `add_loadout(name)`, `rename_loadout(index, name)`, `duplicate_loadout(index)`, `delete_loadout(index)`, `set_active_loadout(index)`.
9. Write `tests/unit/test_loadout_model.gd` with tests covering migration, prune-all-loadouts, accessor sync, `is_loadout_valid`, and last-loadout delete guard; register in `tests/runner.gd`.

## Changes Made

- **`autoloads/SaveManager.gd`**: Added `MAX_LOADOUTS: int = 5`, `var loadouts: Array[Dictionary] = []`, `var active_loadout: int = 0` fields. Bumped `CURRENT_SAVE_VERSION` to 34. Added `_migrate_v33_to_v34()` (wraps existing `player_deck` into `loadouts = [{"name": "Deck 1", "cards": existing_deck}]`). Updated `_apply_migrations()` chain. Updated `new_game()` to initialise `loadouts` from the starting deck. Updated `load_save()` to deserialise `loadouts` and `active_loadout`, and sync `player_deck` from the active loadout. Updated `save()` to sync `loadouts[active_loadout].cards` from `player_deck` before serialising and include `loadouts`/`active_loadout` in the data dict. Updated `set_active_deck()` to mirror changes into `loadouts[active_loadout].cards`. Updated `remove_card_instance()` to prune the removed UID from every loadout's cards array. Added helpers: `is_loadout_valid()`, `get_loadout_names()`, `set_active_loadout()`, `add_loadout()`, `rename_loadout()`, `duplicate_loadout()`, `delete_loadout()`.
- **`tests/unit/test_loadout_model.gd`** (new): 30 tests covering migration v33→v34, prune-all-loadouts, set_active_loadout sync, is_loadout_valid boundaries, add/rename/duplicate/delete guards. Uses `_set_loadouts()` helper to avoid typed-array assignment errors.
- **`tests/unit/test_loadout_model.gd.uid`** (new): UID sidecar.
- **`tests/runner.gd`**: Registered `test_loadout_model` suite.

## Documentation Updates

- **`docs/agent/inventory-and-deck.md`**: Added "Deck Loadouts (GID-058)" section documenting the data model, save migration, pruning behaviour, validation, and full CRUD API.
