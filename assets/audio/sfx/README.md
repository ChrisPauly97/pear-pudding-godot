# SFX Placeholder Directory

AudioManager expects the following `.wav` files in this directory.
Missing files are a silent no-op — the game will not crash without them.

| File | Trigger |
|---|---|
| `card_play.wav` | Player plays a card from hand |
| `attack.wav` | A minion attacks |
| `battle_win.wav` | Player wins a battle |
| `battle_lose.wav` | Player loses a battle |
| `enemy_engage.wav` | Enemy spots player and starts battle |
| `chest_open.wav` | Player opens a chest |
| `door_enter.wav` | Player enters a door/dungeon |
| `footstep.wav` | Player footstep (throttled) |

Replace each file with a real audio asset when available.
The Godot editor will auto-generate `.import` sidecars on first scan.
