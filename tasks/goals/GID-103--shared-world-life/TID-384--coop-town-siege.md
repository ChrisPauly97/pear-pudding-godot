# TID-384: Co-op Town Siege Defense

**Goal:** GID-103
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Single-player Town Siege (GID-054) is a narrative event where waves of enemies attack the player's town, building tension and culminating in a boss battle. This task adapts Town Siege for co-op as the flagship party defense event on the shared madrian map: the host can trigger a "Siege" from a dedicated HUD button, synchronized enemy waves spawn for all peers (deterministic ids via world-object sync), and the final wave escalates into a joint PvE boss battle via the GID-099 engine (`BattleScene._coop_pve`, `CoopBattleScaling`). Victory rewards (gold, cards, achievements) are distributed to all active session members and persisted to `SessionState`, providing a climactic shared goal that directly addresses BID-024 (madrian has nothing to do).

This is the flagship co-op event: it brings the atmospheric Town Siege narrative into multiplayer, creates a scripted spectacle with wave escalation, and uses the full co-op battle infrastructure (party scaling, shared leaderboard recording, session-wide rewards).

## Research Notes

**Host-only trigger button:** Following the TID-380 precedent (Dungeon Crawl button), create a "Siege" HUD button in `WorldScene._setup_coop()`, visible only when `NetworkManager.is_host()`. The button is disabled during active sieges (state flag: `_siege_active: bool`) and shows "Siege In Progress" or is hidden. When pressed, call a local method `_start_siege()` which broadcasts a map transition or world-state change via the existing `recv_map_transition` RPC (or a new dedicated RPC if the transition is complex, e.g., `_recv_siege_started(siege_id, seed)`).

**Deterministic wave spawning:** Derive a siege seed from `hash(str(world_seed) + "_siege_" + str(days_elapsed))` (like TID-380). Use this seed to deterministically generate wave configurations (enemy types, counts, tiers) on every peer simultaneously — no randomness divergence. Each enemy in each wave gets a unique world-object id (`siege_wave_` + `wave_number` + `_enemy_` + `index`). Enemies spawn via deterministic coords and are tracked in `SessionState` so rejoining peers know what's active.

**Wave synchronization via WorldObjectSync:** Each spawned enemy syncs via GID-096 `WorldObjectSync`: enemy_engaged (first attacker locks it), enemy_removed (on death or despawn), enemy_defeated (victory recorded). Peers cannot engage an already-engaged enemy. On each enemy defeat, a brief HUD message announces the kill, and a counter increments toward the next wave. When all enemies in a wave are defeated, the next wave escalates (more enemies, higher tiers, faster spawn). This is all driven from the authority's `_process` watching the world-object sync feedback.

