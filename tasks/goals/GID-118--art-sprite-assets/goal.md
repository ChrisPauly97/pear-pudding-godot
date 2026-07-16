# GID-118: Open-Source Character, Enemy & World Art Sprites

## Objective

Find and integrate open-source, license-clean pixel-art sprites to replace every procedurally generated `TextureGen` placeholder — enemies, NPCs, props, the mount, and card illustrations — matching the game's pixel-isometric creative direction.

## Context

Modeled on GID-116 (soundtrack assets), which proved the pattern: agent curates a license-verified shortlist, a human downloads the binaries (sandbox proxy 403-blocks all asset sites, even via WebFetch), then the agent wires them in with attribution.

The user approved this goal with **full scope** (2026-07-16, this session): characters/enemies/NPCs *plus* props, mounts, and card illustrations — i.e. everything `game_logic/TextureGen.gd` currently generates as placeholder silhouettes.

Current art state:

- **Real art exists only for the player**: 4 wizard walk frames at `assets/textures/pixel_art/wizard_walk_{1-4}_pixel.png`, assembled by `scenes/world/entities/AvatarSprite.gd` (`build()` — billboard `AnimatedSprite3D`, `PIXEL_SIZE 0.05`, nearest filter, alpha-cut prepass, feet-at-y=0 offset). Used by `Player.gd` and `RemotePlayer.gd`.
- **Everything else is procedural** via `game_logic/TextureGen.gd`:
  - `enemy(is_roaming_boss, is_boss)` — one generic 16×32 humanoid for ALL enemy types (`scenes/world/entities/EnemyNPC.gd:15`, `ScoutAmbush.gd:12`), despite ~15 distinct enemy `.tres` in `data/enemies/` (undead basic/elite, ghoul_pack, martarquas raiders ×3 + warleader, duelists ×3, rival_isfig ×3, mimic, roaming_terror).
  - `npc_townsperson()` (`TownspersonNPC.gd:14`), `npc_merchant(is_traveling)` (`MerchantNPC.gd:12`), `npc_maiteln()` (`MaitelnFollower.gd:65`).
  - `prop(key)` — 10 16×16 biome props (rock, flower, mushroom, fern, cactus, thorn, ash, ember, boulder, lichen) instanced by `ChunkRenderer.gd:343`, keys from `BiomeDef.PROP_SETS`.
  - `mount_horse()` — 48×24 silhouette (`Player.gd:122`).
  - `card_illustration(card_id, magic_branch)` — 32×32 archetype art (ghost/skeleton/zombie/ghoul + spell runes) injected by `CardRegistry.gd:178`.

Unlike GID-116, integration requires **code changes**: `TextureGen` call sites must switch to per-type `preload()`ed textures (with TextureGen kept as graceful fallback for missing files, mirroring `AudioManager`'s no-op pattern).

Creative direction: classic pixel-art RPG in 3D isometric; Hobbit/Redwall warmth, not grimdark; one coherent style/palette across all picks (and coherent with the existing wizard, or the shortlist proposes replacing the wizard frames too).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-444 | Research & curate CC0/CC-BY sprite shortlist per art slot | agent | done | — |
| TID-445 | Acquire & place licensed sprite files under assets/textures/ | human-action | done | TID-444 |
| TID-446 | Wire character/enemy/NPC sprites into entity builders + attribution | agent | pending | TID-445 |
| TID-447 | Wire prop, mount & card illustration sprites + attribution | agent | pending | TID-445 |

## Acceptance Criteria

- [ ] `docs/agent/art-sprites.md` exists with a sprite manifest (slot → file path → source) and a curated shortlist (primary + backup) per slot group: enemy archetypes, NPCs, props, mount, card illustrations — each with direct source URL, license, and required attribution text
- [x] All manifest sprite files exist under `assets/textures/` and are correctly licensed (CC0 preferred; CC-BY acceptable with attribution; no NC/paid) — TID-445, licenses re-verified at download
- [ ] Enemy types render with distinct per-archetype sprites (mapped from `EnemyRegistry` type), not one shared silhouette; NPCs (townsperson, merchant, Maiteln) have real sprites
- [ ] Props, mount, and card illustrations use real sprites; `TextureGen` remains as graceful fallback when a file is absent
- [ ] A `CREDITS`/attribution file documents author, license, and source URL for every included sprite (extending the pattern GID-116/TID-437 establishes)
- [ ] Headless editor import and parse checks are clean after all changes
- [ ] `docs/agent/enemies-and-npcs.md` and `docs/agent/visual-polish.md` updated to reflect real sprite assets
