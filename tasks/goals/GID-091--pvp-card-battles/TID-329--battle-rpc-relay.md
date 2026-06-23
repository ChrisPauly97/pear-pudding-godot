# TID-329: Battle RPC relay node + host-authority scaffolding

**Goal:** GID-091
**Type:** agent
**Status:** done
**Depends On:** TID-328

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Provides the networking transport for PvP battles: a fixed-name RPC relay node
under BattleScene (the battle-layer analogue of `scenes/world/NetSync.gd`) plus the
host-authority helpers that decide which peer simulates. No game logic yet — this
task is the plumbing that TID-330 wires the BattleScene perspective/input onto.

## Research Notes

**Why a fixed-name child node (not an autoload, not MultiplayerSpawner).**
GID-090's `NetSync` lives as a child named exactly `NetSync` under `WorldScene`
because Godot RPC requires the **same node path on both peers**
(`/root/WorldScene/NetSync`). Replicate this for battles. BattleScene is
instantiated by `SceneManager._start_battle()` and promoted to `current_scene`;
confirm the BattleScene **root node name is stable and identical on both peers**
(check `BattleScene.tscn` root name + how SceneManager swaps it — it uses property
sets then promotes to current_scene). The relay must resolve to e.g.
`/root/BattleScene/BattleNetSync` on both sides. If the root name isn't guaranteed
identical, set it explicitly when entering PvP (TID-331 controls instantiation).

**Relay script:** `scenes/battle/BattleNetSync.gd` — a `Node` with a
`battle_scene` back-reference (set by BattleScene), carrying **reliable** RPCs
(turn-based, must not drop — unlike avatar sync which was `unreliable_ordered`):

```gdscript
@rpc("any_peer", "reliable", "call_remote")
func send_intent(payload: Dictionary) -> void:
    var sender: int = multiplayer.get_remote_sender_id()
    if battle_scene != null and battle_scene.has_method("_on_pvp_intent"):
        battle_scene._on_pvp_intent(sender, payload)

@rpc("any_peer", "reliable", "call_remote")
func sync_state(payload: Dictionary) -> void:
    # host -> client full-state mirror (BattleNetProtocol.decode_state)
    ...battle_scene._on_pvp_state(payload)

@rpc("any_peer", "reliable", "call_remote")
func pvp_ended(payload: Dictionary) -> void:
    # winner/forfeit notification; routed to battle_scene._on_pvp_ended(...)
    ...
```

Use `"any_peer"` so both host and client can call (client sends intents host→
receives; host sends state/ended client→receives). The receiver guards on
`multiplayer.get_remote_sender_id()` and on whether it is host/client.

**Host-authority helper.** The simulation owner is the **co-op host**
(`NetworkManager.is_host()`), independent of who issued the challenge. Add a tiny
helper surface so TID-330 can ask "am I the authority?" cleanly. Options: a method
on BattleNetSync or just call `NetworkManager.is_host()` directly. Keep it to
`NetworkManager.is_host()` / `NetworkManager.local_id()` — no new NetworkManager
API should be needed (it already exposes `is_active`, `is_host`, `local_id`,
`peer_disconnected`/`session_ended` signals). Confirm `MAX_PEERS = 1` is fine
(2-player PvP = host + 1 client; no bump needed).

**Reliability/ordering.** Godot `"reliable"` RPC is ordered+guaranteed per channel
— exactly what a turn-based exchange needs. The `seq` from TID-328 is belt-and-
braces for dropping stale mirrors.

**.uid:** `BattleNetSync.gd` is a plain script — the editor generates `.gd.uid`;
no separate resource `.uid` authoring needed. Preload it from BattleScene (TID-330)
rather than relying on `class_name`.

**Validate:** headless editor import after adding the script (parse errors here
would cascade into BattleScene's preload chain). This task may not have a runnable
end-to-end path until TID-330; verify compile + that the node can be added to a
BattleScene without error.

## Plan

Create `scenes/battle/BattleNetSync.gd` — a plain `Node` with a `battle_scene`
back-reference and three **reliable** `any_peer`/`call_remote` RPCs:
`send_intent(payload)` (client→host, routes to `_on_pvp_intent`),
`sync_state(payload)` (host→client, routes to `_on_pvp_state`), and
`pvp_ended(payload)` (host→client, routes to `_on_pvp_ended`). Each guards on
`battle_scene != null and has_method(...)`. Authority resolves via
`NetworkManager.is_host()` — no new NetworkManager API. The node is added under
BattleScene by SceneManager (TID-331) as a fixed-name child so the path
`/root/BattleScene/BattleNetSync` matches on both peers. `MAX_PEERS = 1` is fine.

## Changes Made

- **`scenes/battle/BattleNetSync.gd`** (new) — RPC relay node mirroring
  `scenes/world/NetSync.gd` but for the battle layer. Reliable RPCs `send_intent`,
  `sync_state`, `pvp_ended`, each routing to a `battle_scene._on_pvp_*` handler
  (handlers land in TID-330/332). `any_peer` so host and client can both call.
- Headless editor import clean (no parse/compile errors); the node compiles and
  can be instantiated under a BattleScene. End-to-end exercise lands in TID-330+.

## Documentation Updates

Documented holistically in TID-333 (`docs/agent/multiplayer-coop.md`).
