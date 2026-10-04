# Credits & Attribution

Third-party assets used by Pear Pudding TCG, with author, license, and source.

## Music

All seven tracks live at `assets/audio/music/`. Sources and licenses were
verified on-page at download time (2026-07-16, TID-436); see
`docs/agent/audio-soundtrack.md` for the full shortlist and processing notes.

**Four tracks are CC-BY and their attribution below is a licence condition, not
a courtesy.** It must be reproduced in any distributed build — in-game credits,
store listing, or accompanying documentation. Do not remove these lines when
swapping a track; remove the track first.

### Required attribution (CC-BY)

- **"Woodland Fantasy"** by **Matthew Pablo** — https://matthewpablo.com —
  CC BY 3.0. Source: https://opengameart.org/content/woodland-fantasy
  *(used as `forest.ogg`)*
- **"Dark Times"** — Kevin MacLeod (incompetech.com). Licensed under Creative
  Commons: By Attribution 4.0 License. http://creativecommons.org/licenses/by/4.0/
  Source: https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100747
  *(used as `scorched.ogg`)*
- **"UNFORGIVING HIMALAYAS"** by **Eric Matyas** — www.soundimage.org —
  CC BY 3.0. Source: https://opengameart.org/content/unforgiving-himalayas-looping
  *(used as `mountains.ogg`)*
- **"Crystal Cave (Mysterious Ambience)"** by **cynicmusic** —
  https://pixelsphere.org / The Cynic Project — CC BY 3.0 (chosen from the
  source's CC-BY 3.0 / CC-BY-SA 3.0 / GPL 3.0 multi-licence).
  Source: https://opengameart.org/content/crystal-cave-mysterious-ambience-seamless-loop
  *(used as `dungeon.ogg`)*

### CC0 (courtesy credit, not required)

- **"GrassLands Theme"** by **DST** — CC0.
  https://opengameart.org/content/grasslands-theme *(`grasslands.ogg`)*
- **"Desert Theme"** by **Tarush Singhal** — CC0.
  https://opengameart.org/content/desert-theme-0 *(`desert.ogg`)*
