# TID-318: Interactable highlight & selection outline

**Goal:** GID-089
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** claude/GID-089--game-visual-polish
**Acquired:** 2026-06-25T00:34:08Z
**Expires:** 2026-06-25T01:04:08Z

## Context

Players can't tell at a glance what is interactable on the map. This task adds a visual highlight to the nearest interactable entity — chests, NPC entities, and doors — when the player is within interaction range. The highlight must work on billboard sprites (after TID-302) and on the current door mesh. The pattern is a pulsing emissive ring or outline `MeshInstance3D` placed at the entity's base, which is simpler and more Android-safe than full-screen outline post-processing.

## Research Notes

**Entities that are interactable:**
- `Chest.gd` — player interacts to open
- `Door.gd` — player walks into / taps to enter
- `MerchantNPC.gd`, `TownspersonNPC.gd`, `BountyBoardNPC.gd` — player interacts to talk
- `Waystone.gd` — player interacts to fast-travel
- All have `WorldEntityBase.gd` as a base class

**WorldEntityBase.gd API:**
Check what signals/methods exist. Likely has `interact()` or proximity logic. The player script determines when it's in range.

**Highlight approach — floor ring:**
- Add a `MeshInstance3D` to each interactable entity's scene: a flat `TorusMesh` or thin `CylinderMesh` at `y = 0.05` (just above the tile)
- Material: `StandardMaterial3D` with `emission_enabled = true`, `emission_color = Color(1.0, 0.9, 0.2)`, `albedo_color = Color(0, 0, 0, 0)` (transparent body), `billboard_mode = BILLBOARD_DISABLED`
- Animate the ring pulsing via shader `TIME` or `_process()` with a sine on `emission_energy`
- Show/hide the ring node based on player proximity (exposed via a method on the entity)

**Player proximity check:**
`Player.gd` already tracks position every frame. Add a scan each frame for the closest interactable within `IsoConst.INTERACT_RADIUS` (likely 2–3 tiles) using `get_tree().get_nodes_in_group("interactable")`. Call `entity.set_highlighted(true/false)`.

**WorldEntityBase extension:**
Add `set_highlighted(on: bool)` to `WorldEntityBase.gd` — shows/hides the ring node. Subclasses that have ring nodes inherit this.

**Android constraint:** One `TorusMesh` per entity, no post-process. Trivially cheap. Groups are a standard Godot pattern.

## Plan

Add `build_highlight_ring(parent, radius)` static + `_ring` field + `set_highlighted(on)` instance method to `WorldEntityBase`. Add `add_to_group("interactable")` + ring setup to `_ready()` of all 6 interactable entities. Add `_scan_interactables()` to `Player.gd` called at ~7 Hz from `_physics_process`.

## Changes Made

- `scenes/world/entities/WorldEntityBase.gd`: Added `var _ring: MeshInstance3D = null`, `static func build_highlight_ring(parent, radius) -> MeshInstance3D` (creates `CylinderMesh` with inline pulsing emissive shader), `func set_highlighted(on)`.
- `scenes/world/entities/MerchantNPC.gd`, `TownspersonNPC.gd`, `BountyBoardNPC.gd`: Added `add_to_group("interactable")` + `_ring = build_highlight_ring(self, 0.55/0.6)` in `_ready()`.
- `scenes/world/entities/Chest.gd`, `Door.gd`, `Waystone.gd`: Added `const _WEB = preload(WorldEntityBase)`, `var _ring`, `add_to_group("interactable")`, `_ring = _WEB.build_highlight_ring(self, r)` in `_ready()`, `func set_highlighted(on)`.
- `scenes/world/entities/Player.gd`: Added `_highlight_timer`, `_highlighted_node`, `_SCAN_INTERVAL=1/7`, `_INTERACT_RADIUS=3.0`, `_scan_interactables()` proximity scan in `_physics_process`.

## Lock

**Session:** none
**Acquired:** —
**Expires:** —
