# TID-447: Wire Prop, Mount & Card Illustration Sprites + Attribution

**Goal:** GID-118
**Type:** agent
**Status:** pending
**Depends On:** TID-445

## Context

Companion to TID-446, covering the non-humanoid `TextureGen` slots: biome props, the rideable mount, and card illustrations. Same fallback philosophy: real sprite when the file exists, `TextureGen` procedural art otherwise. If TID-446 has already landed its SpriteRegistry helper, extend it rather than creating a second registry.

## Research Notes

### Call sites to convert

| File | Line (approx) | Today | Target |
|---|---|---|---|
| `scenes/world/ChunkRenderer.gd` | 343 | `TextureGen.prop(str(pt_key))` in `_build_props()` | per-key prop texture; keys are the 10 strings from `BiomeDef.PROP_SETS` (rock, flower, mushroom, fern, cactus, thorn, ash, ember, boulder, lichen) |
| `scenes/world/entities/Player.gd` | 122 | `TextureGen.mount_horse()` | horse sprite |
| `autoloads/CardRegistry.gd` | 178 | `TextureGen.card_illustration(illus_key, magic_branch)` | per-archetype card art (ghost, skeleton, zombie, ghoul) + per-branch spell rune |

### Constraints & gotchas

- **Props are GPU-instanced** by ChunkRenderer (see `docs/agent/visual-polish.md`, GID-089/TID-316) — the texture swap happens where the material/texture is assigned per prop key; keep instancing intact and verify chunk build perf doesn't regress (props rebuild on every chunk load).
- **Card illustrations** flow through `CardRegistry` resource setup (`res.set("illustration", ...)`) — cards are rendered in 2D UI, so nearest-filter import settings matter for crispness; check how the illustration is displayed (battle card UI + inventory) for expected aspect.
- **Mount**: `test_mount_dismount_visuals.gd` asserts against `TextureGen.mount_horse()` (calls it at lines ~173–178, including a caching identity check) — update the test to the new source or keep it exercising the fallback path explicitly; do not leave it asserting stale behavior.
- Android rule: literal `const` preloads only, one per PNG; no dynamic path composition. A dictionary `{"rock": _PropRock, ...}` keyed by prop string is fine (keys literal, values preloaded).
- Run headless parse/import check after every `.gd` edit; full test runner at the end.

### Attribution & docs

- Extend the CREDITS file with prop/mount/card art entries (author, license, URL, verbatim CC-BY text from TID-445).
- Update `docs/agent/art-sprites.md` (entries → "integrated"), `docs/agent/visual-polish.md` (prop scatter + card art sections), `docs/agent/rideable-mounts.md` (sprite + dust visuals section), `docs/agent/inventory-and-deck.md` if card art display details change.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