- **"Battle Theme A"** by **cynicmusic** (https://pixelsphere.org) — CC0.
  https://opengameart.org/content/battle-theme-a *(`battle.ogg`)*

### Per-slot index

| Slot | File | Track | Author | License |
|---|---|---|---|---|
| Biome: Grasslands | `music/grasslands.ogg` | GrassLands Theme | DST | CC0 |
| Biome: Forest | `music/forest.ogg` | Woodland Fantasy | Matthew Pablo | **CC BY 3.0** |
| Biome: Desert | `music/desert.ogg` | Desert Theme | Tarush Singhal | CC0 |
| Biome: Scorched | `music/scorched.ogg` | Dark Times | Kevin MacLeod | **CC BY 4.0** |
| Biome: Mountains | `music/mountains.ogg` | Unforgiving Himalayas | Eric Matyas | **CC BY 3.0** |
| Dungeons / spire | `music/dungeon.ogg` | Crystal Cave | cynicmusic | **CC BY 3.0** |
| Battle | `music/battle.ogg` | Battle Theme A | cynicmusic | CC0 |

Named towns and story maps use `grasslands.ogg` as their peaceful default via
`MapData.music_track` (GID-125 / TID-470); only procedurally generated dungeons
and spire floors fall through to `dungeon.ogg`.

## Sound Effects & Ambience (GID-145)

All CC0 (Creative Commons Zero): no attribution required, credited with thanks.
Files were trimmed, converted to mono Ogg Vorbis and peak-normalised with ffmpeg.

- **Kenney** (kenney.nl): *Casino Audio* (card draw/play), *Impact Sounds*
  (footsteps grass/stone/snow/wood, attack, land, dig), *RPG Audio* (generic
  footsteps, chest latch + creak, book flips, doors), *Interface Sounds* (UI click),
  *Music Jingles* (battle win/lose, nightfall stingers). https://kenney.nl/assets
- **"80 CC0 RPG SFX"** by **rubberduck**: enemy roar/alert, coin shower on a dig.
  https://opengameart.org/content/80-cc0-rpg-sfx
- **"100 CC0 SFX #2"** by **rubberduck**: thunder, wet footsteps.
  https://opengameart.org/content/100-cc0-sfx-2
- **"Magic Spell SFX"** by **JaggedStone**: spell resolve, waystone travel. https://opengameart.org/content/magic-spell-sfx
- **"Horse Trotting"** by **EZduzziteh**: mount hoofbeats. https://opengameart.org/content/horse-trotting
- **"Water Splash and sand footsteps"** by **Peludo**: sand footsteps.
  https://opengameart.org/content/water-splash-and-sand-footsteps
- **"Rain (loopable)"** by **Ylmir**: rain and heavy-rain layers. https://opengameart.org/content/rain-loopable
- **"wind whoosh loop"** by **SketchMan3**: wind/sandstorm layers and all five filtered biome beds.
  https://opengameart.org/content/wind-whoosh-loop
- **"Fire Crackling"** by **AntumDeluge**: ash/volcanic crackle layer. https://opengameart.org/content/fire-crackling
- **"Ambient Bird Sounds"** by **isaiah658**: daytime birds layer.
  https://opengameart.org/content/ambient-bird-sounds
- **"Crickets Ambient Noise - loopable"** by **Wolfgang_**: night crickets layer.
  https://opengameart.org/content/crickets-ambient-noise-loopable

Public Domain Mark 1.0 field recordings from **radio aporee ::: maps** (via the Internet Archive): no rights
reserved, credited with thanks. Trimmed to a quiet-edged window, crossfaded into a seamless loop, mixed to mono,
halved to 24 kHz and peak-normalised (GID-152 backlog, BID-073 / BID-083).

- **"The babbling of a brook, uncovered"** (Schleiden, Germany) by **Matthes**: stream layer (`stream.ogg`, 56–92 s).
  https://archive.org/details/aporee_21934_25484
- **"A lone tawny owl calls nearby…"** (Chediston, Suffolk) by **Peter Cusack**: night owl layer (`owls.ogg`,
  45–99 s). https://archive.org/details/aporee_68716_81482

### Siege music

- **"Epic Boss Battle [Seamlessly Looping]"** by **Juhani Junkala** (uploaded by SubspaceAudio): CC0.
  Loudness-matched to `battle.ogg`. https://opengameart.org/content/boss-battle-music
  *(used as `assets/audio/music/siege.ogg`)*

## Art / Sprites

### 0x72 — 16x16 DungeonTileset II (v1.7)

- **Source:** https://0x72.itch.io/dungeontileset-ii
- **License:** CC0-1.0 (Creative Commons Zero v1.0 Universal) — no attribution required; credited with thanks.
- **Used for:** nothing any more — every character, chest, door and card that came from this pack is generated in-house (GID-143/144). Credited for the history of the project.

### Kenney — Tiny Town (1.1) & Tiny Dungeon (1.0)

- **Source:** https://kenney.nl/assets/tiny-town , https://kenney.nl/assets/tiny-dungeon
- **License:** CC0 (Creative Commons Zero) — no attribution required; credited with thanks.
- **Used for:** nothing any more — terrain, props, the spectre and the ghost card are generated in-house (GID-144). Credited for the history of the project.

### Clint Bellanger — Tiny Creatures (1.0)

- **Source:** https://opengameart.org/content/tiny-creatures
- **License:** CC0 (Creative Commons Zero). Attribution not mandatory; the author asks for a credit — thank you, **Clint Bellanger** (clintbellanger.net).
- **Used for:** nothing any more — the horse and props are generated in-house (GID-144). Credited for the history of the project.

## Per-Slot Index

All sprites listed above are integrated in-engine as of GID-118 (TID-446 wired
characters/enemies/NPCs; TID-447 wired props/mount/card art). `TextureGen`
remains as a runtime fallback wherever a slot's texture is missing.

| Slot | File | Source |
|---|---|---|
| Enemy: undead / undead (horde) | `characters/enemy_{skeleton,zombie}.png` | Original — generated by `tools/generate_characters.py` (GID-143) |
| NPC: named quest givers / trainers ×9 | `characters/npc_<name>.png` | Original — generated by `tools/generate_characters.py` (GID-143) |
| Enemy: undead elite, ghoul, raider (+ScoutAmbush), warleader, duelist, rival, terror (+roaming boss), spectre; NPC: townsperson ×3, merchant (+traveling), Maiteln (+walk) | `characters/enemy_*.png`, `characters/npc_*.png` | Original — generated by `tools/generate_characters.py` (GID-144 / TID-610) |
| Enemy: mimic | `characters/enemy_mimic.png` | Original — `tools/generate_sprites.py` (chest, door) / `tools/generate_characters.py` (mimic, horse) — GID-144 / TID-612 |
| Mount | `characters/mount_horse.png` | Original — `tools/generate_sprites.py` (chest, door) / `tools/generate_characters.py` (mimic, horse) — GID-144 / TID-612 |
| Props: rock, boulder, ash_pile, ember, mushroom, flower, fern, cactus, thorn, lichen (3-5 variants each); waystone dormant/active, mana well, puzzle shrine, burial mound, blight heart | `props/prop_<key>_<n>.png`, `props/{waystone_*,mana_well,puzzle_shrine,burial_mound,blight_heart}.png` | Original — generated by `tools/generate_sprites.py` on the 0x72 pack palette (replaced the Tiny Creatures / Kenney / Danaida / 0x72-recolour sprites) |
| Card: ghost / skeleton / zombie / ghoul; rune: dawn / dusk / ember / ash | `cards/card_*.png`, `cards/rune_*.png` | Original — generated by `tools/generate_cards.py` (GID-144 / TID-611; replaced 0x72 / Kenney portraits and the CC BY game-icons.net runes) |
| Terrain: grass, hill top/side, wall side/top, path | `pixel_art/{grass,hill_top,hill_side,wall_side,wall_top,path}_pixel.png` | Original — generated by `tools/generate_hd_terrain.py` (128×128, replaced the Kenney / 0x72 16×16 tiles); grass tuft atlas `pixel_art/grass_tufts.png` likewise original |
| Town roofs + gables | `pixel_art/{roof_clay,roof_slate,roof_thatch,roof_shingle,roof_moss,gable}_pixel.png` | Original — generated by `tools/generate_roof_textures.py` (128×128, GID-154) |
| Chest: closed / open | `props/chest_{closed,open}.png` | Original — `tools/generate_sprites.py` (chest, door) / `tools/generate_characters.py` (mimic, horse) — GID-144 / TID-612 |
| Door (all map-transition doors) | `props/door.png` | Original — `tools/generate_sprites.py` (chest, door) / `tools/generate_characters.py` (mimic, horse) — GID-144 / TID-612 |
| Graveyard: headstones ×3, iron fence, crypt door | `props/{headstone_0..2,iron_fence,crypt_door}.png` | Original — `tools/generate_sprites.py` (GID-143) |
| Main menu key art | `ui/menu_keyart.jpg` | Original — in-engine capture (`tools/capture_menu_keyart.gd`, GID-143) |

## Fonts

Both under the SIL Open Font License 1.1 (licence texts in `assets/fonts/`).
Latin subsets from the Fontsource npm packages (GID-132 / TID-509).

- **Nunito** Bold — The Nunito Project Authors — https://github.com/googlefonts/nunito
  *(body text and buttons, `assets/fonts/Nunito-Bold.woff2`; licence `OFL-Nunito.txt`)*
- **Cinzel** Bold — The Cinzel Project Authors — https://github.com/NDISCOVER/Cinzel
  *(titles, `assets/fonts/Cinzel-Bold.woff2`; licence `OFL-Cinzel.txt`)*

## Icons

HUD action icons (`assets/icons/hud/`) are original, written by `tools/generate_hud_icons.py`
(GID-144 / TID-613; they replaced the CC BY 3.0 game-icons.net set).
