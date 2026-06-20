# TID-246: Discovery System — Name Generator, Journal Tab, Toast, Reward

**Goal:** GID-067
**Type:** agent
**Status:** done
**Depends On:** TID-244

## Lock

**Session:** —
**Acquired:** —
**Expires:** —

## Context

The emotional payoff of landmarks: walking up to one for the first time names it ("The Kneeling King of the Ashen Waste"), shows a discovery toast, logs it permanently in the Journal, and grants a one-time reward. Re-visits show the known name but never re-reward. Runs off TID-244's placement data; works even before TID-245's meshes land (discovery radius around the entity position).

## Research Notes

**Name generator:**
- Deterministic from (world_seed, cx, cz) — seed an RNG with the same hash TID-244 uses so the name is a stable property of the landmark.
- Pattern: `"The <epithet> <noun> of the <place>"` with word pools per variant and per biome, e.g. epithets ["Kneeling", "Silent", "Sunken", "Broken", "Watchful"], nouns per variant (colossus → ["King", "Giant", "Sentinel"]; spire → ["Needle", "Fang"]), places per biome (Scorched → ["Ashen Waste", "Cinder Fields"], Desert → ["Endless Sands"], …).
- Pure static function, e.g. in the same module as TID-244's `landmark_for_chunk` or a small `game_logic/world/LandmarkNames.gd` (preload where used). Headless-testable: same inputs → same name.

**Discovery trigger:**
- `scenes/world/WorldScene.gd` runs `_check_interactions()` every frame for proximity prompts (IsoConst.INTERACT_RANGE). Landmarks want a LARGER discovery radius (~8–10 world units) and no button press — discovery fires automatically on first approach.
- Implementation options: check distance to the landmark entity position for loaded chunks in WorldScene, or give the landmark node (TID-245) an Area3D. Prefer the WorldScene distance check against `ChunkData.entities` so discovery works even if the mesh task ships later.

**On first discovery:**
1. Append `landmark_id` (e.g. `"landmark_<cx>_<cz>"` from TID-244) to a NEW SaveManager field `discovered_landmarks: Array[String]` (migration default `[]`, dirty-flag save like `opened_chests: Array[String]` at SaveManager.gd:34).
2. Emit a new GameBus signal `landmark_discovered(landmark_id: String, display_name: String)` — add to `autoloads/GameBus.gd` with the other signals; never direct node references.
3. Toast: reuse the `scenes/ui/AchievementToast.gd` pattern (or the toast itself with a different style) showing the generated name.
4. One-time reward: coins (`SaveManager.coins`) plus a random card via `CardRegistry`/`SaveManager.add_card_instance(template_id, rarity)` — follow chest-reward patterns in `scenes/world/entities/Chest.gd`.
5. `hud_message_requested` fallback line for the moment ("You discovered …").

**Journal "Discoveries" section:**
- `scenes/ui/JournalScene.gd` / `JournalScene.tscn` is opened via GameBus `journal_requested` (already touch-accessible — mobile parity satisfied). Study its existing tab/section structure (it lists collected story scrolls per GID-013) and add a Discoveries section listing each discovered landmark's name + biome.
- Names for already-discovered landmarks are regenerated on demand from the id (parse cx/cz from the id, call the name generator) — no need to persist name strings.
- UI sizing rule: dimensions as % of viewport height/width (`get_viewport().get_visible_rect().size`), never fixed pixels; font ~2–2.5% vh.

**Testing:**
- Headless: name determinism; discovery idempotency (second trigger no-ops, no double reward); SaveManager migration default for the new field.
- Run `godot --headless --path . -s tests/runner.gd`; exit 0 required.

## Plan

- Create `game_logic/world/LandmarkNames.gd` with `get_name(cx, cz, world_seed) -> String` and `name_from_id(id, world_seed) -> String`
- Add `discovered_landmarks: Array[String]` to `SaveManager` with migration v38→v39, `mark_landmark_discovered()`, `is_landmark_discovered()` API
- Add `landmark_discovered` signal to `GameBus.gd`
- Add `_active_landmark_data: Dictionary` to `WorldScene`, populate in chunk load/eviction, call `_check_nearby_landmark()` from `_check_interactions()`
- Add `_discover_landmark()` in WorldScene: mark, emit signal, toast, grant 50 coins + rare card, emit hud_message
- Add "Discoveries" tab to `JournalScene.gd` listing landmark names on demand

## Changes Made

- **`game_logic/world/LandmarkNames.gd`** (NEW): Deterministic name generator; `_EPITHETS`, `_NOUNS_BY_VARIANT`, `_PLACES_BY_BIOME` word pools; format `"The <epithet> <noun> of <place>"`; `get_name()` and `name_from_id()` static functions
- **`game_logic/world/LandmarkNames.gd.uid`** (NEW): `uid://wmxy2sahmehc`
- **`autoloads/GameBus.gd`**: Added `signal landmark_discovered(landmark_id: String, display_name: String)`
- **`autoloads/SaveManager.gd`**: Added `discovered_landmarks: Array[String]`, version bump 38→39, migration `_migrate_v38_to_v39()`, `mark_landmark_discovered()`, `is_landmark_discovered()` API, load/save round-trip
- **`scenes/world/WorldScene.gd`**: Added `LandmarkNames` preload, `_active_landmark_data`, `register_landmark()`, `LANDMARK_DISCOVERY_RANGE=9.0`, `_check_nearby_landmark()`, `_discover_landmark()` (toast + 50 coins + rare card + hud_message)
- **`scenes/ui/JournalScene.gd`**: Added "Discoveries" tab button, `_populate_discoveries_list()` listing known landmarks, `_on_discovery_selected()` detail view

## Documentation Updates

- Created `docs/agent/ancient-colossi.md` covering the full system
- Added row to CLAUDE.md docs table
