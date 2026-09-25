# GID-133: Sprite Outlines & Rain Detail

## Objective

Characters read clearly against busy ground; rain visibly hits the world and pools in low spots.

## Context

Raised by the user (2026-09-25): *"outlines pls then rain and splash, puddles in low areas?"*. Sprites are unshaded alpha-cut billboards with no edge; rain (GID-129 / TID-487) only darkens terrain and adds noise puddles, with nothing striking the ground.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-513 | Character Sprite Outlines | agent | done | — |
| TID-514 | Rain Splashes & Ripples | agent | done | — |
| TID-515 | Puddles in Low Areas | agent | done | TID-514 |
| TID-516 | Stylised Screen Transitions | agent | done | — |

## Acceptance Criteria

- [x] Outlines on player, remote players, NPCs, enemies; animation, flip, modulate/fades and rider-over-mount depth still work
- [x] Rain/heavy rain show ground splash rings + droplets around the player, scaled by particle knobs, none on Low
- [x] Puddles collect in dips, reflect the sky, ripple while raining, dry slowly; grass does not poke through them
- [x] Tests, gdlint, unsafe-hits, smoke tests clean; visual check
