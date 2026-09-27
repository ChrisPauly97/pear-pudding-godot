# TID-561: Co-op Avatars Wear Their Gear

**Goal:** GID-137
**Type:** agent
**Status:** done
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

## Plan

New `CoopAppearance` module (CoopSession is flagged as lint debt — only
two hook lines added there) owning a `recv_gear` RPC; gear rides the identity
handshake and every `equipment_changed`; receivers store per peer and dress
the avatar on arrival or spawn.

## Changes Made

- `scenes/world/coop/CoopAppearance.gd` (new), registered in
  `WorldScene._ensure_coop_modules()` as `coop_appearance`.
- `NetSync.recv_gear` → `_on_gear_received`.
- `CoopSession`: send gear with identity; apply gear after avatar spawn.
- `RemotePlayer.set_gear()`; `AvatarSprite.build(_gear)` on ready.
- `PaperDoll.encode_gear/decode_gear` (sanitising decode).
- `SaveManager.adopt_session_character` emits `equipment_changed("", "")`
  (also fixes the local hero not redrawing after adopting a session character).
- Tests: payload round-trip + junk rejection; `net_coop_smoke` ENet round-trip.

## Documentation Updates

- `docs/agent/multiplayer-coop.md` "Avatar gear sync"; CLAUDE.md coop module table.
