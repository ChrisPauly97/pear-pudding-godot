# TID-600: Rift Entrances in Each Biome

**Goal:** GID-142
**Type:** agent
**Status:** done
**Depends On:** TID-597, TID-589

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Each rift is entered from its own biome, so rifting in "different biomes with different enemy types" means travelling.

## Research Notes

- Current entrance: a spire door in a town map (`scenes/world/entities/Door.gd` `_is_spire`, purple modulate L32–44) →
  WorldScene panel (~L1900) → `SceneManager.enter_spire()`. Generalise the panel: rift name, best tier, tier picker
  (1..best+1), active quest, Enter/Resume.
- Placement: one portal per biome in the infinite world. Options: deterministic placement per biome near the first
  chunk of that biome from spawn, or attach to existing landmarks (`InfiniteWorldGen.gd` landmarks L18–30, e.g.
  "shattered_spire" for Scorched). Must be findable: add to realm map / minimap (`RealmMapOverlay`, `Minimap.gd`) once
  discovered. The Grasslands rift should be near Madrian (starter zone, TID-591).
- A rift keeper NPC at each portal gives that rift's quests (TID-599); interaction via `INTERACT_PRIORITY`
  (`test_interact_priority`) or `_try_simple_interaction` table.
- Gate on `feat_spire` (GID-141 TID-589): portal visible but "The rift is sealed to you (level 15)" until learned.
- Resuming an active run from another rift's portal: refuse or resume the original — decide in Plan.
- Mobile parity: tap target + interact button.

## Plan

Madrian door = Grasslands rift; deterministic biome portals from world gen (door `rift:<id>`); rift panel moved out of WorldScene into a module with a tier picker; resume the active run from any door. Rift keepers per portal were dropped in favour of the one Rift Warden in Madrian (TID-599) — quests need a findable giver, portals are procedural.

## Changes Made

- New `scenes/world/modules/RiftPortals.gd`; WorldScene forwards `_show_spire_entrance_panel(rift_id)` (−35 lines;
  ceiling 2180 → 2100).
- `InfiniteWorldGen._gen_entities`: rift portals. `RiftDefs`: `rift_for_biome`, `PORTAL_RARITY`, `PORTAL_MIN_CHUNK`.
- `Door.gd`: rift doors purple + named.
- Tests: `test_rift_defs.gd` +1 (door targets, portals match biome, none in the starter region, several rifts
  reachable); `world_scene_smoke.gd` builds locked + unlocked rift panels.

## Documentation Updates

`rifts.md` entrances; CLAUDE.md world-module row.
