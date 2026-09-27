# BID-063: Co-op Sessions Still Start on the Named Town Maps

**Category:** design-inconsistency
**Discovered During:** TID-571 (GID-138)

## Description

GID-138 stitched the outdoor story towns (madrian, maykalene, blancogov, larik,
marsax_hold) into the overworld for single-player. Co-op still hosts and joins on
the old named `madrian` map, whose `.tres` keeps its town-to-town doors, so a
co-op party plays the story through the old door-and-transition maps.

## Evidence

- `scenes/ui/MultiplayerLobbyScene.gd` `_COOP_MAP = "madrian"`
- `autoloads/NetworkManager.gd` discovery reply map `"madrian"`
- `autoloads/scene_manager/NetBattles.gd` `resume_pvp_battle` → `enter_map_coop("madrian")`
- `scenes/world/coop/CoopActivities.gd` spire summary → `enter_coop_map_no_stack("madrian")`
- `game_logic/net/SessionState.gd` default `current_map` / character `map` = `"madrian"`
- `SceneManager._maybe_boot_dedicated_server` default map `"madrian"`

## Suggested Fix

Switch those defaults to `"main"` and verify the named-map-only co-op features
(synced weather, night hunts, siege, world-object sync) against the infinite
world with a real two-peer run; update `test_session_state` / co-op tests.
