# TID-173: House Purchase Flow + Interior Map + Door Gating

**Goal:** GID-046  
**Type:** agent  
**Status:** pending  
**Depends On:** —

## Lock

**Session:** none  
**Acquired:** —  
**Expires:** —

## Context

The entry point to the trophy hall: a house door placed in madrian that costs coins to purchase, leads to a new interior map on entry, and persists the purchase in the save state with automatic migration.

## Research Notes

- **Door placement in madrian:** Check **`assets/maps/madrian.tres`** structure — existing doors at tile coords `(50,99)` → maykalene, `(60,50)` → main, `(80,50)` → farsyth_mansion, `(85,50)` → blancogov, `(60,56)` → blancogov_temple, `(65,56)` → infinite. Place house door at a sensible location on the map perimeter, e.g. `(40, 50)` or `(70, 50)` to avoid existing buildings. Verify the map layout visually with the MapEditorScene if needed.
- **Purchase prompt flow:** Door interaction must check `SaveManager.home_owned` (bool, added as new field). If false, show a confirm dialog with price (500 coins suggested). Cite **`ShopScene.gd`** lines 180–186 for button + price label pattern. Adapt it: instead of a full shop overlay, use a single confirm dialog. Reuse **WorldScene dialogue system** — check `_on_dialogue_label_show()` in **`scenes/world/WorldScene.gd`** line 1236+. If no general confirm dialog exists, build one inline in a helper script (simple Control with two buttons: "Buy (500 coins)" and "Cancel").
- **Coins check + debit:** Use **`SaveManager.add_coins(-amount)`** to spend coins (negative value). Check insufficient balance before showing the button. Cite the coin API at **`autoloads/SaveManager.gd`** line 476 `add_coins(amount: int)`.
- **SaveManager.home_owned field:** Add `var home_owned: bool = false` to **`autoloads/SaveManager.gd`** alongside the other boolean flags. Add migration in `_migrate_v14_to_v15()` backfilling `home_owned = false` for old saves. Increment `CURRENT_SAVE_VERSION` from 14 to 15. Update the migration function table in `_apply_migrations()` to call the new migration.
- **Interior map:** Create **`assets/maps/player_home.tres`** using the MapData resource schema (cite **`game_logic/world/resources/MapData.gd`** for fields). Small room dimensions: ~12×10 tiles, spawn at `(6, 5)`. Add three **`MapDoor`** resources: exit door `target_map = "__exit__"` (which pops the map stack). Cite **`game_logic/world/resources/MapDoor.gd`** lines 9–10: `target_map` empty string = pop map stack. Exit door can be at `(6, 1)` or similar. Placeholder for two interactable entities: bed and three trophy pedestals (to be spawned by TID-174/TID-175).
- **MapRegistry registration:** Add to **`autoloads/MapRegistry.gd`**: `const _PLAYER_HOME := preload("res://assets/maps/player_home.tres")` at line 22+, then add `"player_home": _PLAYER_HOME` to the `_BUNDLED` dict at line 26+. Cite CLAUDE.md Map Storage section.
- **UID sidecar:** Generate a 12-char random UID for `player_home.tres.uid` file. Use: `python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"`.
- **Door lock logic:** In **WorldScene**, when a player interacts with the house door (entity_id "house_door"), check `SaveManager.home_owned`:
  - If true: allow passage via normal door flow (call SceneManager.enter_map("player_home", "bed")).
  - If false: show a confirmation prompt (price 500, or tune based on GID-007 economy). On confirm: call `SaveManager.add_coins(-500)`, set `SaveManager.home_owned = true`, mark dirty, then proceed to enter the map.
- **WorldScene door interaction routing:** Cite **`scenes/world/WorldScene.gd`** method that handles door interaction (search for DOOR entity type and the entity_id check). Add a branch for `entity_id == "house_door"` that calls a helper `_handle_house_door_interaction()` — returns early if not owned and cancel is pressed.
- **Tests:** Headless test for:
  - Insufficient coins: show prompt, cancel button does nothing, coins remain unchanged.
  - Sufficient coins: show prompt, confirm reduces coins by 500, sets `home_owned = true`, persists across save/load.
  - Once owned: door entry proceeds without prompt.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
