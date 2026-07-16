# TID-446: Wire Character/Enemy/NPC Sprites Into Entity Builders + Attribution

**Goal:** GID-118
**Type:** agent
**Status:** pending
**Depends On:** TID-445

## Context

With real PNGs in the repo (TID-445), replace the procedural humanoid silhouettes with per-type sprites at every character call site, keeping `TextureGen` as a graceful fallback so the game still runs if a file is missing (same philosophy as `AudioManager`'s `ResourceLoader.exists()` no-op).

## Research Notes

### Call sites to convert

| File | Line (approx) | Today | Target |
|---|---|---|---|
| `scenes/world/entities/EnemyNPC.gd` | 15 | `TextureGen.enemy(_is_roaming_boss, _is_boss)` | per-archetype sprite mapped from enemy type; bosses keep existing scale treatment, optionally tint |
| `scenes/world/entities/ScoutAmbush.gd` | 12 | `TextureGen.enemy()` | raider/scout archetype sprite |
| `scenes/world/entities/TownspersonNPC.gd` | 14 | `TextureGen.npc_townsperson()` | townsperson sprite (variants if available) |
| `scenes/world/entities/MerchantNPC.gd` | 12 | `TextureGen.npc_merchant(_is_traveling)` | merchant sprite (traveling variant if available) |
| `scenes/world/entities/MaitelnFollower.gd` | 65 | `TextureGen.npc_maiteln()` | Maiteln (old wizard) sprite |

### Design: a SpriteRegistry helper

Create a small preload-registry (e.g. `game_logic/SpriteRegistry.gd`, `RefCounted` with statics, preloaded by callers per the CLAUDE.md class_name rule):

- One `const _X := preload("res://assets/textures/characters/....png")` per manifest file — **Android requires literal preloads**, never dynamic `load("dir" + name)` (CLAUDE.md Android rule).
- `static func enemy_texture(etype: String, is_roaming_boss: bool, is_boss: bool) -> Texture2D` — maps `EnemyRegistry` enemy type ids to archetype textures (mapping table from `docs/agent/art-sprites.md`); returns `null` → caller falls back to `TextureGen.enemy(...)`.
- Equivalent accessors for NPC slots.
- Archetype → enemy-type mapping must cover every `.tres` in `data/enemies/` (undead basic/elite, ghoul_pack, martarquas_raider_1-3, martarquas_warleader, duelist_novice/adept/champion, rival_isfig_1-3, mimic, roaming_terror) plus infinite-world spawns — check how `EnemyNPC.configure()` receives its type (`data.get(...)`, `EnemyRegistry.get_is_boss(etype)` at line ~40).

### Constraints & gotchas

- Sprite sizing: keep the feet-at-y=0 formula — `sprite.position.y = tex.get_height() * pixel_size * 0.5 (+ margin)` (CLAUDE.md Sprite3D depth-clipping rule). Don't assume 16×32; read the texture height.
- Keep `TEXTURE_FILTER_NEAREST`, billboard, alpha-cut settings identical to current builders.
- If the pack includes walk frames for NPCs/enemies, wiring animation is OPTIONAL scope — only do it if trivial via the `AvatarSprite.build()` pattern; otherwise log a backlog item.
- If TID-444/445 delivered a player-wizard replacement (optional slot), update `AvatarSprite.gd`'s four preloads; RemotePlayer inherits automatically.
- Run the headless parse/import check after every `.gd` edit (CLAUDE.md). Run `godot --headless --path . -s tests/runner.gd` — `test_mount_dismount_visuals.gd` touches `TextureGen.mount_horse()` (TID-447's slot) and must stay green regardless.

### Attribution

Create or extend the repo CREDITS file (GID-116/TID-437 establishes it at `assets/audio/music/CREDITS.md` or repo root — reuse whatever location it chose; if TID-437 hasn't run yet, create `CREDITS.md` at repo root and note it for TID-437 to merge into). Every sprite: author, license, source URL, verbatim CC-BY attribution where required (captured by the human in TID-445).

### Docs to update

- `docs/agent/enemies-and-npcs.md` — enemy/NPC visuals section.
- `docs/agent/art-sprites.md` — flip shortlist entries to "integrated", document the SpriteRegistry pattern and fallback behavior.
- `docs/agent/visual-polish.md` — references to TextureGen character silhouettes.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
