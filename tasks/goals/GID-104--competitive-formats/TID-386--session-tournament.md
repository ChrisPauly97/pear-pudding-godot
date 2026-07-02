# TID-386: Session Tournament Mode

**Goal:** GID-104
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

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

**Bracket algorithm: round-robin (every player plays every other player once).**
Justification: with only 3–4 session players, single-elimination gives a loser
just one match before they're stuck spectating for the rest of the event — a
poor "marquee event" experience for such a small group — and 3 players needs a
bye (awkward with no clean bye target). Round-robin instead guarantees every
participant plays `n-1` matches (3 for a 4-player tournament, 2 for 3-player),
needs no byes, and its schedule is a flat list of pairs rather than a tree, which
keeps authority-side scheduling/broadcast/tests simple. Winner = most wins;
ties are broken by head-to-head result (2-way tie) or lowest participant index
(3+-way tie or an unresolvable head-to-head) — fully deterministic so every
peer's independently-rendered bracket panel agrees.

**Pure logic — `game_logic/net/TournamentSync.gd`** (mirrors `RatingMath.gd`):
`build_round_robin_matches(n)`, `new_bracket(tokens, names, ante)`,
`get_current_match(bracket)`, `record_match_result(bracket, winner_idx)`
(advances `current_match`, marks `finished` + resolves `winner_idx` once all
matches are done), `wins_by_participant`, `head_to_head_winner`,
`compute_winner`, `is_finished`, `payout_pot(ante, n)`, and
`encode_bracket`/`decode_bracket` (defensive, garbage-tolerant, mirrors
`AvatarSync`/`PlayerIdentity`). Fully unit-tested in
`tests/unit/test_tournament_sync.gd`.

**Match execution — reuse the existing PvP/referee plumbing, no new BattleScene
code.** A round-robin bracket for 3–4 players has matches that do NOT include
the host (e.g. two clients playing each other while the host organizes). The
codebase already has exactly this shape solved for the dedicated-server referee
mode (GID-097): `SceneManager.enter_pvp_referee(deck_a, deck_b, peer_a, peer_b,
token_a, token_b)` builds a canonical `GameState` with `_local_player_idx = -1`
and `_is_pvp_host()` is `multiplayer.is_server()` (true for the *listen-server*
host too, not just a dedicated server) — so the listen-server host can referee
a match it isn't playing in with zero BattleScene changes. For matches where
the host *is* a participant, the existing `enter_pvp_battle(0, ...)` +
`notify_pvp_start(1, ...)` pair (already used by the dedicated-server relay
path) is reused verbatim.

**Learning the winner of a referee'd match.** `BattleScene._finish_pvp` only
ever emits `GameBus.pvp_battle_ended.emit(false)` for `_local_player_idx < 0`
(referee) — the boolean can't carry which of the two *other* peers won. Add one
new signal, `GameBus.pvp_referee_match_ended(winner_idx: int)`, emitted from
`_pvp_check_game_over` and `_apply_remote_surrender` only in the
`_local_player_idx < 0` branch (2 call sites, ~4 lines total) — additive, never
fires for any existing non-referee path, so ordinary 2-player PvP/team
duels/co-op PvE are untouched. GID-097's dedicated-server relay path also
starts firing it now (harmless — nothing listens to it unless a tournament is
active).

**Tournament orchestration — new WorldScene section, isolated by a
`_tournament_active` guard.** Host presses a new "Tournament" HUD button
(visible only for `NetworkManager.is_host()` with 2–3 connected peers, mirrors
the "Team Duel" button precedent exactly) → `_start_tournament()` resolves all
connected peers' tokens/decks (reusing `_team_deck_for_peer`, no new RPC round
trip), deducts a fixed `TOURNAMENT_ANTE_COINS` ante from every participant
(host locally via `SaveManager.add_coins`, each client via a new
`notify_tournament_start(bracket, ante)` RPC that does the same locally —
mirrors the existing ante-wager flow), builds the bracket via
`TournamentSync.new_bracket`, and starts the first match.

Each match: the host broadcasts the updated bracket
(`recv_tournament_update`), tells the two combatants their role via the
existing `notify_pvp_start` RPC + `enter_pvp_battle`/`enter_pvp_referee`, and
tells every *other* connected peer to auto-spectate via a new
`notify_tournament_spectate()` RPC (→ `SceneManager.enter_pvp_spectator()`,
zero manual button press) — plus the existing `recv_pvp_active` broadcast so
the pre-existing spectate HUD state stays consistent for any late joiner.

Because `WorldScene` detaches from the tree for the whole match (same as any
PvP battle) and `NetSync` is freed while detached (mirrors the existing
`_pvp_ended_pending_broadcast` pattern), match results are captured into a
`_tournament_pending_result` dict from `_on_pvp_battle_ended_coop` (host-
participant matches, using `did_win`) or the new `_on_pvp_referee_match_ended`
handler (referee matches, using `winner_idx`) — both short-circuit out of the
existing champion-record/rating/wager logic in `_on_pvp_battle_ended_coop` via
an `if _tournament_active: ...; return` guard at the top, so tournament matches
never touch the unrelated PvP champion-record/ELO/ante-wager systems. Once
`WorldScene` re-enters the tree, a new `_tick_tournament()` call in the
existing `_process()` (`if _coop_active:` block, host-only) drains the pending
result, calls `TournamentSync.record_match_result`, broadcasts the bracket, and
either starts the next match or (bracket finished) pays out the pot.

