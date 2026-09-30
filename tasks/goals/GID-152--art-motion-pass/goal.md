# GID-152: Art Motion Pass

## Objective

Make the world move: flowing streams, animated enemies/NPCs/mount, swaying plants, living landmarks and props.

## Context

All sprites are in-house (GID-143/144) but nearly everything is a single static frame. Stream ripples drift in one
fixed direction regardless of the stream's course. See `docs/agent/art-sprites.md` and `docs/agent/visual-polish.md`.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-642](TID-642--stream-flow.md) | Stream flow direction | agent | done | — |
| [TID-643](TID-643--stream-foam-banks.md) | Stream foam and bank dressing | agent | done | TID-642 |
| [TID-644](TID-644--stream-ambience.md) | Stream water ambience loop | agent | pending | — |
| [TID-645](TID-645--enemy-walk-cycles.md) | Enemy walk cycles | agent | done | — |
| [TID-646](TID-646--enemy-combat-frames.md) | Enemy attack, hit and death frames | agent | pending | TID-645 |
| [TID-647](TID-647--plant-wind-sway.md) | Tree and plant wind sway | agent | done | — |
| [TID-648](TID-648--landmark-idle-loops.md) | Landmark idle loops | agent | done | — |
| [TID-649](TID-649--campfire-flames.md) | Campfire flame frames | agent | done | — |
| [TID-650](TID-650--npc-idle-loops.md) | NPC idle loops | agent | done | — |
| [TID-651](TID-651--horse-trot.md) | Horse trot cycle | agent | done | — |
| [TID-652](TID-652--chest-door-frames.md) | Chest and door opening frames | agent | pending | — |

## Acceptance Criteria

- [ ] Stream ripples visibly flow along each stream, faster in narrows, seamless across chunks
- [ ] Foam/bank dressing on streams and ponds; water ambience near streams
- [ ] Enemies animate walking, attacking, taking hits and dying
- [ ] Trees and plants sway with weather wind
- [ ] Landmarks, campfires, NPCs, horse, chests and doors animate
- [ ] Tests, gdlint, unsafe-hits and headless import clean
