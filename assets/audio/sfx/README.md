# SFX Placeholder Directory

AudioManager expects `.wav` files in this directory, keyed by `AudioManager.SFX_PATHS`.
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
| `footstep` | Player footstep (synced to walk animation) |
| `nightfall_ambient` | Night falls |
| `ui_click` | Button press feedback |
| `land` | Player lands after a jump |
| `dig_success` | Treasure dig succeeds |
| `waystone_travel` | Waystone fast-travel teleport |

Replace any file with a real audio asset when available. The Godot editor will
auto-generate `.import` sidecars on first scan.
