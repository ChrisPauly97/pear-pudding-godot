# TID-383: Party Night Hunts

**Goal:** GID-103
**Type:** agent
**Status:** pending
**Depends On:** TID-382

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Single-player Night Hunts (GID-055, docs/agent/night-hunts.md) spawn spectral enemies at night, offer increased drop rates, and provide a minimap coloring and nocturnal UI feedback. This task brings that system to co-op: when the synced world clock (from TID-382) reaches night on the shared co-op map (madrian), the authority spawns spectral enemies as deterministic world objects so the entire party hunts together. Defeats are recorded to co-op leaderboards, drop bonuses scale with party size, and the event is announced to the whole session via HUD toast.

This directly addresses BID-024 (madrian has no enemies/chests to engage with), transforming the shared landing map into a dynamic gathering space with a signature nightly event. All spawns and engagement use the GID-096 deterministic world-object sync pattern (engage-lock collision: first player to engage fights solo, enemy removed for all peers on defeat).

## Research Notes

**Spawn authority and determinism:** The authority (host) checks if `SessionState.time_of_day` is in the night range and if the party is on madrian. If so, it spawns spectral enemy entities with deterministic ids derived from a stable seed (similar to GID-054 Town Siege: `hash(str(world_seed) + "_night_hunt_" + str(days_elapsed))`). Each spectral spawn gets a unique world-object id so peers can sync their presence and engagement state via the existing `WorldObjectSync` (enemy_engaged, enemy_removed, enemy_defeated kinds).

**Party-scaled drop boost:** When a spectral enemy is defeated, the loot drop check uses a boost factor derived from the current session member count (e.g., `base_drop_chance * (1.0 + 0.15 * max(0, connected_members - 1))`). This is applied at the authority before the victory snapshot is sent, so all peers see the same drops. The connected member count comes from `SessionState.roster` (or the equivalent active peer tracking in NetworkManager).

**Engagement and solo combat:** The first peer to engage a spectral enemy (via attack or card action) triggers `WorldObjectSync.enemy_engaged(enemy_id, engaging_peer_id)` broadcasted to all peers. That enemy is then flagged as "engaged" so other peers cannot engage it — the solo player fights it. On victory, `WorldObjectSync.enemy_defeated(enemy_id, defeater_id)` is broadcast and the enemy is removed for all peers. This reuses the GID-096 pattern exactly.

**Leaderboard recording:** After victory, call `SessionStore.record_pve_score(defeater_id, enemy_type, elapsed_time, difficulty)` to log the hunt kill to co-op leaderboards (TID-379 infrastructure). The score should be attributed to the defeating player's profile within the session, not the global leaderboard (which is single-player only).

**Bounty and quest integration:** Consider a "Party Bounty" mechanic where the session tracks "spectral enemies defeated this night" and grants a session-wide reward (e.g., bonus gold) if a threshold is met. This could reuse `SessionState.party_bounties` (a dict of active party quest ids to progress) similar to single-player `BountyGen`. Alternatively, night hunt kills can count toward a daily "hunt score" that resets at dawn.

**Minimap coloring and UI feedback:** Reuse the minimap coloring from single-player Night Hunts (spectral enemies appear in a distinct color, e.g., purple or cyan). When a hunt completes, broadcast a `GameBus.hud_message_requested("Party defeated X spectral enemies this night!")` so all players see the announcement. If the party reaches a hunt threshold (e.g., 5 defeated), trigger a session-wide `GameBus.hud_message_requested` with celebratory text.

**Clock dependency:** This task depends on TID-382 because the "night" check must be synchronized. Without the synced clock, peers would have different "is_night" states, causing spectral spawns to appear at different times or only on some peers. TID-382 ensures `SessionState.time_of_day` is broadcast and applied uniformly.

**Night Hunts system files:** The single-player system is implemented in a NocturnaSystem node or similar (referenced in docs/agent/night-hunts.md). The co-op extension adds: a `_is_hunt_night` check keyed to the synced clock, a deterministic spawn routine in the authority's `_process`, and engagement sync via `WorldObjectSync`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
