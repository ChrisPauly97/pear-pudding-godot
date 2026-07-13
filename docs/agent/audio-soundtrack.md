# Soundtrack Assets

## Key Features

- 7 looped music slots, all already wired in code — only the `.ogg` files are missing:
  - `AudioManager.play_music(path)` (autoloads/AudioManager.gd) — dedicated `_music_player`,
    same-track guard, graceful no-op via `ResourceLoader.exists()`, auto-loop by replaying
    on the `finished` signal.
  - `WorldScene.gd` — `_BIOME_MUSIC` maps biome id → `res://assets/audio/music/{grasslands,forest,desert,scorched,mountains}.ogg`; every non-infinite (named) map plays `res://assets/audio/music/dungeon.ogg` (towns AND dungeons share this one track — see BID-048 for the future split).
  - `BattleScene.gd` — plays `res://assets/audio/music/battle.ogg` at end of `_ready()`.
- Curated shortlist below is CC0-first, CC-BY fallback. No NC/paid/stock licenses.
- Attribution obligations are recorded verbatim per pick; TID-437 collects them into a
  repo-level `CREDITS` file.

## Research Constraints (how this list was built)

Researched 2026-07-13 in a sandboxed session. **The outbound proxy returns 403 for
direct fetches of every asset site tried** (opengameart.org, incompetech.com, itch.io,
freemusicarchive.org, even commons.wikimedia.org), so licenses below were verified via
web-search result snippets that explicitly state the license, not by loading the source
page. Confidence is high for every "license verified" line, but **the human performing
TID-436 must confirm the license tag shown on each page at download time** — catalogs
do occasionally change. Anything marked *unconfirmed* below must be checked on-page.

## Shortlist Per Slot

### grasslands.ogg — pastoral, warm, adventurous (Zelda-overworld energy)
- **Primary pick:** GrassLands Theme — DST — **CC0** (license verified) — https://opengameart.org/content/grasslands-theme
  - "A mild medieval openworld type music" with horns and bells — fits the pastoral/adventure brief.
  - Attribution: none required (CC0). Courtesy credit welcome.
  - Format/conversion needed: **yes** — file is `DST-GrassLands.mp3`.
- **Backup pick:** The Field Of Dreams — pauliuw — **CC0** (license verified) — https://opengameart.org/content/the-field-of-dreams
  - Short (~1:24) instrumental cinematic piece; loop point may need trimming.
  - Format/conversion needed: likely yes (check page for available formats).

