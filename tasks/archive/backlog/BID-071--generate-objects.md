# BID-071: Replace third-party chest, door, mimic and horse

**Category:** design-inconsistency
**Discovered During:** GID-143 / TID-607

## Description

Chest, door and mimic are 0x72; the horse is Tiny Creatures.

## Evidence

`docs/agent/art-sprites.md` → "Third-party art inventory & generation roadmap", batch B3.

## Suggested Resolution

Chest/door frames in generate_sprites.py, mimic from the generated chest, a quadruped rig for the horse.
