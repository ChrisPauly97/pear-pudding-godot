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

Named-map selection is data-driven (GID-125 / TID-470): `MapData.music_track`
wins if set, else `dungeon.ogg` for `dungeon_*` / `spire_floor_*`, else the
peaceful default. Giving a town its own track is a one-line `.tres` change —
add the file, set `music_track`, and add its row to `CREDITS.md`.

### Layered Ambience (GID-129 / TID-490)

Three looping layers play at once, each a crossfading `AudioStreamPlayer` pair
(`AmbLayer`: key, gain, per-player volume tween; `AMBIENCE_CROSSFADE` 2 s).
Every layer's volume is `SFX volume × layer gain`, and `set_sfx_volume()`
retargets all three live.

| Layer | Gain | Driven by | Keys |
|---|---|---|---|
| Biome | `BIOME_LAYER_GAIN` 0.4 | `set_ambience(biome_id)` (WorldScene) | `AMBIENCE_PATHS[biome]` / `SfxGen.get_ambience` |
| Weather | `WEATHER_LAYER_GAIN` 0.5 × per-weather gain | `GameBus.weather_changed`; resumed from `WeatherManager.current_weather` whenever biome ambience starts | `rain`, `heavy_rain`, `wind`, `sandstorm`, `crackle` |
| Time of day | `TIME_LAYER_GAIN` 0.3 | `AudioManager.set_time_of_day(t)`, one hook line in `WorldScene._process` after `_dnc.tick` | `birds`, `crickets`, `owls` |

All choices are pure functions in `game_logic/AmbienceLayers.gd` (unit-tested
in `test_ambience_layers`):

- `weather_layer(id)` / `weather_gain(id)`: rain→`rain` 0.8, heavy_rain→`heavy_rain`,
  sandstorm→`sandstorm`, dust_devil→`wind` 0.7, snow→`wind` 0.45, blizzard→`wind` 1.0,
  ash_fall→`crackle` 0.6, volcanic→`crackle` 1.0. Snow → blizzard keeps the same loop and
  only retargets the volume.
- `next_is_day(t, was_day)`: sun height `sin((t − 0.25)·TAU)` with a ±0.08 hysteresis
  band, so dusk/dawn never flap.
- `time_layer(biome, is_day, weather_key)`: grasslands birds/crickets, forest and
  mountains birds/owls, desert silent/crickets, scorched silent. Birds hush while any
  weather layer plays.
- `named_map_is_outdoors(map)`: dungeons (`dungeon_*`), spire floors and the interiors
  (`blancogov_temple`, `farsyth_mansion`, `guildhall`, `player_home`) are indoors.
  Named maps always mute the weather layer (WeatherManager only runs on `main`);
  outdoor towns keep the grassland day/night layer (`NAMED_MAP_TIME_BIOME`), indoors
  mutes it. AudioManager learns the map from `GameBus.entered_named_map`.

Layer changes are applied from `_process` via a dirty flag, and **held while
`SceneManager.current_state()` is `BATTLE`**: a weather roll during a fight
lands when the player is back in the world. Only the music changes in battle.

Missing files fall back to procedural loops in `game_logic/AmbienceGen.gd`
(`get_layer(key)`, cached; built from SfxGen primitives with an in-place,
wrap-around overlay mixer so transients near the loop point stay seamless).
Real files go at `AmbienceLayers.LAYER_PATHS` (`assets/audio/ambience/<key>.ogg`).

### Music Ducking (GID-129 / TID-490)

The music player's volume is `_music_linear × _duck`. `_update_duck()` tweens
`_duck` to `AmbienceLayers.music_duck(dialogue_active, narration_playing)`
(dialogue 0.35, narration 0.4, else 1.0) — down in 0.4 s, up in 1.0 s. It runs on
`GameBus.dialogue_state_changed`, `play_narration`, `stop_narration` and the
narration player's `finished`. `get_music_volume()` returns the user setting,
never the ducked value, so the Settings slider and save are unaffected.

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
| WeatherManager | `GameBus.weather_changed` → weather layer | Weather roll |
| WorldScene `_process` | `set_time_of_day(t)` | Every frame (cheap; hysteresis-filtered) |
| WorldScene | `GameBus.entered_named_map` → indoor/outdoor time layer | Named-map entry |

TID-010 wires battle SFX; TID-011 wires world exploration SFX.

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| `AudioManager.gd` | `autoloads/AudioManager.gd` | Autoload; registered in `project.godot` |
| `AmbienceLayers.gd` | `game_logic/AmbienceLayers.gd` | Pure layer-selection rules + `LAYER_PATHS` |
| `AmbienceGen.gd` | `game_logic/AmbienceGen.gd` | Procedural weather/wildlife loop fallbacks |
| Weather/time loops | `assets/audio/ambience/{rain,heavy_rain,wind,sandstorm,crackle,birds,crickets,owls}.ogg` | Optional — synthesized fallback when absent (TID-492 sources real ones) |
| SFX wav files | `assets/audio/sfx/*.wav` | Optional — missing files are silent no-ops |
| Music ogg files | `assets/audio/music/*.ogg` | **Present** (7 tracks, GID-116). 4 are CC-BY — attribution in `CREDITS.md` is a licence condition |
| Narration ogg files | `assets/audio/narration/<scroll_id>.ogg` | Optional — missing files are silent no-ops |