**Wave escalation and boss finale:** The final wave (e.g., wave 5 or 10) culminates in a boss encounter instead of regular enemy spawns. The boss is a special enemy entity (or a marker that triggers the next battle). When the boss is engaged by the first player, that player initiates a joint PvE battle via `SceneManager.start_coop_pve_battle(boss_data)` (using GID-099's `_coop_pve` path). The battle scene receives `CoopBattleScaling.scale_boss_tier(base_tier, connected_member_count)` to adjust boss HP and abilities for the party size.

**Joint PvE battle integration:** Use the GID-099 `BattleScene._coop_pve` path: `GameState._coop_pve` flag is true, `turn_order` includes all connected players, the boss is the opponent. The battle engine broadcasts every action via `BattleNetSync` so all peers see the same board state. On victory, `GameBus.coop_pve_battle_ended(did_win: bool)` is emitted. On win, the authority calls `SessionStore.record_siege_victory(days_elapsed, difficulty_tier)` and distributes rewards (gold, cards, achievements) to all `SessionState.roster` members via direct `SessionStore.ensure_member` writes.

**Rewards and persistence:** Siege victory grants:
- Gold split evenly across active members (or total gold with each member getting a share via SessionStore).
- Random card drops scaled by party size (e.g., higher rarity boosted by connected members).
- Session leaderboard entry via `SessionStore.record_pve_score("siege", days_elapsed, boss_tier, elapsed_time)` attributed to the host or the whole party.
- Achievement unlock (e.g., "Defended the Town") recorded to each member's session achievements.

All writes go through `SessionStore` (authority-only) so the session save stays coherent. When a peer's turn arrives to receive rewards, a short cinematic or HUD toast announces "You defended Madrian!" with the gold/card count.

**Announcement and messaging:** Before the siege starts, broadcast `GameBus.hud_message_requested("The town is under siege!")` to all peers. Between waves, announce wave escalation ("Wave 3: Siege intensifies..."). On boss spawn, announce the boss name and threat ("The Siege Commander arrives!"). On victory, broadcast a celebration message with the total rewards ("Party earned X gold and defeated the Siege Commander!"). All messages go through `GameBus.hud_message_requested` (session-visible).

**Session state fields:** Add to `SessionState` (version bump + migration):
- `current_siege: Dictionary` — active siege id, wave number, enemy spawn ids, timestamp started (null if no siege active).
- `siege_history: Array` — completed sieges (days_elapsed, difficulty, rewards_distributed, timestamp).
- `siege_leaderboard_entries: Array` — high scores from past sieges (for session-only leaderboard display).

**Single-player unchanged:** All co-op siege code is guarded by `if not NetworkManager.is_active(): return` at the top. Single-player WorldScene has no "Siege" button and no siege-related state. Single-player Town Siege (GID-054) logic remains orthogonal.

**Wire messages as pure helpers:** Any new wire format (e.g., siege_wave_state, siege_victory_reward, siege_leaderboard_entry) lives as a pure static helper in `game_logic/net/` (e.g., `SiegeSync.gd`) mirroring AvatarSync, with `encode()` and `decode()` functions and unit tests. The NetSync RPC (e.g., `recv_siege_wave_spawned(data)`) calls the helper to decode.

**Town Siege reuse:** The single-player Town Siege (GID-054) system already has wave configurations, enemy tier logic, and boss data (likely in a `TownSiegeConfig` or similar). The co-op variant uses the same data structures, but wraps them in the deterministic spawn and sync layers. There is no code duplication — Town Siege logic is pure data; co-op wraps it in sync.

## Plan

1. Pure deterministic wave planner `game_logic/CoopSiege.gd`: `WAVE_COUNT = 3`
   raider waves, `generate_wave(map_name, siege_id, wave)` derives ids/types/
   offsets seeded by `(siege_id, wave, map_name)` — same "every peer computes
   the identical plan, only progression is broadcast" technique as
   CoopNightHunts, extended with an explicit host-driven "advance" broadcast
   since wave escalation (unlike the day/night boundary) has no independently
   observable trigger every peer can detect on its own. Reuses the existing
   `martarquas_raider_1/2/3` enemy data; reuses `roaming_terror` (existing
   `is_boss: true, boss_hp: 50` enemy, thematically already tied to the
   Martarquas conflict) as the finale boss rather than authoring new enemy data.
2. Host-only "Siege" HUD button (`_ensure_siege_button`/`_start_coop_siege`),
   directly mirroring the TID-380 Dungeon Crawl button precedent (viewport-relative
   sizing, `NetworkManager.is_host()` re-asserted every call, deterministic
   seed from `world_seed + days_elapsed`).
3. Wave sync: `recv_siege_started`/`recv_siege_wave`/`recv_siege_boss_phase`
   RPCs (host → all) carry only the *progression signal*; each peer spawns the
   deterministic wave/boss independently on receipt. Host-only
   `_coop_tick_siege` watches `_coop_removed_enemies` (the existing GID-096
   engage-lock state) for full-wave clears — reuses that mechanism with zero
   new event kinds.
4. Boss handoff to the GID-099 joint PvE engine — confirmed via research that
   `SceneManager.enter_coop_pve_battle` had **no existing caller** anywhere in
   the codebase, making this task the engine's first real consumer. Boss node
   id prefixed `siege_boss_`; `_on_enemy_engaged_coop` special-cases the prefix
   to route to `_coop_engage_siege_boss` instead of the normal solo-engage path.
   A client relays the intent to host via `submit_siege_boss_engaged`; host
   gathers every connected member's deck via `_team_deck_for_peer` (the same
   helper 2v2 Team Duels already use) and calls `enter_coop_pve_battle` — boss
   HP/tier scaling by party size is already handled inside
   `BattleScene._build_coop_pve_state` (confirmed by reading it), so `edata` is
   passed through unscaled.
