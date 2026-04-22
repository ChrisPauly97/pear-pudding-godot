# GID-023: Game Feel Polish

## Objective

Add floating damage numbers, hit flash, screen shake, battle sound effects, and background music hooks so battles have the minimum visual and audio feedback players expect.

## Context

The battle system works correctly but feels inert — attacks and spells have no visceral feedback. Industry standard for TCG games includes floating numbers, hit reactions, and audio cues. AudioManager hooks exist but battle SFX and music are absent. This goal addresses all five feedback layers.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-077 | Floating damage and heal numbers | agent | done | — |
| TID-078 | Hit flash on minions and heroes | agent | done | — |
| TID-079 | Screen shake on heavy hits and death | agent | done | — |
| TID-080 | Battle sound effects | agent | done | — |
| TID-081 | Background music loop integration | agent | pending | — |

## Acceptance Criteria

- [ ] Damage and healing amounts appear as floating labels that animate upward and fade
- [ ] Minions and heroes flash briefly when taking damage
- [ ] Camera shakes on hits of 5+ damage and on hero death
- [ ] Card draw, card play, attack, and win/loss sounds play through AudioManager
- [ ] AudioManager.play_music() is called on world entry per biome; graceful no-op if file absent
- [ ] All tests pass headless
