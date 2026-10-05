# TID-669: Typed Calls

**Goal:** GID-161
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal.

## Research Notes

- Autoload lookups through the tree (`get_node_or_null("/root/X")`) are kept where they guard autoload-less
  `-s` runs; the result is cast to the preloaded autoload script so members are checked.
- Fields that can hold freed nodes (`WorldScene._maiteln_node`, `_remote_player_nodes` values) stay `Node3D`;
  they are cast locally *after* a validity check (CLAUDE.md "Freed Node Dictionary Crash").
- Left dynamic on purpose: genuinely polymorphic receivers (`Player` highlight targets, chest/enemy nodes that
  may be mimics or stand-ins, leaderboard overlays of two kinds, `CardRegistry` resources), the Minimap inner
  draw class, and test stubs that `set("world_scene", stub)` on NetSync.

## Plan

Retype receivers to their preloaded scripts; delete guards made redundant by static types.

## Changes Made

- `game_logic/WorldEvents.gd`: every receiver typed (`_WorldEventManager`, `_WorldScene`, `_EnemyNPC`,
  `_MerchantNPC`, `_WorldItem`, `_GameBus`, `_AudioManager`, `_SceneManager`); `_autoload()` / `_hud_message()`
  helpers. **Fix:** the card-shower sparkle material was set on a `MeshInstance3D` that was never parented
  (leaked one orphan node per shower, and particles drew untextured white quads); the material now sits on the
  draw-pass mesh with `BILLBOARD_PARTICLES`.
- `RemotePlayer.world_scene` / `MaitelnFollower.world_scene`: typed `_WorldScene`; direct `get_terrain_height`.
- `CoopSession.remote_avatar(pid)` typed accessor used by CoopSession + CoopSocial; Maiteln net state typed.
- `StoryCast`: typed `MaitelnFollower` setup / `set_networked`.
- `ChunkRenderer`: removed 17 `has_method` / `.get("world_seed")` guards on the already-typed `world_scene`.
- `TapToMove`: typed player calls, `joystick: _VirtualJoystick`.
- `WorldScene`: door open, waystone activate, blight heart engage, scout ambush interact, card-shower end typed.
- `WorldHUD`: pause / interact buttons call WorldScene directly.

## Documentation Updates

None — CLAUDE.md already states the rule.
