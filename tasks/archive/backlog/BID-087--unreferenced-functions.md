# BID-087: Unreferenced Functions and Constants

**Type:** code-smell
**Found:** GID-157/158 research (cleanup pass)

## Problem

37 functions and 8 constants have no reference anywhere in the repo (`.gd`, `.tscn`, `.tres`, tests included;
string `call("…")` uses counted). Removal was deferred: the automated bulk delete was blocked by the session's
permission policy, so it needs a human go-ahead.

## Functions

- `autoloads/AudioManager.gd`: `stop_narration`, `is_narration_playing`, `stop_music`, `get_music_volume`,
  `get_music_duck`, `get_ambience_keys`
- `autoloads/CraftingRegistry.gd`: `get_recipes_for_template`, `get_recipe`
- `autoloads/NetworkManager.gd`: `is_reconnecting`
- `autoloads/SkillRegistry.gd`: `get_by_type`
- `autoloads/WorldEventManager.gd`: `get_event_position`
- `autoloads/save_manager/SaveQuests.gd`: `abandon`
- `game_logic/progression/UnlockLadder.gd`: `ids_up_to`
- `game_logic/quests/StoryQuests.gd`: `is_story_done`
- `game_logic/world/BlightField.gd`: `get_nearest_heart`
- `game_logic/world/RealmLayout.gd`: `is_road_tile`
- `game_logic/world/WorldMap.gd`: `find_nearby_shrine`
- `game_logic/world/ZoneLevels.gd`: `range_at_tile`
- `scenes/ui/CompassRibbon.gd`: `remove_marker`
- `scenes/ui/UiUtil.gd`: `make_rarity_selector`
- `scenes/world/ChunkRenderer.gd`: `is_lit_world`
- `scenes/world/ChunkStreamingManager.gd`: `get_last_player_chunk`
- `scenes/world/DayNightCycle.gd`: `height_fog_on`, `cloud_strength`
- `scenes/world/TownStreetsView.gd`: `lamp_count`
- `scenes/world/WorldHUD.gd`: `refresh_visibility`, `get_action_button`
- `scenes/world/WorldScene.gd`: `get_entity_root`
- `scenes/world/coop/CoopAppearance.gd`: `gear_for_peer`
- `scenes/world/modules/CharacterPresence.gd`: `animated_count`
- `scenes/world/modules/FakeVolumetrics.gd`: `visible_shafts`, `shaft_strength`, `is_fog_visible`
- `scenes/world/modules/NightLights.gd`: `pool_count`, `halo_count`, `active_count`
- `scenes/world/modules/StarterCamps.gd`: `scenery_count`

## Constants

`autoloads/IsoConst.gd`: `ISO_TW`, `ISO_TH`, `ISO_HALF_W`, `ISO_HALF_H`, `WALL_FACE_TEX_H`, `CAM_ELEVATION_DEG`,
`CAM_AZIMUTH_DEG`, `CAM_ORTHO_SIZE`.

## Fix

Delete each (plus its `##` doc comment); some `*_count` accessors look like intended test hooks — either add the
test or delete. Re-run the scan, import, tests, gdlint, `unsafe-hits.sh`.
