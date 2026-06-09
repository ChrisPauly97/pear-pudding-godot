# TID-180: Stable NPC Purchase Flow + HUD Mount Button

**Goal:** GID-048
**Type:** agent
**Status:** pending
**Depends On:** TID-179

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The sales entry point: a stable NPC merchant in madrian that enforces a level 10 gate, handles the coin purchase flow, and a HUD button for desktop/mobile to summon/dismiss the mount once owned. Mobile parity per CLAUDE.md ensures both keyboard and touch players can access the feature.

## Research Notes

- **Stable NPC placement in madrian:**
  - Check **`assets/maps/madrian.tres`** structure (MapData resource). Existing doors at tile coords `(50,99)` → maykalene, `(60,50)` → main, etc. (cite TID-173 for door placement examples). Place stable NPC at a sensible tile, e.g. `(75, 45)` or similar, away from existing buildings.
  - **MapNpc fields:** (cite **`game_logic/world/resources/MapNpc.gd`** lines 1–17):
    - `entity_id: String` — e.g. "stable_master"
    - `tile_x, tile_z: int` — position
    - `dialogue: String` — "I have horses for sale. Interested?"
    - `npc_type: String` — set to `"merchant"` (cite WorldScene line 1210 `if str(npc.get("npc_type", "")) == "merchant"`)
    - `flag_key, after_dialogue` — optional story progression
  - No `.tres` file needed if madrian is already a MapData resource; just add the NPC entity to its `npcs: Array[MapNpc]` field.

- **Purchase dialog flow (level 10 gate):**
  - When player interacts with the stable NPC (`entity_id == "stable_master"`), WorldScene routes to a merchant shop (cite **`scenes/world/WorldScene.gd`** line 1210 merchant handler).
  - **Level check:** Before showing the buy button, check **`SaveManager.level`** (line 86 of SaveManager.gd, default 1). If `level < 10`, disable the button and show text "Requires level 10" instead of the price label. Cite the TID-173 pattern: **`ShopScene.gd`** lines 180–186 show button + price label pattern with `disabled = coins < price`. Extend this: `disabled = (coins < price) or (SaveManager.level < 10)`.
  - If `level < 10`, show a secondary label "Requires level 10" overlaying or replacing the price label.
  - If sufficient coins (750) and level >= 10: button is enabled. On purchase, call `SaveManager.add_coins(-750)` (cite line 476 add_coins API), set `SaveManager.owned_mounts.append("stable_horse")`, set `SaveManager.active_mount = "stable_horse"`, `SaveManager.is_mounted = true`, mark_dirty(). Then close the shop.

- **Reuse ShopScene pattern:**
  - The stable NPC is a `"merchant"` type. When interacted with, WorldScene checks npc_type == "merchant" and opens ShopScene (cite line 1210–1213).
  - Adapt ShopScene or create a stable-specific shop overlay: inject a "Mounts" section into ShopScene._refresh() that iterates `MountRegistry` mounts not yet in `SaveManager.owned_mounts`.
  - Alternatively, create a lightweight **`StableScene.gd`** (minimal overlay, just for mounts) and route stable_master interactions to it instead of ShopScene. Simpler for v1: use a helper method in WorldScene or ShopScene itself.
  - Mount row format: display_name, speed_multiplier hint, price. Check: `disabled = (coins < price) or (level < 10)`. If disabled and level < 10, show "Requires level 10" in red text instead of price.

- **HUD summon/dismiss button:**
  - **Desktop key binding:** Suggest **T** for "mount" action (M is taken by map_view per project.godot line 79–82). Add to **`project.godot`** `[input]` section: `mount={"deadzone": 0.5, "events": [InputEventKey(physical_keycode: 84, ...)]}` (84 = T).
  - **HUD button:** In **`scenes/world/WorldScene.gd`** `_build_hud()` (line 254+), add a new mount button (flat style, like Inventory/Journal/Character/Skills buttons). Position it below the Skills button using the same spacing pattern (cite lines 293–299): `minimap_bottom + (btn_h + vh * 0.005) * 4`.
    - Text: "Mount" (if owned and dismounted) or "Dismount" (if mounted).
    - `custom_minimum_size = Vector2(btn_w * 1.3, btn_h)` (cite line 271 width pattern for 1.3× buttons).
    - `flat = true` per CLAUDE.md mobile parity pattern.
    - Only visible if `SaveManager.owned_mounts.size() > 0` and `SaveManager.current_map == "main"` (not in interiors/dungeons).
    - On press: if mounted, call `SaveManager.dismiss_mount()`, else call `SaveManager.summon_mount("stable_horse")` (v1 assumes one mount).
    - Update button text/visibility every frame in `_process()` to reflect current mount state. Or listen to GameBus.mount_state_changed signal (from TID-179) and update on that event.

- **Mobile parity (touch equivalent):**
  - The button itself (flat, on-screen) serves as the touch target. No separate touch-specific logic needed — the button's `pressed` signal works on both desktop and mobile.
  - Verify on Android: button is tappable, press works, summon/dismiss completes.

- **Input detection:**
  - In **`scenes/world/WorldScene.gd`** `_process()` (or a dedicated `_handle_mount_input()`), check `Input.is_action_just_pressed("mount")` for desktop T key. Call the same mount/dismount functions.
  - Button and key should both route to the same summon/dismiss logic (DRY principle).

- **Tests:** Headless test file `tests/test_mount_purchase_hud.gd`:
  - Test level gate: player at level 9, interaction shows "Requires level 10", button disabled, coins unchanged.
  - Test level gate pass: player at level 10, coins >= 750, button enabled. Purchase works, coins decreased by 750, owned_mounts contains "stable_horse".
  - Test insufficient coins: level 10, coins < 750, button disabled, shows "Insufficient coins" (or similar).
  - Test HUD visibility: owned_mounts empty → button hidden; owned_mounts has "stable_horse" + in "main" map → button visible and text toggles based on is_mounted.
  - Test key input: simulate Input.is_action_pressed("mount"), verify summon/dismiss is called.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
