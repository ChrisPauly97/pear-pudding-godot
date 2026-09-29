# TID-562: Hero Appearance Picker (skin, hair)

**Goal:** GID-137
**Type:** agent
**Status:** done
**Depends On:** TID-560

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`PaperDoll` already takes an `appearance` Dictionary overriding
`DEFAULT_APPEARANCE` colours (skin, hair, eyes, shirt, trousers, boots, belt).
Nothing persists or exposes it yet.

## Research Notes

- Add one `SaveManager.PERSISTED_FIELDS` entry (e.g. `hero_appearance: {}`)
  storing colour hex strings; convert to Color in a helper before PaperDoll.
- Picker UI via `UiUtil` factories on the New Game flow; live PaperDoll preview
  (`PaperDoll.idle_texture(gear, appearance)` in a nearest-filtered TextureRect).
- Hair *style* variants would be a new `hair_style` key + draw routine.

## Plan

1. Presets, not free colours: `PaperDoll.SKIN_TONES` / `HAIR_COLOURS` (6 each,
   pack-palette colours, index 0 = `DEFAULT_APPEARANCE`). Saves and co-op carry
   indices only, so junk can't reach the renderer.
2. `SaveManager.hero_appearance` (one `PERSISTED_FIELDS` entry, default `{}` —
   old saves keep the default look) + non-persisted `pending_appearance` that
   `new_game()` moves in, so an abandoned picker can't leak into a loaded save.
3. `HeroAppearanceScene` between SlotSelect and BiomeSelection: swatch Buttons
   (mouse/touch/keyboard focus) + live preview.
4. Local hero (Player, battle token) and co-op avatars draw the chosen look;
   the look rides the gear payload as a tail (`encode_look` / `decode_look`).
5. Hair *style* variants left out (no draw routine yet).

## Changes Made

- `PaperDoll.gd`: presets, `appearance_from`, `look_index`, `appearance_of`,
  `frames_for`, `encode_look`, `decode_look`.
- `SaveManager.gd`: `hero_appearance`, `pending_appearance`, `new_game()` hand-off.
- New `scenes/ui/HeroAppearanceScene.{gd,tscn}`; `SlotSelectScene` routes to it,
  `BiomeSelectionScene` Back returns to it.
- `Player.gd` (`frames_for`), `RealtimeVisuals.gd`, `AvatarSprite.build(gear, appearance)`,
  `RemotePlayer.set_gear(gear, look)`, `CoopAppearance` (`_remote_look`), NetSync doc.
- Tests: `test_paper_doll` (index validation, every preset changes the sprite,
  payload tail round-trip + old/junk peers), `test_head_feet_equipment`
  (`new_game` adopts the pending look).

## Documentation Updates

- `camera-and-player.md` (Appearance), `ui-and-scene-management.md` (new scene,
  New Game flow), `multiplayer-coop.md` (gear payload look tail).