**Payout.** `TournamentSync.new_bracket` precomputes `pot = ante * n`. On
finish, if the winner is the host, `SaveManager.add_coins(pot)`; otherwise a
direct `SessionStore` member-record write (`rec["coins"] += pot;
st.update_member(...); SessionStore.mark_dirty()`) — the same
direct-SessionState-write pattern `_grant_chest_loot_to_token` already uses for
a winner who may not be the local player. No ranked-ELO integration in v1
(the task marks it optional; skipping it avoids entangling tournament matches
with the unrelated champion/rating systems — documented decision).

**Bracket HUD panel.** A small always-visible-during-tournament panel (mirrors
`_build_party_bounty_panel`/`_refresh_party_bounty_panel` structurally),
positioned top-right (bounty/roster/chat already occupy top-left), listing each
match's two names + result (or "vs" while pending/in-progress) and a highlight
on the current match. Rebuilt on every `recv_tournament_update` (all peers) and
on `notify_tournament_start` (bracket's initial shape). Mobile + desktop parity
throughout — everything is a tap/click target, sized as a fraction of the
viewport per CLAUDE.md's UI-sizing rule.

**New files:** `game_logic/net/TournamentSync.gd` (+ `.uid`),
`tests/unit/test_tournament_sync.gd` (+ `.uid`).
**Touched shared files (kept minimal):** `autoloads/GameBus.gd` (+1 signal),
`scenes/battle/BattleScene.gd` (+2 small emit sites, no behavior change for
existing paths), `scenes/world/NetSync.gd` (+3 RPCs, additive),
`scenes/world/WorldScene.gd` (+1 new section: button, panel, orchestration —
no existing function bodies are rewritten, only a handful of one-line hooks
added to `_ready`/`_setup_coop`/`_process`/`_enter_tree`/
`_on_pvp_battle_ended_coop`). `autoloads/SceneManager.gd` is **not** touched —
`enter_pvp_battle`/`enter_pvp_referee`/`enter_pvp_spectator` already have every
parameter the tournament needs.

## Changes Made

- **New `game_logic/net/TournamentSync.gd`** (+ `.uid`) — pure round-robin bracket
  scheduling, standings (wins / head-to-head / deterministic tie-breaks), pot math,
  and garbage-tolerant `encode_bracket`/`decode_bracket` wire helpers. Fully covered
  by new `tests/unit/test_tournament_sync.gd` (+ `.uid`).
- **`autoloads/GameBus.gd`** — new `pvp_referee_match_ended(winner_idx)` signal: a
  referee (`_local_player_idx < 0`) can't learn the winner from `pvp_battle_ended`'s
  bool, so the referee branch emits the canonical winner index directly.
- **`scenes/battle/BattleScene.gd`** — two additive emit sites for that signal
  (`_pvp_check_game_over`, `_apply_remote_surrender`), referee branch only; no
  behavior change for any existing path.
- **`scenes/world/NetSync.gd`** — three additive reliable RPCs:
  `notify_tournament_start(bracket, ante)`, `recv_tournament_update(bracket)`,
  `notify_tournament_spectate()`.
- **`scenes/world/WorldScene.gd`** — new tournament section (host-only "Tournament"
  button gated on listen-server host + 2–3 clients; `_start_tournament` participant/
  deck/ante resolution; `_start_current_tournament_match` routing host matches through
  `enter_pvp_battle` and client-vs-client matches through the GID-097
  `enter_pvp_referee` path; auto-spectate fan-out; `_tick_tournament` result drain +
  4s inter-match countdown; pot payout to the winner via `SaveManager.add_coins`
  (host) or a direct SessionState member-record write (remote winner); bracket HUD
  panel on all peers mirroring the party-bounty panel; disconnect abort + session-end
  reset). Tournament matches short-circuit out of the champion-record/ELO/wager logic
  in `_on_pvp_battle_ended_coop` via the `_tournament_active` guard.
- All new code is reachable only through `_setup_coop` / `NetworkManager.is_active()`
  guards — single-player is byte-for-byte unaffected.
- Godot binary unavailable in this environment (network policy): headless import and
  test run could not be executed locally; the diff was hand-audited against every
  CLAUDE.md parse pitfall (tabs-only indentation, no Variant `:=` inference, no `//`,
  no 2-arg `Object.get()`, preloads for all cross-file refs, typed-array `.assign()`).
  CI runs the headless import before export.

## Documentation Updates

- `docs/agent/multiplayer-coop.md` — new "Session Tournaments (GID-104 / TID-386)"
  section: bracket algorithm + tie-breaks, ante/pot flow, match routing (host vs
  referee'd matches), the `pvp_referee_match_ended` signal rationale, RPC table,
  and v1 edge cases (abort-on-disconnect without refunds, no client ante pre-check,
  casual-only).
