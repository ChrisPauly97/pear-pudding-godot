# TID-016: Merchant NPC and Shop Overlay

**Goal:** GID-007
**Type:** agent
**Status:** done
**Depends On:** TID-015

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Players can now earn coins but have nowhere to spend them. This task adds a Merchant NPC entity type (placeable in named maps via the `MERCHANT` directive and spawnable in procedural towns) and a ShopScene overlay where cards can be purchased.

## Research Notes

**Relevant files:**
- `scenes/world/WorldScene.gd` — spawns NPCs and handles `E` interaction; model after `TownspersonNPC` for the entity type
- `scenes/world/TownspersonNPC.gd` — existing NPC with dialogue; MerchantNPC will show dialogue then open shop
- `autoloads/SceneManager.gd` — `push_overlay(scene)` pattern used by InventoryScene; ShopScene uses the same pattern
- `autoloads/SaveManager.gd` — `owned_cards`, `coins`, `add_coins()`, `mark_dirty()`
- `autoloads/CardRegistry.gd` — provides all available cards for shop listing
- `assets/maps/*.txt` — `MERCHANT x z` directive needs parsing in WorldMap
- `docs/agent/ui-and-scene-management.md` — overlay and viewport-relative sizing patterns

**Design:**
- **MerchantNPC entity:** new `.gd` script similar to TownspersonNPC; on `E` press opens ShopScene overlay
- **ShopScene:** vertical list of all cards (via CardRegistry), each row shows card name + cost in coins + Buy button; buy deducts coins and adds to owned_cards
- **Pricing:** base 15 coins per card (same for all cards initially; rarity differentiation is a future goal)
- **Map directive:** `MERCHANT x z` in `.txt` files; WorldMap parser emits a merchant entity; WorldScene spawns MerchantNPC at that position
- **Procedural spawning:** InfiniteWorldGen can optionally place 0–1 merchant per chunk (low probability, ~5%) in grassland/forest biomes

**UI sizing:** follow viewport-relative rules from CLAUDE.md — button height ~5% vh, font ~2% vh.

## Plan

1. Add `shop_requested` signal to `autoloads/GameBus.gd`.
2. Create `scenes/ui/ShopScene.gd` — a `Control` overlay listing all cards from `CardRegistry` with Buy buttons (15 coins each); disables button if player lacks coins; deducts coins and adds to `owned_cards` on purchase; emits `closed` signal.
3. Create `scenes/ui/ShopScene.tscn` referencing the script.
4. Add `SHOP` state to `SceneManager`; connect `GameBus.shop_requested` → open `ShopScene` overlay on the current world scene; close on `closed` signal.
5. Create `scenes/world/entities/MerchantNPC.gd` — variant of `TownspersonNPC` with golden robe colour and `get_dialogue()` returning a greeting.
6. Create `scenes/world/entities/MerchantNPC.tscn`.
7. Update `WorldMap.load_from_string()` to parse `MERCHANT x z` → append to `npcs` with `npc_type: "merchant"`; update `save_to_file()` to write `MERCHANT x z` for these rows.
8. Update `ChunkRenderer._spawn_entities()` to check `npc_data.get("npc_type","") == "merchant"` and instantiate `MerchantNPC` scene instead of `TownspersonNPC`.
9. Update `InfiniteWorldGen._gen_entities()` to add 0–1 merchant per chunk (~5% chance) in grassland/forest biomes.
10. Update `WorldScene._handle_interact()`: if nearest NPC has `npc_type == "merchant"`, emit `GameBus.shop_requested` instead of showing dialogue.

## Changes Made

- `autoloads/GameBus.gd` — added `shop_requested` signal
- `autoloads/SceneManager.gd` — added `SHOP` state, `_shop_scene_packed` preload, `_shop_overlay` variable, `_on_shop_requested()` / `_on_shop_closed()` handlers, cleanup in `_exit_world_cleanup()`
- `scenes/ui/ShopScene.gd` (new) — overlay listing all cards via `CardRegistry` with 15-coin buy buttons; disables button when insufficient coins; deducts coins and adds card to `owned_cards` on purchase
- `scenes/ui/ShopScene.tscn` (new) — scene file for the shop overlay
- `scenes/world/entities/MerchantNPC.gd` (new) — NPC entity with golden-robe appearance; `get_dialogue()` returns merchant greeting
- `scenes/world/entities/MerchantNPC.tscn` (new) — scene file for the merchant NPC
- `game_logic/world/WorldMap.gd` — added `MERCHANT x z` directive parsing (appends to `npcs` with `npc_type: "merchant"`); updated `save_to_file()` to write `MERCHANT` lines for merchant NPCs
- `scenes/world/ChunkRenderer.gd` — added `_MerchantScene` preload; `_spawn_entities()` now checks `npc_type == "merchant"` and instantiates `MerchantNPC` instead of `TownspersonNPC`
- `game_logic/world/InfiniteWorldGen.gd` — added ~5% merchant spawn chance per chunk in grasslands/forest biomes
- `scenes/world/WorldScene.gd` — `_handle_interact()` emits `GameBus.shop_requested` instead of showing dialogue when nearest NPC has `npc_type == "merchant"`

## Documentation Updates

- `docs/agent/enemies-and-npcs.md` — added Merchant NPC section
- `docs/agent/ui-and-scene-management.md` — added ShopScene overlay documentation
