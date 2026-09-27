# TID-561: Co-op Avatars Wear Their Gear

**Goal:** GID-137
**Type:** agent
**Status:** pending
**Depends On:** TID-560

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`RemotePlayer._ready()` calls `AvatarSprite.build()` with no gear, so every
remote peer renders in base clothes. Session records already carry
`equipped_weapon/armor/offhand/trinket` (see `SaveManager` session-record
restore, ~line 626).

## Research Notes

- `PaperDoll.gear_of_record(record)` reads a record's `equipped_*` keys.
- Needs: send the peer's gear with the character handshake (CoopSession) and
  on `GameBus.equipment_changed`; RemotePlayer swaps `sprite_frames` +
  `SpriteOutline.refresh()` like `Player._on_equipment_changed`.
- Sync payloads must carry the map discriminator per CLAUDE.md co-op learnings
  only if tied to world objects; gear is per-peer so it can ride the identity path.