### forest.ogg — mysterious but gentle, woodwinds/strings
- **Primary pick:** Woodland Fantasy — Matthew Pablo — **CC-BY 3.0** (license verified) — https://opengameart.org/content/woodland-fantasy
  - "Peaceful ballad in a medieval/fantasy style… high quality instruments and a real violin."
  - Attribution text (record verbatim from the page; Matthew Pablo's standard request is a credit naming him with a link to matthewpablo.com, e.g.): `Music: "Woodland Fantasy" by Matthew Pablo — https://matthewpablo.com — CC-BY 3.0`
  - Format/conversion needed: check page (his uploads are usually `.mp3` → convert).
- **Backup pick:** Natural Forest Fantasy Music — Thalon — **CC-BY 4.0** (license verified) — https://opengameart.org/content/natural-forest-fantasy-music
  - Loopable; file is `Fantasy Menu Theme.mp3` → convert.
  - Attribution text: `Music: "Natural Forest Fantasy Music" by Thalon (opengameart.org/users/thalon) — CC-BY 4.0` (confirm exact requested wording on page).

### desert.ogg — sparse, arid, subtle percussion, wide open
- **Primary pick:** Desert Theme — Tarush Singhal — **CC0** (license verified) — https://opengameart.org/content/desert-theme-0
  - Tagged RPG/VGM/desert. Creator *requests* credit as "Tarush Singhal" — not legally required under CC0, but include it in CREDITS anyway.
  - Format/conversion needed: **yes** — file is `desertvibes.mp3`.
- **Backup pick:** Ibn Al-Noor — Kevin MacLeod (incompetech.com) — **CC-BY 3.0** (license verified) — https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100706
  - Attribution text (incompetech standard form): `"Ibn Al-Noor" Kevin MacLeod (incompetech.com). Licensed under Creative Commons: By Attribution 3.0 License. http://creativecommons.org/licenses/by/3.0/`
  - Format/conversion needed: **yes** — `.mp3`.

### scorched.ogg — tense, low drones, embers-and-ash (tension, not horror)
- **Primary pick:** Dark Times — Kevin MacLeod (incompetech.com) — **CC-BY** (catalog-wide license; *confirm 3.0 vs 4.0 wording on page*) — https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100747
  - Dark, tense underscore without horror shrieks — matches the "embers and ash, not grimdark" brief. Preview before committing; if it reads too grim, swap with the backup.
  - Attribution text: `"Dark Times" Kevin MacLeod (incompetech.com). Licensed under Creative Commons: By Attribution 3.0/4.0 License.` (use the exact text the incompetech page generates).
  - Format/conversion needed: **yes** — `.mp3`.
- **Backup pick:** Ove Melaa — Dark Blue (Orchestral Tune) — **CC-BY 3.0** (license verified) — https://opengameart.org/content/ove-melaa-dark-blue-orchestral-tune
  - Attribution text (author's stated requirement, verbatim form): `"Dark Blue (Orchestral Tune)" written and produced by Ove Melaa (Omsofware@hotmail.com)` — placed in the game's credits.
  - Format/conversion needed: check page.
  - Also considered: Dark Ambient Loop 13 (https://opengameart.org/content/dark-ambient-loop-13) — seamless drone loop, 48 kHz 24-bit WAV, but its license tag could not be confirmed from search snippets (*unconfirmed — check page*).

### mountains.ogg — grand, echoing, brass/horns, sense of scale
- **Primary pick:** Unforgiving Himalayas (Looping) — Matthew Pablo — **CC-BY 3.0** (license verified) — https://opengameart.org/content/unforgiving-himalayas-looping
  - "Soaring above jagged peaks"; explicitly looping.
  - Attribution text: `Music: "Unforgiving Himalayas" by Matthew Pablo — https://matthewpablo.com — CC-BY 3.0` (confirm exact requested wording on page).
  - Format/conversion needed: **no** — file is already `unforgiving_himalayas_looping.ogg`; just rename to `mountains.ogg`.
- **Backup pick:** Five Armies — Kevin MacLeod (incompetech.com) — **CC-BY** (catalog-wide license; *confirm on page*) — search "Five Armies" at https://incompetech.com/music/royalty-free/music.html
  - Grand orchestral brass. Attribution: incompetech standard form as above.
  - Format/conversion needed: **yes** — `.mp3`.

### dungeon.ogg — calm-but-mysterious; must NOT read as threatening (also plays in peaceful towns — see BID-048)
- **Primary pick:** Crystal Cave + Mysterious Ambience (seamless loop) — cynicmusic (Alex Smith) — **CC-BY 3.0** (also offered CC-BY-SA 3.0 / GPL 3.0; use CC-BY 3.0) (license verified) — https://opengameart.org/content/crystal-cave-mysterious-ambience-seamless-loop
  - "Bells, arpeggios, relaxing, enchanting" — mysterious without menace, safe for towns.
  - Attribution text: `Music: "Crystal Cave + Mysterious Ambience" by cynicmusic — cynicmusic.com / pixelsphere.org — CC-BY 3.0` (confirm exact requested wording on page).
  - Format/conversion needed: **no** — file is already `music_jewels.ogg` (2.3 MB, seamless loop); rename to `dungeon.ogg`.
- **Backup pick:** Mysterious Ambience (song21) — cynicmusic — same multi-license family as the combined track (*confirm on page*) — https://opengameart.org/content/mysterious-ambience-song21
  - Piano textures and arpeggios; one half of the primary pick.
  - Format/conversion needed: check page.

### battle.ogg — energetic, rhythmic, Hearthstone-tempo tension (not orchestral bombast)
- **Primary pick:** Battle Theme A — cynicmusic (Alex Smith, for Pixelsphere) — **CC0** (license verified) — https://opengameart.org/content/battle-theme-a
  - Proven, widely-used RPG battle loop; "epic strings and horns", exciting without being a wall of bombast. Preview at Hearthstone-battle tempo expectations; if too cinematic, use the backup.
  - Attribution: none required (CC0). Courtesy credit `cynicmusic.com / pixelsphere.org` in CREDITS.
  - Format/conversion needed: **yes** — file is `battleThemeA.mp3`.
- **Backup pick:** JRPG Epic Rock Battle Theme #1 — **CC0** (license verified; author name on page) — https://opengameart.org/content/jrpg-epic-rock-battle-theme-1
  - Loops seamlessly; downloadable as intro / loop / intro+loop — use the **loop** variant (AudioManager restarts the whole file on `finished`, so an intro would replay every loop).
  - Format/conversion needed: check page (loop variant format).

## Acquisition Instructions (for TID-436)

Sandbox sessions cannot download from these sites (proxy 403) — a human must do this
on their own machine.

1. For each slot, open the **primary pick** URL, confirm the license tag on the page
   matches the license above, and download the audio file. If the license has changed
   or the track doesn't fit after listening, use the backup.
2. Convert any non-`.ogg` file to Ogg Vorbis:
   ```bash
   ffmpeg -i input.mp3 -c:a libvorbis -q:a 5 output.ogg
   ```
   (`-q:a 5` ≈ 160 kbps VBR — good quality at reasonable APK size.)
3. Rename/save to exactly these paths in the repo:
   - `assets/audio/music/grasslands.ogg`
   - `assets/audio/music/forest.ogg`
   - `assets/audio/music/desert.ogg`
   - `assets/audio/music/scorched.ogg`
   - `assets/audio/music/mountains.ogg`
   - `assets/audio/music/dungeon.ogg`
   - `assets/audio/music/battle.ogg`
4. While downloading, copy the **exact attribution text / author name / license / URL**
   from each page (for CC-BY picks the page usually shows the author's requested
   wording) — TID-437 needs it verbatim for the CREDITS file.
5. Loop check: play each file and listen across the end→start seam. If a track has a
   hard intro or trailing silence, trim it (`ffmpeg -ss <start> -to <end> -i in.ogg -c:a libvorbis -q:a 5 out.ogg`)
   so the whole-file restart loop sounds seamless.
6. Commit the 7 `.ogg` files (no `.uid` sidecars needed — audio files take `.import`
   sidecars, generated by the editor/headless import in TID-437).

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| Biome music ×5 | `assets/audio/music/{grasslands,forest,desert,scorched,mountains}.ogg` | Played by `WorldScene` `_BIOME_MUSIC` on biome change |
| Named-map music | `assets/audio/music/dungeon.ogg` | Played on every non-infinite map (towns + dungeons); BID-048 tracks splitting |
| Battle music | `assets/audio/music/battle.ogg` | Played by `BattleScene._ready()` |
| Credits file | repo root (TID-437) | Author, license, source URL per track; verbatim CC-BY attribution |

Integration notes for TID-437:
- `AudioManager.play_music()` uses `ResourceLoader.exists()` + `load(path)` with fixed
  literal paths. Imported `.ogg` resources are packaged in the Android PCK, so dynamic
  `load()` is fine here (the CLAUDE.md Android `preload()` rule targets dynamically
  composed `.tres` paths / `DirAccess` enumeration, which this is not) — but verify
  music actually plays in an Android export as part of integration checks.
- Run the headless import/parse check after adding files and confirm no import errors.
- All 7 tracks loop via `_on_music_finished()` replaying the same stream — no
  `AudioStreamOggVorbis.loop` flag is required, but enabling loop in the import dock
  would also work and survives even if the `finished` handler changes.
