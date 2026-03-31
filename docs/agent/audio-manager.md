# AudioManager

## Key Features

- Global autoload (`AudioManager`) that owns a pool of 8 `AudioStreamPlayer` nodes
- `AudioManager.play_sfx(name: String)` is the sole entry point for all sound effects
- Graceful no-op: if the `.wav` file is missing, the call returns silently — game never crashes due to absent audio assets
- Pool-based: reuses existing nodes, no allocations per sound; if all 8 players are busy the oldest is cut off

## How It Works

```gdscript
AudioManager.play_sfx("card_play")   # plays res://assets/audio/sfx/card_play.wav if it exists
AudioManager.play_sfx("footstep")    # no-op if footstep.wav is missing
```

### SFX Name → File Map

| Name | File |
|---|---|
| `card_play` | `assets/audio/sfx/card_play.wav` |
| `attack` | `assets/audio/sfx/attack.wav` |
| `battle_win` | `assets/audio/sfx/battle_win.wav` |
| `battle_lose` | `assets/audio/sfx/battle_lose.wav` |
| `enemy_engage` | `assets/audio/sfx/enemy_engage.wav` |
| `chest_open` | `assets/audio/sfx/chest_open.wav` |
| `door_enter` | `assets/audio/sfx/door_enter.wav` |
| `footstep` | `assets/audio/sfx/footstep.wav` |

### Adding a New SFX

1. Add an entry to `SFX_PATHS` in `AudioManager.gd`.
2. Place the `.wav` file at the declared path.
3. Open the project in the Godot editor once so it generates the `.import` sidecar.

## Integrations with Other Features

| System | Calls | When |
|---|---|---|
| BattleScene / GameState | `play_sfx("card_play")` | Player plays a card |
| BattleScene / GameState | `play_sfx("attack")` | Minion attacks |
| SceneManager / BattleScene | `play_sfx("battle_win")` | Battle won |
| SceneManager / BattleScene | `play_sfx("battle_lose")` | Battle lost |
| EnemyNPC | `play_sfx("enemy_engage")` | Enemy engages player |
| Chest entity | `play_sfx("chest_open")` | Chest opened |
| Door entity | `play_sfx("door_enter")` | Door entered |
| WorldScene (player move) | `play_sfx("footstep")` | Throttled footstep |

TID-010 wires battle SFX; TID-011 wires world exploration SFX.

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| `AudioManager.gd` | `autoloads/AudioManager.gd` | Autoload; registered in `project.godot` |
| SFX wav files | `assets/audio/sfx/*.wav` | Optional — missing files are silent no-ops; see `assets/audio/sfx/README.md` |
