# TID-384: Co-op Town Siege Defense

**Goal:** GID-103
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** claude/end-to-end-goal-nbilf4
**Acquired:** 2026-07-02T19:33:45Z
**Expires:** 2026-07-02T20:03:45Z

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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
