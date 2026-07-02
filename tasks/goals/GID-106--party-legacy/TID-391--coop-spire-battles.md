# TID-391: Co-op Spire — Joint Floor Battles & Leaderboard

**Goal:** GID-106
**Type:** agent
**Status:** pending
**Depends On:** TID-390

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Completes the co-op Spire loop: the party drafted a shared deck together (TID-390), and now they fight each floor as a team. This task integrates floor battles into the joint PvE engine (GID-099: `_coop_pve`, `CoopBattleScaling.scale_boss_tier`) so the party faces progressively harder bosses coordinated by tier. The run's final result — the highest floor reached — feeds `SessionState.record_pve_score` on the `"coop_clears"` board, completing the leaderboard-recording cycle started in TID-379. Critically, this task also **enriches the value signal** sent to the leaderboard (BID-031): instead of just recording party size, capture the highest floor and maybe elapsed session day, giving future runs meaningful ranking granularity. A run summary overlay (reusing `RunSummaryScene` with a co-op cosmetic variant) is shown to all peers when the run ends. Handling mid-run disconnect is documented: the run continues for remaining members; rejoining mid-run is out of scope.

## Research Notes

**Floor battle routing — integrate into GID-099 joint PvE engine.** `SpireScene._run_floor_coop(floor_num)` (new co-op branch) routes to `SceneManager.enter_coop_battle(state_setup)` instead of the single-player `BattleScene.spire_floor` path. The battle is a one-off encounter (not a full session-long co-op battle), so the normal co-op setup applies: `_coop_pve = true`, `_players` seeded from session members, boss tier scaled via `CoopBattleScaling.scale_boss_tier(base_tier, party_size, floor_num)` (or a Spire-specific variant if the formula differs). The drafted shared deck is passed to `_setup_battle()` or persisted on `GameState` for all party members to draw from. **Decision to make in Plan:** does each member have their own hand / field, or is there one shared board and one rotating hand? Guidance: consider co-op PvE UX (BattleScene already supports multiple player states) and whether rotating control feels natural. The GID-099 implementation (`_coop_pve` battles) can be used as-is if each peer controls its own hero on a shared field.

**Run-end recording to PvE leaderboard.** `SpireScene.spire_run_ended(stats)` already emits `GameBus.spire_run_ended(stats)` (GID-038). For co-op runs, a new signal variant `GameBus.coop_spire_run_ended(stats, floor_reached)` is broadcast to the party, or the existing signal is enhanced with an optional co-op flag. WorldScene connects both and routes to `_on_spire_run_ended_leaderboard(stats, floor, is_coop)`: on the authority, calls `SessionState.record_pve_score("coop_spire", token, name, value, day)` where `value` is **`floor_reached + (party_size * 0.1)`** or similar — a richer signal than GID-099's pure party size (TID-379 BID-031 note). Alternatively, thread floor + party composition into the value as JSON or a structured int (e.g. `(floor * 100) + party_size`), or add a parallel `SessionState.record_pve_stats(board, token, {floor, party_size, session_day})` method if the structure should be richer than a single int. Choose in Plan based on how much granularity the leaderboard UI (not this task) will expose. The entry is marked with the session's current `day` (from `SessionStore`), so runs are time-stamped.

**Run summary — co-op variant.** `scenes/ui/RunSummaryScene.gd` displays floor reached, XP (if earned), and cards won. For co-op, it also shows **party member names and colors** (fetched from `_remote_identities` in the session state) and maybe a shared stat line (e.g. "3 players, 9 floors defeated"). The existing scene can gain a `_coop_mode: bool` flag set during entry, and a co-op variant overlay is rendered via `_refresh_coop()`. All peers see the same summary (fetched from a `recv_spire_run_summary(stats)` RPC from the authority, or computed locally since the floor is deterministic). Once Continue is pressed, all peers are routed back to madrian via `NetSync.recv_map_transition` (TID-355 pattern, same as dungeon-crawl shared transitions).

**Mid-run disconnect — continued play for remaining members.** If a member DC'd during the run, the authority continues the run server-side with the remaining party members; a rejoining member lands back in the Spire at the floor they disconnected on (or at the next floor, decide in Plan). The run's recorded leaderboard entry is authored by the authority with the party composition at **run end**, not start — if the party size changed mid-run, the final value reflects the survivors. This is a deliberate simplification: tracking "started with 3, finished with 2" adds bookkeeping; recording the final survivor count is simple and fair. Document this clearly in Plan Notes.

**Project invariants.** All co-op Spire code guarded by `NetworkManager.is_active()`. Single-player floor battles entirely unchanged. New signals on GameBus (optional if reusing existing) must be declared in `autoloads/GameBus.gd`. Headless import must pass.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
