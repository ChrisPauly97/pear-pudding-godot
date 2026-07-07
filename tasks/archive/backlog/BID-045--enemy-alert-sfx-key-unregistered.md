# BID-045: `enemy_alert` SFX key played but never registered in AudioManager.SFX_PATHS

**Category:** code-smell
**Discovered During:** GID-114 research (game-feel audit)

## Description

`WorldScene.gd` plays the SFX key `"enemy_alert"` on mimic reveal, but
`AudioManager.SFX_PATHS` has no such key — only `"enemy_engage"` exists. Since
`play_sfx()` silently no-ops on a cache miss, the call can never produce sound
even once audio assets/synthesis exist, unless the key is registered.

## Evidence

- `scenes/world/WorldScene.gd:5035` — `AudioManager.play_sfx("enemy_alert")`
- `autoloads/AudioManager.gd:15-28` — `SFX_PATHS` dictionary; no `enemy_alert`
  entry (nor is the key listed in `assets/audio/sfx/README.md`)

## Suggested Resolution

Register `enemy_alert` (distinct alarm sting, also wanted by the GID-114
engage-beat work) in `SFX_PATHS` / the synth fallback table. Being resolved by
GID-114 / TID-425; if that task is descoped, either register the key or switch
the call site to `enemy_engage`.
