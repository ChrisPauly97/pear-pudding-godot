# TID-371: 2v2 team duels (allies-vs-allies battle mode)

**Goal:** GID-102
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

PvP today is strictly **2 players** (`docs/agent/multiplayer-coop.md` → "PvP is LAN/loopback
only, 2 players"). The N-player joint battle engine (GID-099) already supports 2–4
participants for **allies-vs-boss**. This task adds **team PvP**: two teams of human allies
(e.g. 2v2) fight each other, reusing that engine. This is the largest battle-layer task.

## Research Notes

- **Engine reuse — `game_logic/battle/GameState.gd`.** `setup_coop_battle(n_allies,
  ally_setup, boss_setup)` builds N ally `PlayerState`s + 1 boss; turn rotation is already
  `(current_player_idx + 1) % players.size()` (generalised, see GID-099 docs). For team PvP
  the change is **targeting + win/loss by team**, not turn order:
  - Add a `team_battle: bool` flag (parallel to `coop_battle`) and a per-player `team: int`
    (0 or 1). No boss; every player `is_ai = false` (or AI-filled if a slot is empty).
  - `opponent()` for a player on team T must return an **enemy-team** target (lowest-HP
    enemy hero, reusing `_get_lowest_hp_ally`-style logic generalised to "lowest-HP player
    not on my team"). Attacks/spells may target any enemy-team board/hero — extend the
    `target_pidx` plumbing already added to `encode_attack` (GID-099) and the `pidx`
    cross-board spell targeting (GID-100).
  - `is_game_over()` / `winner()` by team: a team loses when **all** its players' heroes are
    dead; `winner()` returns the surviving team id.
- **Wire format — `game_logic/net/BattleNetProtocol.gd`.** `encode_attack` already carries
  `target_pidx`; team play also needs the acting player's team known to the authority. Keep
  intents player-indexed (the authority maps `peer_id → player_idx` exactly as the co-op-PvE
  referee does, see `_coop_peer_to_idx` / `_pvp_peer_to_idx`).
- **Relay — `scenes/battle/BattleNetSync.gd`.** Add a distinct RPC set for team PvP
  (`send_team_intent` / `sync_team_state` / `team_battle_ended` / `request_team_sync`)
  mirroring the co-op-PvE RPCs (lines 48–82) so modes never share a handler. Authority owns
  the canonical `GameState`, broadcasts mirrors to all participants; clients render from
  their own perspective (generalise `_my_idx()`/`_opp_idx()` — for teams, "my side" vs "the
  rest", grouped by team in the arena layout).
- **Scene — `scenes/battle/BattleScene.gd` + `autoloads/SceneManager.gd`.** Add
  `enter_team_battle(local_player_idx, team_assignments, all_decks)` mirroring
  `enter_coop_pve_battle` / `enter_pvp_battle`. Reuse the GID-100 square-battlefield ally bar
  to show all participants grouped by team. Gate everything behind a new `_team_pvp: bool`.
- **Challenge/handshake — `scenes/world/NetSync.gd` + WorldScene.** Extend the proximity
  challenge flow (`request_battle`/`respond_battle`) to form teams. Simplest first cut:
  challenger picks a partner from the roster, both confirm, then the other two confirm — or
  scope this task to **the authority assigns teams from the 4-peer session** and the world
  HUD offers a "Team Duel" button when ≥4 players are present. Keep team formation UI minimal.
- **Rewards/rating:** wire to TID-370 so a team duel updates each participant's rating
  (team-average expected score, or pairwise). Coordinate if TID-370 lands first.
- **Tests:** extend `tests/unit/test_coop_battle_state.gd` (or a new
  `test_team_battle_state.gd`) for team targeting, per-team win/loss, turn rotation across
  4 players on 2 teams, `to_dict`/`from_dict` with `team_battle` + `team` fields. A
  `tests/net_team_pvp_smoke.gd` loopback (4 peers) if practical (mirror `net_pvp_smoke.gd`).
- **Docs:** update `docs/agent/multiplayer-coop.md` (new "Team Duels" subsection under PvP)
  and the GID-099 engine notes if `GameState` API changes.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