5. Rewards: `_finish_coop_siege_victory` (host-only) splits 150 gold + a random
   rare-or-better card across every session member, writing directly into each
   member's `SessionState` record and push-syncing refreshed `recv_character`
   snapshots. The co-op-clear leaderboard entry is **not** duplicated — the
   pre-existing `_on_coop_pve_battle_ended_leaderboard` handler (permanently
   connected to the same `GameBus.coop_pve_battle_ended` signal) already
   records every joint PvE win, including this one, to `coop_clears`.
6. Formal `AchievementRegistry` integration was scoped out — that registry's
   condition-check design targets single-player `SaveManager` fields, not
   session-scoped co-op rewards, and wiring a parallel achievement path was
   judged out of proportion for this task; the win is still announced via
   `GameBus.hud_message_requested`.
7. Persisting in-progress siege state to `SessionState` (for a mid-siege map
   transition or reconnect) was scoped out as a v1 limitation, documented in
   `docs/agent/multiplayer-coop.md` — mirrors the existing PvP-battle-disconnect
   limitations already accepted elsewhere in this doc.
8. Unit tests for `CoopSiege` (determinism, wave escalation, uniqueness).

Complexity assessed as high (new pure-logic file, 5 new RPCs, and the first-ever
caller of the GID-099 joint-battle engine) but fully specified by the task's
Research Notes and closely modeled on three already-shipped precedents (TID-380
dungeon crawl, GID-096 engage-locks, GID-102 Team Duel deck-gathering) —
proceeded directly to Build, as part of an explicit end-to-end autonomous
goal-implementation request.

## Changes Made

- `game_logic/CoopSiege.gd` (new) — pure wave planner.
- `tests/unit/test_coop_siege.gd` (new) — 14 tests.
- `scenes/world/NetSync.gd` — `recv_siege_started`, `recv_siege_wave`,
  `recv_siege_boss_phase`, `submit_siege_boss_engaged`, `notify_coop_pve_start`
  RPCs.
- `scenes/world/WorldScene.gd` — full Co-op Town Siege section: HUD button,
  start/receive handlers, wave spawn/tick, boss engage interception (patched
  into the existing `_on_enemy_engaged_coop`), joint-battle handoff, battle-end
  handler, and reward distribution. Wired into `_setup_coop` (button creation),
  `_process` (`_coop_tick_siege`), and `_on_coop_session_ended` (cleanup).
  Fixed a self-review bug before finalizing: RPCs in this codebase are declared
  `"call_remote"` (never self-invoking), so a client-engaged boss required an
  explicit local `_coop_remove_enemy_node` call on the host in addition to the
  broadcast to other peers.
- Logged BID-041 (pre-existing single-player bug found while researching the
  raider-spawn precedent: `_spawn_siege_raiders`'s `node.set("enemy_type", ...)`
  is a silent no-op since `EnemyNPC` has no such property) — not fixed here
  (out of this task's scope; the new co-op spawner does not share the bug).

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: "Shared World Life (GID-103)" section,
  "Co-op Town Siege" subsection — full design writeup; Limitations section
  updated with the "siege state does not survive a map transition" note.
- `docs/agent/town-siege.md`: added a short "Co-op (GID-103 / TID-384)" pointer
  section clarifying this is a different composition from the single-player
  sequential gauntlet, with a link to the full design doc.
