# TID-327: LAN game discovery (UDP broadcast) + found-games list in lobby

**Goal:** GID-090
**Type:** agent
**Status:** pending
**Depends On:** TID-321, TID-324

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Typing the host's IP is clunky, especially on mobile. This task adds local-network
game discovery so a joining player sees a list of nearby hosts and taps one to
join — no IP entry needed. Manual IP entry (TID-324) remains as a fallback for
networks where broadcast is blocked. Discovery is a **separate UDP channel** from
the ENet game connection; ENet still carries gameplay. This is an
ENet-transport-only feature: when the Steam transport is added later, Steam
matchmaking replaces this scan, so discovery must live behind the same transport
seam as `NetworkManager` (do not bake it into transport-agnostic code paths).

## Research Notes

**Mechanism — UDP broadcast via `PacketPeerUDP` (request/response):**
- **Discovery port:** a fixed constant separate from the game port (game port is
  `24565` per TID-321; use e.g. `DISCOVERY_PORT = 24566`).
- **Host side:** while hosting (or always, when a session is active), bind a
  `PacketPeerUDP` listener on `DISCOVERY_PORT`. On each received query packet,
  reply (to the sender's address via `get_packet_ip()/get_packet_port()`) with a
  small JSON dict: `{"name": <host label>, "game_port": 24565, "map": "madrian",
  "players": <count>}`. Poll the socket from `_process` (PacketPeerUDP is
  non-blocking; check `get_available_packet_count()`).
- **Client side:** create a `PacketPeerUDP`, `set_broadcast_enabled(true)`,
  `set_dest_address("255.255.255.255", DISCOVERY_PORT)`, `put_packet(query)`,
  then collect replies for ~1.0 s. Each reply's source IP
  (`get_packet_ip()`) + decoded JSON becomes a discovered host. Dedupe by IP.
- Tapping a discovered host calls the existing `NetworkManager.join(ip, game_port)`.

**Where it lives:** add the discovery logic to `NetworkManager`
(`autoloads/NetworkManager.gd`) as transport-specific helpers, e.g.:
```gdscript
signal hosts_discovered(hosts: Array)   # Array of {name, ip, game_port, map, players}
func start_discovery() -> void          # client: begin a scan
func stop_discovery() -> void
func _serve_discovery() -> void         # host: answer queries (called from _process)
```
Keep the ENet specificity explicit so the Steam path can no-op these and use Steam
lobbies instead. Reuse `is_host()` / `is_active()` from TID-321.

**Lobby UI (extend `scenes/ui/MultiplayerLobbyScene.gd` from TID-324):**
- Add a "Find Games" / refresh button that calls `start_discovery()`, a list
  control (e.g. `ItemList` or VBox of buttons) populated from `hosts_discovered`,
  and a "joining…" status. Keep manual IP entry visible as fallback.
- Viewport-relative sizing; re-layout on `NOTIFICATION_RESIZED`; tap-friendly list
  rows (mobile parity — CLAUDE.md).

**Caveats / risks to handle and document:**
- **AP isolation / guest networks** block UDP broadcast (same as the game traffic).
  Discovery is best-effort — manual IP entry MUST remain functional.
- **Android multicast/broadcast lock:** many Android devices will not deliver
  *incoming* broadcast UDP to an app without a `WifiManager.MulticastLock`. An
  Android **host** may therefore not hear client queries. Mitigations to evaluate
  (do a small spike early): (a) host periodically *broadcasts a beacon* instead of
  waiting for queries — *sending* broadcast does not require the lock, only
  receiving does — and clients passively listen; or (b) add a minimal Android
  plugin to acquire a MulticastLock. Prefer (a) if it proves reliable, since it is
  pure GDScript. Record which approach worked in Changes Made and the agent doc.
- Broadcast does not cross subnets/routers — same-LAN only (acceptable for slice).

**Testing:** unit-test the discovery payload encode/decode (pure JSON dict
round-trip) alongside TID-325's `test_coop_sync.gd` or a sibling test. Manual:
host on one device, open lobby on another, confirm the host appears in the list
and tapping it joins. Test desktop↔desktop first, then Android↔desktop, then
Android↔Android (the multicast-lock case). Headless compile check per CLAUDE.md.

**CLAUDE.md conventions:** explicit type annotations (UDP `get_packet()` returns
`PackedByteArray`; JSON parse returns Variant — annotate); preload referenced
scripts; no `.uid` for plain `.gd`; validate with headless import.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
