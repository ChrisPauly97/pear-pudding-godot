# TID-467: Player Hero Sprite Swap (elf_m)

**Goal:** GID-123
**Type:** agent
**Status:** done
**Depends On:** TID-466

## Lock

**Session:** none · **Acquired:** — · **Expires:** —

## Context

The player still used the hand-made 32 px wizard frames
(`assets/textures/pixel_art/wizard_walk_{1-4}_pixel.png`); GID-118 deferred
the pack swap. User request: "my character should use a third party sprite."

TID-445's suggestion (player takes `wizzard_m`) was rejected on story
grounds: `wizzard_m` is a white-bearded old wizard — that is Maiteln, who
already wears it. The player is Saimtar, an 11-year-old adventurer, and the
pack's young hero `elf_m` (blond, green tunic — fitting the spec's Zelda
inspiration) was free apart from doubling as the rival's sprite.

## Plan

1. Crop `elf_m_idle_anim_f0` + `elf_m_run_anim_f0-3` (16×28) from the
   freshly downloaded 0x72 v1.7 pack into
   `assets/textures/characters/player_hero{,_walk_1-4}.png`.
2. Repoint `Player.gd` and `AvatarSprite.gd` (RemotePlayer avatars) at the
   new frames; add a dedicated `_IdleTex` so idle uses the idle pose rather
   than run frame 1. `PIXEL_SIZE 0.05` stays — 28 px → 1.4 world units, the
   TID-466 reference height.
3. Regenerate `enemy_rival{,_walk_1-4}.png` as a hostile palette recolor of
   `elf_m` (crimson tunic, violet hair, red eyes) so the rival stays
   distinct — now literally the player's dark mirror.
4. Update CREDITS.md.

## Changes Made

- New: `assets/textures/characters/player_hero.png` + `player_hero_walk_1-4.png`
  (0x72 `elf_m`, CC0) with generated `.import` sidecars.
- Overwritten: `assets/textures/characters/enemy_rival.png` +
  `enemy_rival_walk_1-4.png` (recolor maps: tunic 75,167,71→178,58,58;
  shade 61,115,79→115,40,52; hair 250,203,62→146,86,190; hair shade
  238,142,46→96,52,135; eyes 86,152,204→214,72,72).
- `scenes/world/entities/Player.gd`: `_IdleTex` + walk preloads → new paths;
  idle animation uses `_IdleTex`.
- `scenes/world/entities/AvatarSprite.gd`: same swap for co-op avatars.
- Old wizard frames remain on disk but are unreferenced (nothing preloads
  them, so they are not packed into exports).
- `CREDITS.md`: player-hero row, rival recolor note.

## Documentation Updates

- `docs/agent/art-sprites.md` (GID-123 section), `docs/agent/camera-and-player.md`
  asset table, `docs/agent/multiplayer-coop.md` asset note.
