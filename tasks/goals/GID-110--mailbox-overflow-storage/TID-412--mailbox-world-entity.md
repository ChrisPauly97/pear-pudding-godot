# TID-412: Mailbox World Entity + Interaction Wiring Across Maps

**Goal:** GID-110
**Type:** agent
**Status:** pending
**Depends On:** TID-411

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The Mailbox needs to be a physical, interactable object placed in madrian, maykalene, blancogov, and the player's home (once purchased) — not a menu tab. Named maps are `.tres` `MapData` resources that aren't hand-edited directly (see `docs/agent/named-maps-and-dungeons.md`), so placement must use the same "inject near spawn if the map has no authored data for it" technique already used for Waystones, rather than editing map files.

Mailbox is structurally closer to **Waystone** (a standalone tracked entity type with its own `_nodes`/`_active_data` dictionaries and its own interact-range check) than to the generic NPC pipeline (`npc_type` match in `ChunkRenderer.gd`/`WorldScene.gd`) — do not route it through `npc_type`. This task only wires the entity, interaction, and signal plumbing; it does not build the overlay UI (that's TID-413) — stub the signal handler to open a placeholder/empty overlay or leave `_on_mailbox_requested` calling `_open_overlay` with whatever packed scene TID-413 will fill in (a minimal placeholder `.tscn` is fine so this task's acceptance criteria — "opens something" — can be verified independently).

## Research Notes

**Waystone precedent to mirror** (`scenes/world/WorldScene.gd`):
- Tracking dicts: `var _waystone_nodes: Dictionary = {}` and `var _active_waystone_data: Dictionary = {}` (near line 294).
- Spawn-from-chunk-data path: `chunk_data.waystones` loop around line 3005 (erase from tracking dicts when a chunk unloads) — Mailbox likely doesn't need this half, since it's only ever injected near spawn on named maps, never procedurally generated in infinite chunks. Skip it unless you find the map's own `.tres` can define mailboxes some other way (it can't yet — there's no `MapMailbox` resource type, and adding one is out of scope for this task; injection-only is correct).
- **Named-map injection** — `const _NAMED_MAP_WAYSTONE_LABELS: Dictionary` (`scenes/world/WorldScene.gd:3300-3307`) and `func _spawn_named_map_waystones()` (`scenes/world/WorldScene.gd:3309-3344`), called once from `_ready()` at `scenes/world/WorldScene.gd:533`. Copy this shape for mailboxes:
  ```gdscript
  const _NAMED_MAP_MAILBOX_LOCATIONS: Array[String] = ["madrian", "maykalene", "blancogov", "player_home"]

  func _spawn_named_map_mailboxes() -> void:
      if world_map == null:
          return
      if not _NAMED_MAP_MAILBOX_LOCATIONS.has(map_name):
          return
      if map_name == "player_home" and not SceneManager.save_manager.home_owned:
          return
      # pick an offset near spawn (mirror waystone's tx/tz clamp logic), instantiate _MailboxScene,
      # add to _entity_root, position at get_terrain_height(...)+offset, store into _mailbox_nodes / _active_mailbox_data
  ```
  Call `_spawn_named_map_mailboxes()` from `_ready()` right after `_spawn_named_map_waystones()` (line 533). **No special "purchased mid-session" hook is needed**: purchasing the home happens at the `house_door` interact (`scenes/world/WorldScene.gd:4521-4526`, `_show_house_door_panel`) *before* `SceneManager.enter_map("player_home", "exit_door")` runs — by the time the player_home scene's `_ready()` executes, `home_owned` is already `true`, so the normal map-load spawn path already sees it correctly. Do not build extra dynamic-repopulation logic for this.
  One offset per map is enough (single mailbox per location) — a flat `Dictionary` keyed by `map_name` (like a simplified version of `_NAMED_MAP_WAYSTONE_LABELS`) or a small per-map offset table works; exact tile offset from spawn doesn't need design review, just avoid stacking it on top of the waystone spawn point (add e.g. `+2` tiles further out, follow the same `world_map.has_player_spawn()` / clamp logic at `scenes/world/WorldScene.gd:3317-3320`).

- **Interact-range lookup** — mirror `_find_nearby_waystone` (`scenes/world/WorldScene.gd:3488-3496`) as `_find_nearby_mailbox(px, pz, range_dist) -> Dictionary` scanning `_active_mailbox_data`.
- **Label switch** — add `elif not mailbox.is_empty(): interact_label = "MAIL"` alongside the waystone case at `scenes/world/WorldScene.gd:3965-3966` (and thread `var mailbox := _find_nearby_mailbox(...)` into the `has_entity` boolean at line 3940, same as the other entity types).
- **Interact dispatch** — add a block mirroring `scenes/world/WorldScene.gd:4413-4422` (waystone case) right after it: `var mailbox := _find_nearby_mailbox(px, pz, IsoConst.INTERACT_RANGE); if not mailbox.is_empty(): GameBus.mailbox_requested.emit(); return`.

**New entity script/scene** — clone `scenes/world/entities/BountyBoardNPC.gd` (57 lines, full file already read: procedural `BoxMesh` post + board via `StandardMaterial3D`, `Label3D` child, `WorldEntityBase` highlight ring, `init_from_data(data)`, `_ready()` builds the visual and calls `add_to_group("interactable")`). Give Mailbox its own simple procedural look (e.g. a post + a small box "mailbox" head, distinct color, `Label3D` text "Mailbox") — do not reuse BountyBoard's mesh dimensions/colors verbatim, pick something visually distinct (e.g. a red/brown box on a post, postbox-shaped). Save as `scenes/world/entities/MailboxNPC.gd` + `MailboxNPC.tscn`, remembering the `.uid` sidecar rule (CLAUDE.md "Godot Resource .uid Files") for the new `.tscn`.

**GameBus signal** — add `signal mailbox_requested` next to `signal bounty_board_requested` (`autoloads/GameBus.gd:18`).

**SceneManager wiring** (mirror bounty board exactly):
- `enum State { ... }` (`autoloads/SceneManager.gd:3`) — add `MAILBOX,` next to `BOUNTY_BOARD,` (line 16).
- Preload: add `var _mailbox_scene_packed := preload("res://scenes/ui/MailboxScene.tscn")` next to `_bounty_board_scene_packed` (`autoloads/SceneManager.gd:59`). TID-413 builds the real `MailboxScene`; this task can create a minimal placeholder overlay scene/script (empty panel + close button, extending `BaseOverlay.gd` like every other overlay) so the signal chain is testable end-to-end now, and TID-413 replaces its contents in place (same file path) without touching this wiring again.
- Connect: `GameBus.mailbox_requested.connect(_on_mailbox_requested)` next to line 125.
- Handler: `func _on_mailbox_requested() -> void: _open_overlay(_mailbox_scene_packed, State.MAILBOX)`, mirroring `autoloads/SceneManager.gd:1368-1369`.

**Home/map ids** — `SaveManager.home_owned: bool` field (search `autoloads/SaveManager.gd` for `home_owned`), `player_home` map registered in `autoloads/MapRegistry.gd` (search for `_PLAYER_HOME`/`"player_home"`).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
