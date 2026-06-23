# GID-090: Co-op Multiplayer Vertical Slice

## Objective

Two players connect over an abstracted ENet transport, both load the named map **madrian**, and each sees the other player's avatar walk around smoothly.

## Context

The game is fully single-player today with zero networking code. The user wants
networked multiplayer; the chosen first deliverable is a **thin vertical slice of
co-op world exploration** that proves the architecture before any larger
investment. Transport is Godot's built-in **ENet now**, deliberately wrapped so
**GodotSteam's `SteamMultiplayerPeer` can be swapped in later** by editing a
single factory method.

The codebase is well-suited to this: a uniform `init_from_data(data)` entity
convention, an imperative `Entities` node in `WorldScene`, registries kept in
dicts (`_enemy_nodes[id]`), and a fixed isometric camera that only the local
player drives. The key design tension is that `SceneManager` detaches/re-attaches
`WorldScene` from the tree during battles, which is why `MultiplayerSpawner`/
`MultiplayerSynchronizer` (which assume stable tree paths + auto-replication) are
**not** used — manual RPC into the existing entity system fits the codebase.

**Explicitly out of scope for this slice:** battles, enemy/NPC/chest/inventory/
save sync, the infinite chunk-streamed world, save merging, reconnection, NAT
traversal, >2 players, and Steam (stubbed behind a reserved enum).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-320 | Pure avatar-sync logic (serialize + interpolate) | agent | done | — |
| TID-321 | NetworkManager autoload (abstracted ENet factory + signals) | agent | done | — |
| TID-322 | RemotePlayer scene/script + shared AvatarSprite helper | agent | done | TID-320 |
| TID-323 | WorldScene coop hooks: NetSync RPC node, spawn/despawn, 15 Hz broadcast | agent | done | TID-321, TID-322 |
| TID-324 | MultiplayerLobbyScene UI + MenuScene entry + SceneManager coop hook | agent | done | TID-321, TID-323 |
| TID-325 | Unit test + headless compile + manual 2-instance verification | agent | done | TID-323, TID-324 |
| TID-327 | LAN game discovery (UDP broadcast) + found-games list in lobby | agent | pending | TID-321, TID-324 |
| TID-326 | Agent doc multiplayer-coop.md + CLAUDE.md doc-table row | agent | pending | TID-325, TID-327 |

## Acceptance Criteria

- [ ] A `NetworkManager` autoload wraps ENet host/join behind one `_create_peer()` factory and re-broadcasts native multiplayer signals; a `Transport { ENET, STEAM }` enum marks the swap seam.
- [ ] A "Co-op (Beta)" entry in MenuScene opens a lobby with IP entry (prefilled `127.0.0.1`), Host / Join / Back, viewport-relative sizing, and works on desktop + mobile.
- [ ] Host starts a session and enters madrian; the joining client is routed to madrian before any avatar data flows.
- [ ] Each connected peer is represented by a `RemotePlayer` avatar in the other client's `Entities` node, spawned on connect and freed on disconnect.
- [ ] Local avatars broadcast position/facing at ~15 Hz; remote avatars interpolate and walk smoothly; `y` is recomputed locally (never synced); the camera follows only the local player.
- [ ] A joining player can discover nearby hosts on the same LAN (UDP broadcast) and tap one to join, with manual IP entry retained as a fallback; the Android receive-side broadcast limitation is handled and documented.
- [ ] `tests/test_coop_sync.gd` passes (AvatarSync encode/decode round-trip + interpolation), `tests/runner.gd` exits 0, and a headless editor import reports no parse/compile errors.
- [ ] `docs/agent/multiplayer-coop.md` documents the system and a row is added to the CLAUDE.md doc table.
