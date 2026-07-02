# TID-382: Synced World Clock & Weather

**Goal:** GID-103
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** claude/end-to-end-goal-nbilf4
**Acquired:** 2026-07-02T19:33:45Z
**Expires:** 2026-07-02T20:03:45Z

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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
