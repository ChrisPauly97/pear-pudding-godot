# BID-076: The hero's skin / hair can only be chosen at New Game

**Category:** content-gap
**Discovered During:** TID-562

## Description

`HeroAppearanceScene` runs only between slot select and world select. There is no way to change the look later,
and the Character screen shows a grey placeholder square instead of the hero.

## Suggested Fix

Open the same picker from the Character screen in an edit mode that saves straight into
`SaveManager.hero_appearance` and redraws the hero; show the PaperDoll idle frame as the Character screen avatar.

## Resolution

- `HeroAppearanceScene` gained an edit mode (`edit_mode`, `closed` signal, static `open_editor(tree, on_closed)`):
  Save writes `SaveManager.hero_appearance`, marks the save dirty and emits `equipment_changed("appearance", "")`,
  which already redraws the local hero (`Player._on_equipment_changed`) and re-sends the co-op gear + look payload
  (`CoopAppearance`). Cancel just closes.
- The Character screen's grey placeholder is now the hero's PaperDoll idle frame (gear + look), with a
  **Change Look** button under the name that opens the editor and rebuilds the screen afterwards.
- Checked headlessly (save → look stored, signal fired, editor closed) and by a 1280×720 capture.
