# TID-383: Party Night Hunts

**Goal:** GID-103
**Type:** agent
**Status:** done
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

1. Pure deterministic planner `game_logic/CoopNightHunts.gd`:
   `generate_hunt(map_name, days_elapsed)` derives up to 4 spectral enemies
   (id/type/offset from the map's `SiegeDefs.TOWN_GATES` anchor), seeded only
   by `(map_name, days_elapsed)` — no world-seed dependency needed since
   `days_elapsed` is already synced (TID-382) and both peers are on the same
   map by construction. `party_drop_tier_bonus(party_size)` for the drop-boost
   scaling requirement.
2. `WorldScene._coop_update_night_hunts` (ticked every frame, `_coop_active` +
   `not _is_infinite`): spawns the plan the instant the synced clock crosses
   into night, despawns at dawn. Each spawned node's `enemy_data["id"]` is the
   deterministic id, so the pre-existing GID-096 engage-lock/defeat flow needs
   **zero changes** to handle them — confirmed by reading `EnemyNPC.engage()`
   (emits `enemy_data` verbatim) and `_on_enemy_engaged_coop`/`_on_world_event_*`
   (generic on any id).
3. `SceneManager._on_battle_won`: add the party-size drop-tier bonus on top of
   the existing single-player night boost, guarded by `NetworkManager.is_active()`.
4. New `"night_hunts"` PvE leaderboard board (`SessionState` v9, same migration
   as TID-382's `weather_id`): kill tally submitted via the existing generic
   `_submit_pve_score` routing (host-direct or client-RPC, whichever already
   exists) — no new RPC needed.
5. HUD toast per kill + a 5-kill milestone message via the existing
   `GameBus.hud_message_requested` signal.
6. Unit tests for `CoopNightHunts` (determinism, uniqueness, map support).

## Changes Made

- `game_logic/CoopNightHunts.gd` (new) — pure spawn planner + drop-bonus helper.
- `tests/unit/test_coop_night_hunts.gd` (new) — 14 tests.
- `game_logic/net/SessionState.gd` — `_PVE_BOARDS`/`leaderboards`/
  `get_pve_leaderboards_snapshot` extended with `"night_hunts"` (same v9
  migration as TID-382).
- `scenes/world/WorldScene.gd` — `_coop_update_night_hunts`,
  `_coop_spawn_night_hunt`, `_coop_despawn_night_hunt`; wired into `_process`
  and `_on_coop_session_ended` cleanup. `_coop_persist_enemy_defeat` extended
  to tally + announce + submit a night-hunt kill when the defeated id begins
  with `"night_hunt_"`. Minimap coloring required no changes — it already keys
  off the shared `is_nocturnal` meta flag both single-player and this system set.
- `autoloads/SceneManager.gd` — `_on_battle_won` applies
  `CoopNightHunts.party_drop_tier_bonus` on a co-op spectral kill.

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: "Shared World Life (GID-103)" section,
  "Party Night Hunts" subsection — full design writeup.
- `docs/agent/night-hunts.md`: added a short "Co-op (GID-103 / TID-383)" pointer
  section clarifying this is a parallel system, not a reuse of the
  infinite-world spawn loop, with a link to the full design doc.
