# TID-386: Session Tournament Mode

**Goal:** GID-104
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** claude/sonnet-5-subagent-dispatch-yz77ku
**Acquired:** 2026-07-02T09:05:00Z
**Expires:** 2026-07-02T09:35:00Z

## Context

With 3–4 players in a co-op session there is no structured competition—duels are ad-hoc challenges between two players, leaving the others idle or spectating informally. A host-run tournament gives a session a marquee event, schedules matches in a predictable bracket, and gives non-combatants a reason to watch via the spectate system (TID-367). A tournament takes 3–4 connected peers, builds an authority-scheduled round-robin or single-elimination bracket, and runs each match through the existing `SceneManager.enter_pvp_battle` flow with auto-spectate for non-combatants. The host is the authority; they can initiate a tournament from a new "Tournament" HUD button (visible only when 3–4 players are connected, mirroring the host-only "Team Duel" and "Dungeon Crawl" button precedents). The bracket state lives on the authority and is broadcast to peers for a HUD bracket panel showing match results and the current match.

Ante pool escrow reuses the wagered-duel coin pattern from TID-362: all participants deduct their ante (`SaveManager.add_coins(-ante)`) on tournament entry, the host holds the escrow in-memory, and at the end of the bracket the winner (or winners if multiple rounds) receives the pot via direct `SessionState` member-record writes (following the `_grant_chest_loot_to_token` pattern used for party bounties). Optionally, each match can be rated for ranked ELO changes via the existing `RatingMath` path. Match results flow naturally through `GameBus.pvp_battle_ended` and the `_on_pvp_battle_ended_coop` handler, so the authority receives battle outcomes and advances the bracket state without needing new event channels.

## Research Notes

**Existing patterns:**
- Host-only buttons: `scenes/hud/HudManager.gd` and related overlay scenes already gate features on `NetworkManager.is_host()` (e.g., team duel button visible only to host). The tournament button follows the same pattern: visible only when `NetworkManager.is_host()` and `NetworkManager.get_peer_count() >= 3`.
- Battle flow: `SceneManager.enter_pvp_battle(local_idx, opponent_deck, ante_coins, ranked=False)` expects the local player index and opponent deck; the host can call this repeatedly for each bracket match, passing the scheduled matchups.
- Auto-spectate: non-combatants are redirected to `SceneManager.enter_pvp_spectator()` (TID-367) while the host and opponent enter the battle. `NetSync.recv_pvp_active(in_battle, peer_a, peer_b)` informs spectators who is currently fighting.
- Match results: `_on_pvp_battle_ended_coop(winner_idx, loser_idx, rewards)` in `scenes/multiplayer/NetSync.gd` receives the outcome. The host can track this to advance the bracket.
- Coin escrow: `SaveManager.add_coins(delta)` is the entry point. On tournament start, the authority deducts `ante * num_players` from each player. On tournament end, the authority writes the full pot to the winner via `SessionState.members[winner_token].coins += pot` (direct member write, not `add_coins`, to bypass auth checks on the authority).
- Rated matches: the `ranked` flag passed to `enter_pvp_battle` sets `GameState._pvp_ranked = True`, which causes `_on_pvp_battle_ended_coop` to call `RatingMath.update_elo(winner_rating, loser_rating, ...)`. ELO changes write directly to `SessionState.members[token].pvp_rating` and `pvp_games`.
- Bracket data: in-memory authority-only `BracketState` class (or nested data) tracks: players, matches (scheduled, in-progress, completed), current match index, winner. Broadcast to peers via a simple RPC (e.g. `_on_bracket_updated(bracket_dict)`) so they can render a HUD bracket panel.

**CLAUDE.md invariants:**
- NetworkManager guard: all tournament logic wrapped in `if NetworkManager.is_active():` (single-player unaffected).
- Wire format: if bracket state is broadcast via RPC, use a pure helper in `game_logic/net/` (e.g. `TournamentSync.encode_bracket(state) -> Dictionary`) mirroring `AvatarSync`/`BattleNetProtocol`.
- Headless import: after any `.gd` edit, run the headless import check (must be empty).
- Preload + UID: if new `.tres` tournament configs are created, declare preloads and generate `.uid` sidecars.
- Mobile parity: the "Start Tournament" button and bracket panel must be tap-able on mobile (not keyboard-only).

**Files to examine:**
- `autoloads/SaveManager.gd` — `add_coins()` and member-write patterns for escrow and payout.
- `autoloads/SessionState.gd` — `members` list, direct `members[i].coins` / `members[i].pvp_rating` writes; versioning for any new fields.
- `scenes/multiplayer/NetSync.gd` — `request_battle` / `respond_battle` and `_on_pvp_battle_ended_coop` signature; add RPC for bracket updates if needed.
- `autoloads/SceneManager.gd` — `enter_pvp_battle` and `enter_pvp_spectator` methods; host-only tournament orchestration.
- `game_logic/net/RatingMath.gd` — `update_elo` logic (already pure and reusable for each tournament match).
- `scenes/hud/HudManager.gd` and overlay scenes — where the tournament button and bracket panel are wired.

**Bracket algorithms:**
- Round-robin (all vs. all): `N * (N - 1) / 2` matches; matches scheduled sequentially or in parallel waves.
- Single-elimination: `N - 1` matches (binary tree, 3–4 players fits one round), winner determined in log₂(N) rounds.
- Swiss-system: hybrid; requires wins/losses tracking per round. For a one-off tournament, round-robin or single-elim is simpler.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
