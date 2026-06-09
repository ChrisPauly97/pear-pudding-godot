# GID-055: Night Hunts

## Objective

Spectral enemy variants that only roam the infinite world at night, dropping better loot, with clear visual/audio cues — making the day/night cycle mechanical instead of cosmetic.

## Context

Day/night currently changes only the lighting. Night-only spectres with boosted drops create a risk/reward choice — push on in the dark or wait for dawn — and complement GID-042's weather without overlapping it (weather is biome-keyed, this is time-keyed).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-200 | Nocturnal spawn layer: spectral variants spawn at night in the infinite world, fade at dawn | agent | pending | — |
| TID-201 | Spectral enemy data: decks, boosted rarity drops, distinct visual treatment | agent | pending | — |
| TID-202 | Night-hunt feedback: minimap distinction, ambient audio cue, tutorial popup | agent | pending | TID-200, TID-201 |

## Acceptance Criteria

- A night window is defined from the existing `time_of_day` value (reusing thresholds from **WorldScene.gd** line 963–964: `sun_h < 0` occurring when `time_of_day < 0.25` or `> 0.75`); during it, spectral enemies spawn around the player in loaded chunks at a bounded density, and at dawn all of them fade out and despawn
- Spawning happens only in the infinite world (not named maps or dungeons) and respects a per-area cap so nights don't overwhelm
- Three spectral `EnemyData` variants exist with night-themed decks and a distinct translucent/glowing look; defeating one rolls card drops at a boosted rarity tier and slightly higher coins
- Spectres appear differently on the minimap than normal enemies; nightfall plays an ambient cue and shows a one-time tutorial popup explaining night hunts
- Spectres use the existing wander/track/engage AI unchanged; defeated spectres do not enter `defeated_enemies` (they're transient)
- All tests pass headless
