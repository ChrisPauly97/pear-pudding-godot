# GID-151: Card Visual Overhaul

## Objective

Make cards look like real TCG cards: framed faces, branch backgrounds, a card back, motion, and full illustration coverage.

## Context

User (2026-09-30) asked for card backgrounds, art, card backs and card-play animations. Cards are flat coloured
StyleBoxFlat panels with a small art strip; the enemy hand is a plain box; only 4 minions and 4 spell branches have
illustrations. Order: frames/backs/backgrounds → animations → illustrations.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-631 | Card frame art generator | agent | done | — |
| TID-632 | Shared card-face builder + bigger art window | agent | done | TID-631 |
| TID-633 | Per-branch card backgrounds | agent | pending | TID-632 |
| TID-634 | Designed card back shared everywhere | agent | pending | TID-632 |
| TID-635 | Draw animation (deck → hand + flip) | agent | pending | TID-634 |
| TID-636 | Hover lift/tilt/glow + playable pulse | agent | pending | TID-632 |
| TID-637 | Play arc + landing burst; enemy flip-reveal | agent | pending | TID-634 |
| TID-638 | Dissolve shader: spell cast + card death | agent | pending | TID-632 |
| TID-639 | Spell runes for bloom/thorn/flux/fracture | agent | pending | — |
| TID-640 | Creature illustrations for all minions/legendaries | agent | pending | TID-632 |
| TID-641 | Rarity frame treatments | agent | pending | TID-632 |

## Acceptance Criteria

- [ ] Every card face (battle, backpack, inspect, pack opening) uses one framed builder
- [ ] Every magic type has a frame, every branch a background, and there is one shared card back
- [ ] Draw, play, spell-cast, death and enemy-play animations run without slowing real-time mode
- [ ] Every card resolves to generated art (no TextureGen fallback)
- [ ] Full suite, smoke tests, gdlint and unsafe-hits clean
