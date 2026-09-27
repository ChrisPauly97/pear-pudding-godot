# TID-560: Layered PaperDoll Renderer & Local Hero

**Goal:** GID-137
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The player used 0x72 `elf_m` frames (16×28, idle + 4 walk) in `Player.gd`,
`AvatarSprite.gd` and the real-time battle token (`RealtimeVisuals.gd`). Gear
(`SaveManager.equipped_{weapon,armor,offhand,trinket,ring}`) had no visual.

## Research Notes

- Keep 16×28 at `PIXEL_SIZE` 0.05: `SpriteRegistry.PLAYER_HEIGHT` (1.4), the
  mount ride offsets and the contact shadow radius are tuned to it.
- `SpriteOutline` feeds the texture to the outline shader on `frame_changed`;
  after swapping `sprite_frames`, call `SpriteOutline.refresh()`.
- Equip paths: `SaveManager.equip_item()` / `equip_weapon()` (CharacterScene).

## Plan

1. `game_logic/character/PaperDoll.gd`: draw body parts per pose into an Image
   (legs → torso/armour → trinket → arms → head/hair → cloak → held items);
   `GEAR_VISUALS` table maps item id → style + palette; cached SpriteFrames.
2. `GameBus.equipment_changed(slot, item_id)` emitted by both equip methods.
3. Player rebuilds frames on that signal; AvatarSprite + battle token use PaperDoll.
4. Delete `player_hero*.png`; tests; docs.

## Changes Made

- New `game_logic/character/PaperDoll.gd` + `tests/unit/test_paper_doll.gd`.
- `GameBus.equipment_changed`; emitted from `SaveManager.equip_item/equip_weapon`.
- `Player.gd`, `AvatarSprite.gd` (`build(gear := {})`), `RealtimeVisuals.gd` use PaperDoll.
- Removed `assets/textures/characters/player_hero{,_walk_1-4}.png`; CREDITS updated.

## Documentation Updates

- `docs/agent/camera-and-player.md`, `art-sprites.md`, `multiplayer-coop.md`,
  `inventory-and-deck.md` (equipment visuals).
