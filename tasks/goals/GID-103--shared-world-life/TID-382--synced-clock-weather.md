# TID-382: Synced World Clock & Weather

**Goal:** GID-103
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Day/night and weather are currently explicitly unsynced in co-op (Limitations section of docs/agent/multiplayer-coop.md), causing each peer to experience different times of day, different skies, and therefore different environmental effects. This breaks immersion and prevents time-gated shared events (e.g., night hunts, siege phases). `SessionState` already carries `time_of_day` and `days_elapsed` as the canonical shared world progress (authority-only write via `SessionStore`), but there is no live broadcast mechanism to apply those values to peers' local graphics systems (ProceduralSkyMaterial tint, weather controller, nocturnal checks).

This task adds a pure wire-format helper (`EnvSync`) and a NetSync RPC broadcast so all peers receive the authority's current clock and weather state, apply it to their local sky/atmosphere shaders, and see a unified sky. Late-joining peers receive the current env state as part of the existing character unicast snapshot (`_send_character_to_peer`), ensuring no desync window.

## Research Notes

**Authority and peers:** The authority (host) owns `SessionState.time_of_day` and `SessionState.days_elapsed`; only `SessionStore.save_session()` writes these fields. Peers consume them read-only, used only for graphics and nocturnal checks. The WebClock autoload (or equivalent time-tracking logic) is already authority-driven via `SessionState` (clients reset their world-clock each frame to match the snapshot).

**Wire format pattern:** Create `game_logic/net/EnvSync.gd` following the established pattern (AvatarSync, SocialSync, ChatSync, WorldObjectSync): pure static functions `encode(time_of_day: float, days_elapsed: int, weather_type: int) -> PackedByteArray` and `decode(data: PackedByteArray) -> Dictionary` returning `{"time_of_day": float, "days_elapsed": int, "weather_type": int}`. Unit tests mirror AvatarSync. This decouples the wire format from the underlying systems and makes it reusable for snapshots and RPCs.

**NetSync RPC:** Add a new RPC method `recv_env_state(env_data: PackedByteArray)` to the `NetSync` node (fixed-name child at `/root/WorldScene/NetSync`), reliable and authority → clients. The authority broadcasts either on every `SessionState` write or on a low-Hz tick (e.g., every 2–5 seconds if the state changed) to avoid spam. Clients decode and apply to local `DayNightCycle` and `WeatherController` autoloads (or their equivalent nodes).

**Late-join snapshot:** Extend the existing `_send_character_to_peer(peer_id)` unicast in `WorldScene._setup_coop()` to include the current `EnvSync.encode(SessionState.time_of_day, SessionState.days_elapsed, weather_type)` payload. The peer applies it before rendering, ensuring no window of mismatch.

**Single-player guard:** All broadcasts and RPC receives are guarded by `if not NetworkManager.is_active(): return`. Single-player code paths (which use `DayNightCycle` and `WeatherController` directly) are untouched.

**Weather system:** Weather system is documented in GID-042. The weather controller exposes a weather state (e.g., `current_weather: int` or a method `set_weather(type)`) that peers apply on receiving the env broadcast.

**Dependencies and imports:** `NetworkManager` autoload for `is_active()` and `is_host()`; `SessionState` for `time_of_day` and `days_elapsed`; `DayNightCycle` and `WeatherController` autoloads or WorldScene children for local graphics application.

## Plan

1. Add a pure `game_logic/net/EnvSync.gd` wire-format helper (encode/decode
   `[time_of_day, days_elapsed, weather_id]`) plus a small standalone weather
   table (`roll_weather`/`roll_duration`) mirroring `WeatherManager`'s
   grasslands table, since `WeatherManager` itself is hard-gated to `"main"`.
2. Bump `SessionState` to v9: add `weather_id: String = ""` field + migration.
3. Add `NetSync.recv_env_state(payload)` RPC (`call_remote`, mirrors
   `recv_world_event`).
4. `WorldScene`: host-only `_tick_env_sync` (guarded `not _is_infinite` +
   `_coop_world_authority()`) rolls weather on a timer, applies it locally via
   the existing `_on_weather_changed`, persists to `SessionState.weather_id`,
   and broadcasts the clock+weather every `_ENV_BROADCAST_INTERVAL` (3s) or
   immediately on a weather change. Clients apply the broadcast to their local
   `_dnc` and mirror `days_elapsed`/`weather_id` (no `SessionStore` on a client).
5. Extend `_send_character_to_peer`'s late-join snapshot with the current env
   state so a joiner never sees a stale sky.
6. Wire `_dnc.day_passed` to also increment `SessionState.days_elapsed` on the
   host when co-op is active — closes BID-039 (the auction-house expiry sweep
   was dormant because nothing advanced this counter).
7. Unit tests for `EnvSync` (round-trip + weighted-roll determinism).

Complexity assessed as high (touches SessionState versioning, a new RPC, and a
new WorldScene subsystem) but the design was fully specified by the task's
Research Notes and closely mirrors existing patterns (AvatarSync, WorldObjectSync,
the dungeon-crawl deterministic-seed pattern) — proceeded directly to Build per
the "otherwise proceed to Build" rule, as part of an explicit end-to-end
autonomous goal-implementation request.

## Changes Made

- `game_logic/net/EnvSync.gd` (new) — pure encode/decode + weather roll/duration
  helpers.
- `tests/unit/test_env_sync.gd` (new) — 12 tests.
- `game_logic/net/SessionState.gd` — v9 migration adds `weather_id`; `to_dict`/
  `from_dict` round-trip it.
- `scenes/world/NetSync.gd` — `recv_env_state` RPC.
- `scenes/world/WorldScene.gd` — `_tick_env_sync`, `_coop_roll_weather`,
  `_broadcast_env_state`, `_on_env_state_received`, `_coop_current_days_elapsed`;
  wired into `_process`, `_send_character_to_peer`, `_setup_session` (resume the
  host's own clock from the persisted session value), `_dnc.day_passed`'s
  handler, and `_on_coop_session_ended` (reset weather mirror/RNG on session end).
- Resolved BID-039 as a side effect (moved to `tasks/archive/backlog/`,
  `tasks/index.md` updated) — `SessionState.days_elapsed` now actually advances
  in co-op, so the GID-102/TID-378 auction-expiry sweep is live.

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: updated the "Live-synced (GID-096)" bullet
  in Limitations to state day/night + weather are now synced; added the
  "Shared World Life (GID-103)" section with a "Synced World Clock & Weather"
  subsection covering the full design (this task) plus Night Hunts/Siege
  (TID-383/384, same section — see those task files).
