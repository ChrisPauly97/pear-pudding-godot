# BID-083: Stream ambience layer still synthesized

**Category:** content-gap
**Discovered During:** GID-152 / TID-644

## Description

The stream layer (`AmbienceLayers.LAYER_PATHS["stream"]`, heard near water) plays the procedural
`AmbienceGen._gen_stream()` loop; no recorded `assets/audio/ambience/stream.ogg` ships. `test_sfx_assets` exempts
it alongside the owl layer (BID-073).

## Evidence

`game_logic/AmbienceLayers.gd`, `tests/unit/test_sfx_assets.gd` (exemption list).

## Suggested Resolution

Source a seamless CC0 babbling-brook loop (freesound CC0, Sonniss GDC bundle), convert to looping ogg, drop the
exemption and credit it in `CREDITS.md`.

## Resolution

A public-domain (PD Mark 1.0) brook field recording by Matthes (radio aporee, via the Internet Archive) now
ships as `assets/audio/ambience/stream.ogg`: 56–92 s, crossfaded seamless, mono 24 kHz. `test_sfx_assets` no
longer exempts it; `AmbienceGen._gen_stream()` stays as the fallback. Credited in `CREDITS.md`.
