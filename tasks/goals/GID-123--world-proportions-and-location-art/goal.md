# GID-123: World Proportions, Player Hero Sprite & Location Art

## Objective

Direct user request (2026-07-26, branch `claude/world-scaling-sprites-5mp8em`):

1. Make open-world entity sizes proportional — enemy sprites rendered small
   relative to the player.
2. Swap the player's hand-made wizard sprite for third-party art.
3. Give the rare world locations and the fast-travel obelisks (waystones)
   real textures — they still drew flat-colored primitive meshes.

## Context

GID-118 integrated 0x72/Kenney pack sprites at a flat
`SpriteRegistry.CHAR_PIXEL_SIZE = 0.05`, which made world height track the
source's pixel height: 16 px skeletons rendered 0.8 units tall next to the
32 px / 1.6-unit player. The player itself was still the hand-made wizard
(the TID-445 pack swap was deferred), and five world entities — Waystone,
ManaWell, PuzzleShrine, BurialMound, BlightHeart — still built untextured
primitive meshes with flat unshaded colors.

The outbound proxy allowed itch.io/kenney.nl downloads this session (as it
did during TID-445), so the 0x72 DungeonTilesetII v1.7 and Kenney Tiny
Dungeon packs were re-downloaded and new slots cropped/recolored directly.

Story note: the TID-445 recommendation to give the player `wizzard_m` was
rejected — the white-bearded wizard is story-correct for Maiteln (who keeps
it). The player (Saimtar, an 11-year-old) takes `elf_m`, the pack's young
hero; the rival, which previously used `elf_m`, becomes a hostile recolor.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-466 | Proportional Entity Scaling | agent | done | — |
| TID-467 | Player Hero Sprite Swap (elf_m) | agent | done | TID-466 |
| TID-468 | Waystone & Rare-Location Sprites | agent | done | TID-466 |

## Completion Criteria

- Regular enemies stand 1.15–1.4 world units next to the 1.4-unit player;
  bosses tower at 1.9 × node scale; mimics stay chest-sized.
- Player renders 0x72 `elf_m` (idle + 4-frame walk) in world and co-op
  (RemotePlayer); rival is visually distinct from the player.
- Waystones, mana wells, puzzle shrines, burial mounds, and blight hearts
  render licensed pixel-art sprites with the mesh path kept as fallback.
- Headless compile check clean; full test suite passes; CREDITS.md and
  agent docs updated.
