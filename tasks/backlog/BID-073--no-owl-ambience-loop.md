# BID-073: Night owl ambience layer still synthesized

**Category:** content-gap
**Discovered During:** GID-145 / TID-616

## Description

Every ambience slot got a real CC0 loop except `owls.ogg` (forest/mountain
nights). No clean CC0 owl loop turned up on opengameart.org during the search,
so `AmbienceGen`'s synthesized owl layer still plays there.

## Evidence

`game_logic/AmbienceLayers.gd` `LAYER_PATHS["owls"]`; `assets/audio/ambience/`
has no `owls.ogg`; `test_sfx_assets.test_ambience_files_exist_and_loop` skips it.

## Suggested Resolution

Find a CC0 owl/night-forest loop (freesound.org CC0 filter needs an account),
drop it in as mono `owls.ogg` with `loop=true`, and remove the skip in the test.
