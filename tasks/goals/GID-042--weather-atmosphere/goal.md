# GID-042: Weather & Biome Atmosphere

## Objective

Per-biome weather — rain, sandstorm, ash-fall, snow — with particle visuals, screen tint, grass-shader wind, and battle modifiers, driven by a WeatherManager autoload.

## Context

The world has a day/night cycle but the sky never does anything. Weather reuses the existing `wind_direction` grass shader uniform and the day/night tint pipeline. Battle modifiers make weather mechanical, not just cosmetic.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-161 | WeatherManager autoload + per-biome weather tables + save persistence | agent | pending | — |
| TID-162 | Visual effects: GPUParticles3D precipitation, screen tint, grass wind hookup | agent | pending | TID-161 |
| TID-163 | Weather battle modifiers + battle HUD banner | agent | pending | TID-161 |

## Acceptance Criteria

- [ ] WeatherManager picks weather per biome on randomized intervals; current weather + remaining duration persist in SaveManager (with migration) so they survive restarts
- [ ] Each biome has a weighted weather table (grasslands/forest: rain; desert: sandstorm; scorched: ash-fall; mountains: snow; all biomes mostly clear)
- [ ] Active weather shows a GPUParticles3D effect that follows the player, a subtle screen tint layered with the day/night tint, and drives the grass wind_direction uniform
- [ ] Weather only runs in the infinite world — named maps and dungeons are always clear
- [ ] A battle started during weather applies that weather's modifier (e.g. rain: friendly Ghosts +1 health) and shows a banner in the battle HUD
- [ ] All tests pass headless
