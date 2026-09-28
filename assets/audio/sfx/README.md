# SFX Directory

AudioManager expects `.ogg` files in this directory, keyed by `AudioManager.SFX_PATHS`.
A missing file is not a silent no-op anymore: `game_logic/SfxGen.gd` procedurally
synthesizes a stand-in sound for every registered key at startup (TID-425), so the
game is never silent even with this directory empty. A real file here always wins
over the synthesized fallback — drop one in and it's used automatically, no code
change needed.

| Key | Trigger |
|---|---|
| `card_draw` | Player draws a card |
| `card_play` | Player plays a card from hand |
| `spell_resolve` | A spell/ability resolves |
| `attack` | A minion attacks |
| `battle_win` | Player wins a battle |
| `battle_lose` | Player loses a battle |
| `enemy_engage` | Enemy spots player and starts battle |
| `enemy_alert` | Enemy engage alert beat / mimic reveal |
| `chest_open` | Player opens a chest |
| `scroll_pickup` | Player picks up a lore scroll |
| `door_enter` | Player enters a door/dungeon |
| `footstep` | Generic footstep (fallback) |
| `footstep_grass` | Step on grass (grasslands, forest, town lawns) |
| `footstep_sand` | Step on sand (desert) |
| `footstep_stone` | Step on stone/paths, scorched rock, mountain slopes, dungeons, temple |
| `footstep_snow` | Step on mountain snowfields |
| `footstep_wood` | Step on wooden floors (home, mansion, guildhall) |
| `footstep_water` | Step through puddles (rain) |
| `footstep_hoof` | Mount hoofbeat on hard ground |
| `nightfall_ambient` | Night falls |
| `ui_click` | Button press feedback |
| `land` | Player lands after a jump |
| `dig_success` | Treasure dig succeeds |
| `waystone_travel` | Waystone fast-travel teleport |
| `thunder` | Storm lightning thunder (heavy rain, volcanic), 0.5–3.5 s after the flash; played pitch-shifted for distance, so a single close, full-bodied crack-and-roll (2–4 s) works best |

Every key now ships a real CC0 file (GID-141 / TID-587; sources in `CREDITS.md`).
Files are mono Ogg Vorbis, peak-normalised to −1 dBFS; the mix trim per key is
`AudioManager.SFX_GAIN_DB` (applied only to file-backed keys, so synth fallbacks
keep their level). Keys in `AudioManager.SFX_TAKES` also ship `<key>_2.ogg` …
`<key>_N.ogg` and play a random take, never the same twice in a row
(TID-588). The source-to-key mapping lives in the TID-587 task file.

Replace any file with another asset when a better one turns up. The Godot editor will
auto-generate `.import` sidecars on first scan.
