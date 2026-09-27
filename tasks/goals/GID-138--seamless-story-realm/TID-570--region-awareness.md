# TID-570: Region Awareness Replaces Map-Name Checks

**Goal:** GID-138
**Type:** agent
**Status:** done
**Depends On:** TID-569

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Code keyed on `map_name == "maykalene"` etc. must use the town the player is in.

## Research Notes

Files with stitched-town literals: ObjectiveTracker, PlaceNames, MapRegistry,
NamedMapProps, SiegeDefs, SceneManager, WorldScene, SessionState, TownSiege, StoryCast,
CoopActivities, MultiplayerLobbyScene, NetBattles, BattleVictory, NetworkManager.

## Plan

New world module `RealmRegions` watches the player tile in the overworld and sets
`WorldScene.current_town`; `WorldScene.story_place()` = town or map name. Town
entry runs what a named-map load did (label, music, rivals, siege, entry flags).
Callers keyed on the town switch to `story_place()`; siege gates shift into the realm.

## Changes Made

- New `scenes/world/modules/RealmRegions.gd` (`realm_regions`): `tick()` from the
  infinite branch of `_process`; `_set_town()` → HUD label + music + entry toast,
  `story_cast.spawn_named_map_rivals()`, `town_siege.on_map_entered()`,
  `chapter1_reached_blancogov` / `chapter2_reached_larik`, and leaving Madrian after
  the intro sets `chapter1_left_madrian` + spawns the wilderness camp. `siege_gate(town)`.
- `WorldScene`: `current_town`, `story_place()`; biome label/music skipped inside a town;
  removed the TID-339 "Return to Town" portal (it stood in Madrian's square and popped
  back to the old Madrian map).
- `StoryCast`: Maiteln follows in the whole overworld during Chapter 1; rivals use
  `story_place()` and shift town-local tiles.
- `TownSiege` / `CoopActivities`: `story_place()` + `realm_regions.siege_gate()`;
  raiders and banner are not duplicated on re-entry; co-op night hunts no longer
  skip the overworld.

## Documentation Updates

- Deferred to TID-573.
