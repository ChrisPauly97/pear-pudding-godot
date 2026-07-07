# Ambience Placeholder Directory

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

Replace any file with a real audio asset when available. The Godot editor will
auto-generate `.import` sidecars on first scan.
