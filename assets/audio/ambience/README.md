# Ambience Directory

`AudioManager.AMBIENCE_PATHS` names one looping bed per biome (indices match
`IsoConst` biome IDs). A missing file falls back to a procedurally synthesized
loop from `game_logic/SfxGen.gd` (`SfxGen.get_ambience(biome_id)`, TID-425) —
a few seconds of shaped noise with `loop_mode = LOOP_FORWARD`. A real file
here always wins over the synthesized fallback.

| Index | File | Biome |
|---|---|---|
| 0 | `grasslands.ogg` | Grasslands |
| 1 | `forest.ogg` | Forest |
| 2 | `desert.ogg` | Desert |
| 3 | `scorched.ogg` | Scorched |
| 4 | `mountains.ogg` | Mountains |


## Weather and time-of-day layers (GID-129 / TID-490)

`game_logic/AmbienceLayers.gd` `LAYER_PATHS` names one optional loop per layer
key; missing files fall back to `game_logic/AmbienceGen.gd`. Seamless loops,
mono or stereo, a few seconds to a minute.

| File | Layer | Plays when |
|---|---|---|
| `rain.ogg` | weather | rain |
| `heavy_rain.ogg` | weather | heavy_rain |
| `wind.ogg` | weather | snow (quiet), dust_devil, blizzard (loud) |
| `sandstorm.ogg` | weather | sandstorm |
| `crackle.ogg` | weather | ash_fall, volcanic |
| `birds.ogg` | time | daytime, grasslands/forest/mountains/outdoor towns, no weather |
| `crickets.ogg` | time | night, grasslands/desert/outdoor towns |
| `owls.ogg` | time | night, forest/mountains |

## Shipped files (GID-145 / TID-616)

Every slot except `owls.ogg` has a real CC0 loop (sources in `CREDITS.md`); owls
still use the `AmbienceGen` synth. The five biome beds are the same wind loop
run through different filters/playback rates (low-passed breeze for
grasslands/forest, bright for desert, rumble for scorched, full for mountains),
rendered from three back-to-back copies with only the middle copy kept, so the
filter tail makes the loop seamless. Every `.ogg.import` here sets `loop=true`;
`test_sfx_assets` fails if one doesn't.
