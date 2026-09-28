# TID-587: Replace Synthesized SFX with CC0 Files

**Goal:** GID-141
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Every SFX key currently plays a `SfxGen` synthesized stand-in. Ship one real
CC0 file per key so the game sounds finished.

## Research Notes

- `autoloads/AudioManager.gd` `SFX_PATHS` (26 keys) points at `.wav` files.
  `_ready()` loads a path when `ResourceLoader.exists(path)`, otherwise falls back
  to `SfxGen.get_sfx(key)` / `FootstepSurface.get_sfx(key)`. Keep the fallback.
- **There is no ffmpeg/sox in the container.** Sources are `.ogg`, so change the
  `SFX_PATHS` extensions to `.ogg` (AudioStreamOggVorbis imports fine; one-shots
  must stay non-looping, which is the Godot default for ogg). Update the table in
  `assets/audio/sfx/README.md`.
- Downloads (all CC0, fetched OK via curl during research):
  - Kenney Casino Audio: `https://kenney.nl/media/pages/assets/casino-audio/2472606a04-1721639069/kenney_casino-audio.zip`
  - Kenney Impact Sounds: `https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip`
  - Kenney RPG Audio: `https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip`
  - Kenney Interface Sounds: `https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip`
  - Kenney Music Jingles: `https://kenney.nl/media/pages/assets/music-jingles/f37e530b9e-1677590399/kenney_music-jingles.zip`
  - Kenney Digital Audio: `https://kenney.nl/media/pages/assets/digital-audio/216eac4753-1677590265/kenney_digital-audio.zip`
  - OGA 80 CC0 RPG SFX: `https://opengameart.org/sites/default/files/80-CC0-RPG-SFX_0.zip`
  - OGA 100 CC0 SFX #2: `https://opengameart.org/sites/default/files/sfx_100_v2.zip`
  - OGA pages (grab the file link from the page): `/content/fantozzis-footsteps-grasssand-stone`,
    `/content/6-short-water-splashes`, `/content/horse-trotting`, `/content/magic-spell-sfx`
- Suggested mapping (audition and adjust):

  | Key | Candidate |
  |---|---|
  | card_draw | casino `card-slide-*` |
  | card_play | casino `card-place-*` |
  | spell_resolve | 80-RPG `spell_01/02` or Magic Spell SFX |
  | attack | impact `impactPunch_medium_*` / 80-RPG `blade_*` |
  | battle_win / battle_lose | Music Jingles (short win/lose stingers) |
  | enemy_engage / enemy_alert | 80-RPG `creature_roar_*` / `creature_misc_*` |
  | chest_open | rpg `creak*` + `metalLatch` or 80-RPG `lock_*` |
  | scroll_pickup | rpg `bookFlip*` |
  | door_enter | rpg `doorOpen_*` |
  | footstep, footstep_stone | impact `footstep_concrete_*` |
  | footstep_grass / snow / wood | impact `footstep_grass_*` / `footstep_snow_*` / `footstep_wood_*` |
  | footstep_sand | Fantozzi's Footsteps (sand) |
  | footstep_water | 100-SFX `footstep_wet_*` or 6 Short Water Splashes |
  | footstep_hoof | Horse Trotting (trim one hoofbeat) |
  | nightfall_ambient | Music Jingles (soft/low stinger) |
  | ui_click | interface `click_*` |
  | land | impact `impactSoft_medium_*` |
  | dig_success | impact `impactMining_*` / 80-RPG `item_gem_*` |
  | waystone_travel | Digital Audio (phaser/powerUp) or 80-RPG `spell_*` |
  | thunder | 100-SFX `thunder_01` (or OGA Rain + Long Thunder) |

- Loudness: no ffmpeg, so balance with per-key gain. Add a `SFX_GAIN_DB` dict next
  to `SFX_PATHS`, applied in `_play_pooled`, rather than editing the files.
- Credits: repo-root `CREDITS.md` already lists the music. Add an SFX section
  (pack name, author, URL, CC0).
- Budget: the Kenney packs are ~1 MB each in total; one file per key should come to well under 2 MB.
- Validate: headless import, `godot --headless --path . -s tests/runner.gd`,
  `gdlint`, and grep the test log for `SCRIPT ERROR`.

## Plan

Download the CC0 packs, pick one source per key, convert with ffmpeg (installed via `pip install imageio-ffmpeg`), repoint `SFX_PATHS` to `.ogg`, add a per-key gain table, credit everything.

## Changes Made

- `assets/audio/sfx/<key>.ogg` for all 26 keys: mono Vorbis q4, leading silence
  stripped, peak-normalised to −1 dBFS (two-pass `volumedetect`). 692 KB with takes.
- Final mapping: card_draw casino `card-slide-1..4`; card_play `card-place-1..4`;
  spell_resolve `magical_1`; attack impact `impactPunch_medium_000..004`;
  battle_win jingle `PIZZI02` (rising), battle_lose `PIZZI01` (falling; picked by a
  pitch-trend scan); enemy_engage 80-RPG `creature_roar_01`; enemy_alert
  `creature_misc_03`; chest_open rpg `metalLatch`+`creak1`; scroll_pickup
  `bookFlip1..3`; door_enter `doorOpen_1/2`; footstep rpg `footstep00..04`;
  footstep_grass/stone/snow/wood impact `footstep_{grass,concrete,snow,wood}_000..004`;
  footstep_sand three slices of Peludo's sand take; footstep_water 100-SFX
  `footstep_wet_01..03`; footstep_hoof four hoofbeats sliced from `Trot.ogg`;
  nightfall_ambient jingle `STEEL06`; ui_click `click_001..003`; land
  `impactSoft_medium_000..002`; dig_success `impactMining_000`+`item_coins_04`;
  waystone_travel `magical_4`; thunder 100-SFX `thunder_01`.
- `AudioManager`: `SFX_PATHS` → `.ogg` (`nightfall.wav` → `nightfall_ambient.ogg`);
  `SFX_GAIN_DB` + `_sfx_trim_db` (trim applies to file-backed keys only).
- `CREDITS.md`: new "Sound Effects & Ambience" section with authors and URLs.
- `tests/unit/test_sfx_assets.gd`: every key has a file; gain/takes tables name real keys.

## Documentation Updates

`docs/agent/audio-manager.md` (file map → .ogg, adding-a-sound steps, new "Real files, takes and mix" section); `assets/audio/sfx/README.md`.
