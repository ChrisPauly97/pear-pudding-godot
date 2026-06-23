# TID-326: Agent doc multiplayer-coop.md + CLAUDE.md doc-table row

**Goal:** GID-090
**Type:** agent
**Status:** done
**Depends On:** TID-325, TID-327

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Document the co-op multiplayer system so future work (Steam transport, battle
sync, enemy/chest sync) can build on it without re-deriving the architecture, and
register it in the project's documentation index.

## Research Notes

**Agent docs convention:** each feature gets a `docs/agent/<feature>.md` covering
**Key Features**, **How It Works**, **Integrations with Other Features**, and
**Asset Requirements** (see existing docs like `docs/agent/tap-to-move.md`,
`docs/agent/rideable-mounts.md` for tone/length). Create
`docs/agent/multiplayer-coop.md`.

**What to document:**
- Architecture: `NetworkManager` transport wrapper (the `_create_peer()` /
  `Transport` enum seam and exactly what to change to add Steam), the signals it
  re-broadcasts.
- Remote avatars: `RemotePlayer` (display-only, no physics/camera), `AvatarSprite`
  helper, the `_remote_player_nodes` registry, spawn/despawn lifecycle.
- Sync protocol: payload `[x, z, flip_h, moving]`, 15 Hz, `unreliable_ordered`,
  the fixed-name `NetSync` child node and why the RPC path must match on both
  peers, Y recomputed locally.
- Pure logic: `game_logic/net/AvatarSync.gd` encode/decode/interp.
- Flow: lobby UI → host/join → both into madrian → broadcasts begin.
- LAN discovery (TID-327): UDP-broadcast scan on the discovery port, the
  found-games list, why it's ENet-only (Steam matchmaking replaces it), and the
  Android receive-side broadcast/multicast-lock workaround that was chosen.
- **Out of scope / known limitations:** loopback/LAN only (no NAT traversal),
  battles/enemies/chests/inventory/save not synced, infinite chunk world not
  supported, 2 players max, no reconnection, Steam stubbed. Be explicit so the
  next person knows the slice's boundaries.

**CLAUDE.md doc table:** add a row to the table under "Documentation: docs/agent/
Directory" in `/home/user/pear-pudding-godot/CLAUDE.md`, e.g.
`| [docs/agent/multiplayer-coop.md](docs/agent/multiplayer-coop.md) | Co-op
multiplayer: NetworkManager transport abstraction, RemotePlayer avatars, NetSync
RPC, lobby |`.

**Ownership:** `docs/agent/` is agent-owned — edit freely. `docs/human/` is
human-owned — never edit. CLAUDE.md edits here are limited to the doc-index table
row.

## Plan

1. Create `docs/agent/multiplayer-coop.md` matching the house structure (Key
   Features / How It Works / Integrations / Asset Requirements / Tests), covering:
   NetworkManager transport seam + signals, RemotePlayer + AvatarSprite, NetSync
   RPC + 15 Hz sync, AvatarSync pure logic, lobby + enter_map_coop flow, LAN
   discovery protocol + the Android receive-side limitation and chosen model, and
   an explicit Out-of-Scope/Limitations section.
2. Add a doc-table row to CLAUDE.md after the app-diagnostics row.
3. Mark goal/index complete (8/8).

## Changes Made

- Created `docs/agent/multiplayer-coop.md` — full system doc (Key Features / How
  It Works / Integrations / Asset Requirements / Tests / Limitations): the
  NetworkManager transport seam + signals, AvatarSync pure logic, RemotePlayer +
  AvatarSprite, NetSync RPC + 15 Hz sync + RPC-path requirement, lobby +
  enter_map_coop flow, the LAN discovery protocol with the rationale for the
  client-broadcasts/host-replies-unicast model and the Android MulticastLock
  limitation, and an explicit Out-of-Scope section.
- Added the doc-table row to `CLAUDE.md` after the app-diagnostics entry.

## Documentation Updates

- New `docs/agent/multiplayer-coop.md`; CLAUDE.md doc index updated. This is the
  agent-doc deliverable for the whole GID-090 slice.
