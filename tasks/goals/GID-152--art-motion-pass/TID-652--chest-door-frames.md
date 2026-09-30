# TID-652: Chest and door opening frames

**Goal:** GID-152
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Chests swap closed→open instantly; doors have one frame; mimic has no reveal. Part of GID-152 (art motion pass).

## Research Notes

- `generate_sprites.py` `chest_body()` / `chest()` / `door()`: add 2-3 intermediate frames. Mimic (`generate_characters.py` on `chest_body`) gets a reveal (lid pops, teeth).
- Runtime: chest open handled in `scenes/world/modules/ChestLoot.gd`; play frames then settle on `chest_open.png` (co-op sync already sends open state — play animation on receive too). Doors: named-map doors/crypt doors.

## Plan

Ajar frames for chest and door (plus a fully open door); one-shot `SpriteLoop.play_once`; hook chest open, mimic
spring (before the engage emit) and door interaction.

## Changes Made

- `tools/generate_sprites.py`: `chest_ajar()`, `door_frame()`; 3 new props PNGs (existing ones unchanged).
- `game_logic/LandmarkFrames.gd`: `chest_opening()`, `mimic_reveal()`, `door_opening()`.
- `scenes/world/entities/SpriteLoop.gd`: `play_once()`.
- `Chest.gd` (`_animate_open`, `reveal_mimic`), `Door.gd` (`play_open`), `ChestLoot._spring_mimic`,
  WorldScene door branch (+3 lines).
- Test: `test_sprite_loop::test_opening_frames_match_their_canvases`.

## Documentation Updates

- `docs/agent/art-sprites.md`: "Opening frames".
