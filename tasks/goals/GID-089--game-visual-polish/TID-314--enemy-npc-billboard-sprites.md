# TID-314: Pixel-art enemy & NPC billboard sprites

**Goal:** GID-089
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

All enemies (`EnemyNPC.gd`) and NPCs (`MerchantNPC.gd`, `TownspersonNPC.gd`, `BountyBoardNPC.gd`) currently render as solid colored `BoxMesh` assemblies (red box body + darker head/legs). The player entity uses a proper pixel-art `Sprite3D` with walk animation frames from `assets/textures/pixel_art/wizard_walk_*.png`. This task replaces the box meshes with billboarded `Sprite3D` nodes, painted procedurally via `TextureGen` the same way the mount horse texture is made. One silhouette-style texture per entity archetype.

## Research Notes

**Current rendering (EnemyNPC.gd ~lines 14–60):**
- `_body_mat`, `_dark_mat` are `StandardMaterial3D` with plain `albedo_color`
- Three `BoxMesh` instances are built in `_setup_visuals()`: body (0.5×0.55×0.3), head (0.35×0.35×0.35), two legs (0.22×0.5×0.22)
- For boss/elite variants: same pattern with gold/crimson color swaps (~lines 155–180)
- NPC scripts follow the same box-mesh pattern in their own `_setup_visuals()`

**Player sprite pattern (Player.gd + Player.tscn):**
- `Sprite3D` node with `billboard = BILLBOARD_ENABLED`, `pixel_size = 0.04`
- Frames from `wizard_walk_1..4_pixel.png` (48px textures → ~1.92 world units tall)
- Position offset `y = 1.1` to clear the tile floor

**TextureGen pattern (game_logic/TextureGen.gd):**
- `static func _cached(key, generator)` memoizes `ImageTexture` by string key
- `_make_path_tex(seed)` and `_gen_mount_horse()` use `Image.create()` + `set_pixel()` to paint programmatically
- All textures are 16×32 or 32×32 pixel-art images

**Android constraint:** `Sprite3D` billboards are cheap — single quad, no geometry shader needed. Cached `ImageTexture` from `TextureGen` means no file assets needed (no `.uid` sidecar required for runtime-generated textures).

**Sprite height formula (from CLAUDE.md):**
`sprite.position.y = pixel_height * pixel_size * 0.5 + margin`
For 32px height, pixel_size=0.04: `y = 32 * 0.04 * 0.5 + 0.05 = 0.69`

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
