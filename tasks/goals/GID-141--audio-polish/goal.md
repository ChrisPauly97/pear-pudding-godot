# GID-141: Audio Polish — Real SFX, Ambience & Siege Music

## Objective

Replace the procedurally synthesized placeholder sounds with curated CC0 audio
files, add real biome/weather/time ambience loops, and give town sieges their
own music.

## Context

Raised by the user (2026-09-28): "how else can we polish the experience of the
game" → "audio polish: real SFX, ambience, siege music — can you search for SFX
for me?". `assets/audio/sfx/` and `assets/audio/ambience/` hold only READMEs:
every sound is a stand-in from `game_logic/SfxGen.gd` / `AmbienceGen.gd`
(TID-425, TID-490). Music landed with GID-116, but all towns share one track and
a siege has no track of its own (`docs/agent/game-appeal.md` §6.5). Spec
amendment (2026-07-08, GID-116) puts CC-licensed audio in scope.

Sources were surveyed during goal creation. All candidates are **CC0** and
downloadable from this container (kenney.nl and opengameart.org return 200;
there is no ffmpeg/sox, so ship `.ogg` as-is and repoint paths).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-587 | Replace Synthesized SFX with CC0 Files | agent | pending | — |
| TID-588 | Sound Variation — Random Takes for Repeated SFX | agent | pending | TID-587 |
| TID-589 | Real Biome Ambience Beds + Weather/Time Loops | agent | pending | — |
| TID-590 | Siege Music — Dedicated Track During Town Sieges | agent | pending | — |

## Acceptance Criteria

- [ ] Every `AudioManager.SFX_PATHS` key resolves to a committed real file (synth fallback kept)
- [ ] Footsteps, card and hit sounds vary between several takes
- [ ] All 5 biome beds and 8 `AmbienceLayers.LAYER_PATHS` loops are real files that loop seamlessly
- [ ] A siege plays its own music, and the town track returns on victory/defeat (solo and co-op)
- [ ] Every new file has a `CREDITS.md` entry (source URL, author, CC0)
- [ ] Total added audio stays ≤ ~8 MB; tests, gdlint and headless import are clean
