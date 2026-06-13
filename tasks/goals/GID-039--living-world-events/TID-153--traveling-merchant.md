# TID-153: Traveling Merchant Event with Rotating Rare Stock

**Goal:** GID-039
**Type:** agent
**Status:** done
**Depends On:** TID-151

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

A merchant who appears in the wilderness with rare cards the town shops don't carry, then leaves. Gives coins a high-end sink and rewards players who happen upon him — the world offering something instead of the player taking it.

## Research Notes

- **Spawn:** Register `traveling_merchant` with WorldEventManager (TID-151), interval ~10–20 min. Spawn `scenes/world/entities/MerchantNPC.tscn` at `find_spawn_tile(player_pos, 15, 30)`.
- `scenes/world/entities/MerchantNPC.gd` + `scenes/ui/ShopScene.gd` — exist from GID-007 (and inn merchants from GID-011). Study how a merchant's stock is defined — likely a stock array/resource on the NPC. The traveling merchant needs a stock override.
- **Rotating stock:** 3 cards rolled from `CardRegistry` filtered to rare/legendary rarities (GID-028 rarity field), seeded from the event's fire-time so the stock is stable for the event's duration. Prices: meaningfully above town-shop levels (premium for convenience) — check existing shop pricing in ShopScene/GID-028 economy docs before picking numbers.
- **Distinct look:** Tint the merchant sprite (modulate) and/or add a simple `GPUParticles3D` smoke puff so he reads as special at a distance. No new textures needed — `TextureGen` patterns if a variant sprite is wanted.
- **Despawn:** 5 minutes of overworld time after spawn, or after the player closes the shop having bought all 3 cards. Emit `end_event("traveling_merchant")` via the TID-151 cleanup callable. If the player is mid-shop when the timer expires, let them finish — despawn on shop close.
- **Discovery aid:** Unlike the boss, NO minimap marker — finding him by chance is the charm. But a brief HUD toast on spawn ("You hear distant wagon wheels...") gives a hint. Check `AchievementToast.gd` for a reusable toast pattern.
- **Mobile parity:** Shop interaction is already touch-friendly via ShopScene; just verify the interact prompt works with the tap-prompt pattern from CLAUDE.md.
- `docs/agent/enemies-and-npcs.md` — document the traveling merchant variant; `docs/agent/world-generation.md` — note the event.

## Plan

1. Add `traveling_shop_requested(stock: Array[String], price: int)` signal to `GameBus.gd`.
2. Modify `ShopScene.gd`: add `_custom_stock`, `_custom_price`, `_custom_title` vars; in `_refresh()` branch on custom stock (show only those 3 cards at `_custom_price`, skip weapons); make `_make_card_row` and `_on_buy_card` accept an explicit price.
3. Modify `SceneManager.gd`: connect to `traveling_shop_requested`; open ShopScene with custom vars set before `add_child()`.
4. Modify `MerchantNPC.gd`: add `_is_traveling: bool` from `init_from_data` data dict; apply violet materials and "Traveling Merchant" label when set; distinct dialogue.
5. Modify `WorldScene.gd`: add `"traveling_merchant"` NPC type detection in `_handle_interact()` (emits `traveling_shop_requested` with stock from npc data); add `_traveling_merchant_timer` and `_tick_traveling_merchant(delta)` for 5-min despawn.
6. Add merchant registration to `game_logic/WorldEvents.gd`: 10–20 min interval, seeded 3-card pick from premium pool, spawn as violet MerchantNPC, cleanup removes NPC from registry.

## Changes Made

- `autoloads/GameBus.gd` — added `traveling_shop_requested(stock: Array[String], price: int)` signal
- `autoloads/SceneManager.gd` — connected `traveling_shop_requested`; added `_on_traveling_shop_requested()` that opens ShopScene with `_custom_stock`, `_custom_price=30`, `_custom_title` set before `add_child()`; added `"roaming_terror": 150` XP table entry
- `scenes/ui/ShopScene.gd` — added `_custom_stock`, `_custom_price`, `_custom_title` vars; `_refresh()` branches on non-empty custom stock (shows only those cards at custom price, no weapons); `_make_card_row` and `_on_buy_card` accept explicit price param
- `scenes/world/entities/MerchantNPC.gd` — full rewrite: added `_is_traveling` var; applies violet robe material `Color(0.45, 0.15, 0.65)` per-instance when traveling; "Traveling Merchant" label in purple; `get_dialogue()` returns traveling greeting
- `scenes/world/WorldScene.gd` — added `WorldEvents` preload; added `_traveling_merchant_timer` var; calls `WorldEvents.register_all(self)` in `_ready()` when `_is_infinite`; added `_tick_traveling_merchant(delta)` for 5-min despawn; added traveling_merchant npc_type detection in `_handle_interact()` (emits `traveling_shop_requested`)
- `game_logic/WorldEvents.gd` — new file: registers both `roaming_boss` (15–25 min) and `traveling_merchant` (10–20 min) with WorldEventManager; merchant spawn picks 3 cards from 18-card premium pool seeded by time; cleanup removes from `_npc_nodes` and `_active_npc_data`

## Documentation Updates

- `docs/agent/enemies-and-npcs.md` — added "Traveling Merchant Event" subsection before MerchantNPC Scene section; describes spawn, interaction flow, despawn, premium card pool, pricing
- `docs/agent/signals-and-constants.md` — added `traveling_shop_requested` row to Signal Reference Table
- `docs/agent/world-generation.md` — added Registered events table listing `roaming_boss` and `traveling_merchant`; added `traveling_shop_requested` to GameBus signals table
