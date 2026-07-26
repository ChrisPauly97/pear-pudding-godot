# AudioManager

## Key Features

- Global autoload (`AudioManager`) that owns a pool of 8 `AudioStreamPlayer` nodes for SFX
- `AudioManager.play_sfx(name: String)` is the sole entry point for all short sound effects
- Graceful no-op: if the `.wav`/`.ogg` file is missing, the call returns silently — game never crashes due to absent audio assets
- Pool-based: reuses existing nodes, no allocations per sound; if all 8 players are busy the oldest is cut off
- Dedicated `_narration_player` for long-form lore scroll narration (separate from pool, −3 dB)
- Narration auto-suppressed while NPC dialogue is active via `GameBus.dialogue_state_changed`

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

### Music Channel

A dedicated `_music_player: AudioStreamPlayer` (default volume 0.5 linear),
separate from the SFX pool, auto-looping via its `finished` signal:

```gdscript
AudioManager.play_music(path: String) -> void   # no-op if already playing that path
AudioManager.stop_music() -> void
AudioManager.set_music_volume(linear: float) -> void
AudioManager.get_music_volume() -> float
```

`play_music()` is idempotent for the currently playing track, so callers can
re-issue it on every scene entry without restarting the music.

All 7 tracks shipped in GID-116 / TID-436 and are present at
`assets/audio/music/`. **Four are CC-BY and carry mandatory attribution** —
see `CREDITS.md` ("Music"), which is the authoritative attribution record;
`docs/agent/audio-soundtrack.md` holds the shortlist and processing notes.

| Slot | File | Chosen by |
|---|---|---|
| Grasslands / named towns | `music/grasslands.ogg` | `_BIOME_MUSIC[0]`, and the named-map default |
| Forest | `music/forest.ogg` | `_BIOME_MUSIC[1]` |
| Desert | `music/desert.ogg` | `_BIOME_MUSIC[2]` |
| Scorched | `music/scorched.ogg` | `_BIOME_MUSIC[3]` |
| Mountains | `music/mountains.ogg` | `_BIOME_MUSIC[4]` |
| Dungeons / spire floors | `music/dungeon.ogg` | `WorldScene._named_map_music_track()` fallback |
| Battle | `music/battle.ogg` | `BattleScene._ready()` |

Named-map selection is data-driven (GID-124 / TID-467): `MapData.music_track`
wins if set, else `dungeon.ogg` for `dungeon_*` / `spire_floor_*`, else the
peaceful default. Giving a town its own track is a one-line `.tres` change —
add the file, set `music_track`, and add its row to `CREDITS.md`.

### Narration Channel

A dedicated `_narration_player: AudioStreamPlayer` (volume −3 dB) plays long-form scroll narration without competing with the SFX pool:

```gdscript
AudioManager.play_narration(scroll_id: String) -> void   # resolves path via ScrollRegistry
AudioManager.stop_narration() -> void
AudioManager.is_narration_playing() -> bool
AudioManager.set_narration_suppressed(suppressed: bool) -> void
```

`AudioManager` connects to `GameBus.dialogue_state_changed` in `_ready()`. While NPC dialogue is showing, `_narration_suppressed = true` and any playing narration is stopped. Narration can be replayed from the Journal overlay.

Narration audio files: `assets/audio/narration/<scroll_id>.ogg` — all are optional (graceful no-op if absent).

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
| StoryScroll entity | `play_sfx("scroll_pickup")` | Scroll collected |
| StoryScroll entity | `play_narration(scroll_id)` | After scroll collected |
| JournalScene | `play_narration(scroll_id)` | Replay button pressed |

TID-010 wires battle SFX; TID-011 wires world exploration SFX.

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| `AudioManager.gd` | `autoloads/AudioManager.gd` | Autoload; registered in `project.godot` |
| SFX wav files | `assets/audio/sfx/*.wav` | Optional — missing files are silent no-ops |
| Music ogg files | `assets/audio/music/*.ogg` | **Present** (7 tracks, GID-116). 4 are CC-BY — attribution in `CREDITS.md` is a licence condition |
| Narration ogg files | `assets/audio/narration/<scroll_id>.ogg` | Optional — missing files are silent no-ops |
