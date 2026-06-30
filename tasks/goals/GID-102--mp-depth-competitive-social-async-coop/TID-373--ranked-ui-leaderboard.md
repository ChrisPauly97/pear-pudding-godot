# TID-373: Ranked queue UI + season leaderboard panel

**Goal:** GID-102
**Type:** agent
**Status:** done
**Depends On:** TID-370

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

TID-370 adds the persistent rating + derived leaderboard data. This task surfaces it: a
**leaderboard panel** ranking the session's players, a **rating display** in the roster /
result UI, and a lightweight **"ranked duel"** opt-in so a duel counts toward rating
explicitly (vs a casual/friendly duel that does not).

## Research Notes

- **UI pattern — `scenes/ui/BaseOverlay.gd`.** All overlays extend `BaseOverlay` (or are
  instantiated `.new()` like `MultiplayerLobbyScene` / `SettingsScene`); they are
  viewport-relative and rebuilt on resize (see CLAUDE.md "UI Sizing"). The session roster
  panel already exists in WorldScene (`_build_coop_roster` / `_refresh_coop_roster`,
  `multiplayer-coop.md` → "Session roster"). Add a **rating column / badge** there, and a
  separate full **Leaderboard overlay** opened from the lobby or a HUD button.
- **Data source.** Read `SessionState.get_leaderboard(limit)` (added in TID-370) via the open
  `SessionStore` on the authority. A **client** does not hold the full roster ratings — so
  the authority must push a leaderboard snapshot: add `NetSync.recv_leaderboard(rows: Array)`
  (reliable, authority → all) broadcast on session join and after each duel end, plus an
  on-demand `submit_leaderboard_request()` (client → authority). Mirror the late-join snapshot
  pattern used for party bounties (`recv_party_bounties_snapshot`, see
  `multiplayer-coop.md` → "Late-join snapshot").
- **Ranked vs casual.** Add a "Ranked" toggle to the challenge flow (alongside the existing
  ante toggle from TID-368). A casual/friendly duel sets a flag so TID-370's rating update is
  skipped. Reuse `GameState.friendly_duel` if it already gates rewards (grep — TID-368 notes
  it exists). Thread the flag through `enter_pvp_battle` → `_on_pvp_battle_ended_coop`.
- **Result UI — `scenes/battle/BattleResultUI.gd`.** `show_pvp_result(did_win, coins_delta)`
  exists (TID-368). Add an optional rating-delta line ("+18 rating" gold / "−14 rating" red)
  shown only for ranked duels.
- **Mobile/desktop parity** (CLAUDE.md): the leaderboard + ranked toggle need touch targets,
  not just keys.
- **Tests:** mostly UI (lighter test burden). If a `recv_leaderboard` snapshot helper is
  added as a pure encode/decode, unit-test it. Otherwise a smoke check that the authority
  broadcasts the snapshot on duel end.
- **Docs:** update `docs/agent/multiplayer-coop.md` (ranked UI subsection; new RPCs in the
  RPC table).

## Plan

**Dependency note:** TID-370 (PvP rating model) landed on a sibling worktree branch
(`claude/work-task-gid-102-4a4yfn`, commit `e2a2db2`) that also stacks two unrelated
later tasks (TID-371 2v2 duels, TID-372 reconnect-into-battle) which are out of scope
here. Cherry-picked only `e2a2db2` onto this branch so `SessionState.get_leaderboard`,
`pvp_rating`/`pvp_games`, and `RatingMath` are available without pulling in unrelated work.

**1. Wire format.** `SessionState.get_leaderboard(limit)` already returns
`Array[Dictionary]` of JSON-primitive rows (`{token, name, rating, games, wins,
losses}`) — same situation as `recv_party_bounties_snapshot(bounties: Array)`. No
dedicated pure encode/decode helper needed; send the Array directly.

**2. New RPCs on `scenes/world/NetSync.gd`** (mirrors the party-bounty RPC pair):
- `recv_leaderboard(rows: Array)` — reliable, authority → one or all peers.
- `submit_leaderboard_request()` — reliable, client → authority (on-demand refresh,
  e.g. opening the panel).
Broadcast points (host only): after `_update_pvp_ratings` runs in
`_on_pvp_battle_ended_coop`, and to a newly-identified peer in `_send_character_to_peer`
(mirroring the party-bounties-snapshot send already there).

**3. Client cache.** `WorldScene._leaderboard_rows: Array` holds the last-received rows;
`_leaderboard_lookup_by_token() -> Dictionary` derives a `token -> row` map on demand for
the roster badge and the overlay list.

**4. Roster rating badge.** Extend `_add_roster_row` (or its caller `_refresh_coop_roster`)
to append `" — <rating>"` (or "—" if not yet cached) looked up via
`MpProfile.get_token()` for the local row and `_remote_identities[pid]["token"]` for
remote rows.

**5. LeaderboardOverlay.** New `scenes/ui/LeaderboardOverlay.gd`, `extends "res://scenes/ui/BaseOverlay.gd"`
(matches the `SettingsScene`/`MultiplayerLobbyScene` convention — both extend BaseOverlay
by path string and are instantiated via `.new()`, not packed `.tscn` scenes). Lists cached
rows: rank, name, rating, W/L, refreshed on `recv_leaderboard`. Opened via a new HUD
button (mirrors the existing `_emote_btn`/`_spectate_btn` pattern — `Button.pressed`,
viewport-relative size, no separate keybind needed since those buttons don't have one
either and a touch/click target is sufficient for both desktop and mobile parity).
Sends `submit_leaderboard_request()` on open for a fresh snapshot.

**6. Ranked vs casual flag — `GameState.ranked: bool` (NEW field, not `friendly_duel`).**
Researched `friendly_duel` first: it is the **single-player NPC wager-duel** feature
(`BattleScene.gd` line ~287, set when `duel_wager > 0` on the NPC-duel path) — it
disables capture-tracking/draw-card/extra-mana companion bonuses and is wired through
`SceneManager.enter_friendly_duel`-style single-player flow. It is structurally and
semantically unrelated to co-op `_pvp` battles (which use `pvp_ante_coins`/`_pvp` and
never touch `friendly_duel`). Reusing it for "this PvP duel doesn't move rating" would
conflate two different game modes and risk disabling unrelated companion logic for real
PvP duels. Decision: add a dedicated `GameState.ranked: bool = false` field
(serialized in `to_dict`/`from_dict` like `coop_battle`), defaulting to `false` so
existing unwagered/wagered duels stay casual unless the challenger opts in.

**7. Ranked toggle UI.** A small `Button` (`toggle_mode = true`, viewport-relative size)
next to the existing `_challenge_btn` ("Challenge to Battle"), labelled "Ranked: OFF/ON".
Its state (`_ranked_toggle_on: bool`) is read by `_request_challenge()` /
`_accept_challenge()` and threaded through the existing challenge RPCs is unnecessary
because `request_battle`/`respond_battle` already carry no flags today; instead the
flag is threaded the same way `ante_coins` is for wagers: `_enter_pvp(opponent_deck)`
already exists for the **unwagered** flow, so it gains a `ranked: bool` parameter that
flows into `SceneManager.enter_pvp_battle(local_idx, opponent_deck, ante_coins, ranked)`.
The wagered flow (`_enter_pvp_wagered`) is left **not ranked** in this task — wager and
ranked are orthogonal but combining them is extra surface; out of scope, noted as a
possible follow-up rather than silently dropped.

**8. Threading through SceneManager → BattleScene → GameState.** `enter_pvp_battle`
gains a `ranked: bool = false` 4th parameter (mirrors how `ante_coins` was added as the
3rd), sets `_battle_overlay.set("pvp_ranked", ranked)`. `BattleScene.gd` gets
`var pvp_ranked: bool = false`, and sets `_state.ranked = pvp_ranked` at the same place
`duel_wager` sets `_state.wager_coins` (PvP branch, not the NPC-duel branch).
`_on_pvp_battle_ended_coop` reads `did the battle ranked?` — simplest correct read is to
gate on a WorldScene-side flag captured at challenge-accept time (`_pvp_ranked: bool`,
set alongside `_pvp_ante_peer1` in `_enter_pvp`/`_enter_pvp_wagered`) since `_state` is
inside BattleScene and WorldScene is detached/reattached around the battle — mirrors
exactly how `_pvp_ante_coins` already crosses that boundary today.

**9. Rating-delta display — scope decision.** Confirmed the sequencing problem described
in the task brief: `BattleScene._finish_pvp` calls `_result_ui.show_pvp_result(...)`
*before* `GameBus.pvp_battle_ended` fires, but `_update_pvp_ratings` (the only place that
computes a delta) runs *after* that signal fires, inside `WorldScene._on_pvp_battle_ended_coop`
— and only on the host. Forcing a same-screen number would require either (a) the host
precomputing the delta before the battle ends and threading it through the end-of-battle
RPC payload (`pvp_ended`), which both peers would need to trust without re-deriving it
(integrity smell — a client could in principle fake a delta), or (b) restructuring the
battle-end flow so rating update happens before the result screen shows, which inverts
the "world is authoritative, battle is ephemeral" ordering the rest of co-op relies on.
Both are real architecture changes outside this task's footprint. Decision: keep
`BattleResultUI.show_pvp_result` exactly as-is (no rating line). After
`_update_pvp_ratings` computes deltas on the host, emit
`GameBus.hud_message_requested.emit("+%d rating" / "%d rating")` to both combatants
(host emits locally + the existing `_net_sync` channel doesn't have a generic "toast"
RPC, so the host sends its own delta via `hud_message_requested` locally and the
opponent's delta is delivered by extending `recv_leaderboard`'s broadcast — simpler:
host computes both, shows its own toast locally, and unicasts the opponent's delta via
a tiny new field tacked onto nothing extra — see Changes Made for the exact mechanism
chosen during Build). This is the pragmatic right call per the task brief, not a
corner cut: it reuses the existing low-risk end-of-action toast pattern instead of
touching the authoritative battle-end sequencing.

**10. Tests.** No new pure wire-format helper (per point 1), so no dedicated unit test
file. Add a lightweight unit test for the one new pure-ish piece of logic introduced:
none strictly required, but a smoke-level check that `_update_pvp_ratings` + leaderboard
broadcast wiring doesn't regress is valuable given time. Will add cases to
`tests/unit/test_session_state.gd`-adjacent if a clean pure surface emerges during
Build; otherwise rely on the full headless import + existing 1700+ test suite staying
green as the safety net (per task brief, lighter test burden expected for UI-heavy work).

## Changes Made

**Dependency setup:**
- Cherry-picked `e2a2db2` (TID-370, PvP rating model) onto this branch from
  `claude/work-task-gid-102-4a4yfn` — only that one commit, not the two unrelated
  later commits (TID-371 2v2 duels, TID-372 reconnect-into-battle) stacked on the
  same sibling branch.

**Wire format / RPCs (`scenes/world/NetSync.gd`):**
- `recv_leaderboard(rows: Array)` — authority → one/all peers, reliable. Sends
  `SessionState.get_leaderboard()` rows directly (already JSON-primitive dicts), no
  dedicated encode/decode helper needed (mirrors `recv_party_bounties_snapshot`).
- `submit_leaderboard_request()` — client → authority, reliable, for on-demand refresh.
- `recv_rating_delta(delta: int)` — authority → the non-host combatant of a ranked
  duel, reliable. Carries the opponent's own rating swing for the post-battle toast
  (see rating-delta scope decision below).
- `request_battle` / `respond_battle` gained a trailing `ranked: bool = false`
  parameter (defaulted for back-compat) so the challenge handshake agrees on the
  ranked flag before either peer calls `enter_pvp_battle`.

**Ranked flag plumbing:**
- `game_logic/battle/GameState.gd`: new `ranked: bool = false` field, serialized in
  `to_dict`/`from_dict` (same pattern as `coop_battle`). Deliberately **not** reusing
  `friendly_duel` — see scope decision below.
- `scenes/battle/BattleScene.gd`: new `pvp_ranked: bool = false` var, set by
  SceneManager before `_ready`; `_setup_pvp_battle()` copies it into `_state.ranked`.
- `autoloads/SceneManager.gd`: `enter_pvp_battle(local_player_idx, opponent_deck,
  ante_coins = 0, ranked = false)` gained the trailing `ranked` parameter, threaded
  into `_battle_overlay.set("pvp_ranked", ranked)`.
- `scenes/world/WorldScene.gd`: `_enter_pvp(opponent_deck, ranked = false)` now
  accepts and forwards the flag; `_request_challenge`/`_on_battle_requested`/
  `_accept_challenge`/`_decline_challenge`/`_on_battle_responded` thread it through
  the handshake (new `_pending_challenge_ranked` var holds the incoming flag while
  the accept/decline panel is open). `_enter_pvp_wagered` intentionally still calls
  `enter_pvp_battle` with the `ranked` default (`false`) — wagered + ranked combined
  is explicitly out of scope for this task (see Plan point 7).
- `_pvp_ranked: bool` (WorldScene) captures the agreed flag for the active duel
  (mirrors how `_pvp_ante_coins` already crosses the WorldScene/BattleScene boundary)
  and gates the TID-370 `_update_pvp_ratings` call in `_on_pvp_battle_ended_coop` —
  casual duels never touch rating.

**Ranked toggle UI:** new `_ranked_toggle_btn` (`toggle_mode`, viewport-relative,
labelled "Ranked: OFF"/"Ranked: ON") created alongside the existing "Challenge to
Battle" button in `_ensure_challenge_button()`, shown/hidden together by proximity in
`_update_challenge_proximity()`. The incoming challenge accept panel
(`_show_challenge_accept_panel`) now shows "...RANKED card battle!" in gold when the
challenge is ranked.

**Roster rating badge:** `_refresh_coop_roster()` / `_add_roster_row` now append a
`[rating]` badge (or `[—]` before the first leaderboard snapshot) next to each name,
looked up via a new `_leaderboard_lookup_by_token()` / `_rating_badge_for_token()`
pair built from the cached `_leaderboard_rows: Array`.

**Leaderboard panel:** new `scenes/ui/LeaderboardOverlay.gd` (+ `.gd.uid`), extends
`res://scenes/ui/BaseOverlay.gd` by path string and is instantiated via `.new()` —
confirmed this is the actual convention used by both `SettingsScene` and
`MultiplayerLobbyScene` before picking it (the task brief asked to check). Lists
cached rows (rank, name, rating, W/L), rebuilt on `NOTIFICATION_RESIZED` and whenever
`refresh_rows()` is called. New always-visible "Leaderboard" HUD button
(`_leaderboard_btn`, top-left, viewport-relative) opens/closes it via
`_toggle_leaderboard_overlay()`, which requests a fresh snapshot on open (host computes
locally; client sends `submit_leaderboard_request`).

**Broadcast points (host only):**
- `_send_character_to_peer` (late-join handshake): unicasts the current leaderboard
  to a newly-identified peer, alongside the existing character + party-bounty sends.
- `_on_pvp_battle_ended_coop`: after a **ranked** duel's `_update_pvp_ratings` runs,
  calls the new `_broadcast_leaderboard()` to push a fresh snapshot to all peers.
- `_on_leaderboard_request_submitted`: answers an on-demand client refresh by
  unicasting back to the requester.

**Rating-delta display:** kept `BattleResultUI.show_pvp_result` unchanged (no rating
line) per the scope decision below. After `_update_pvp_ratings` computes both
combatants' deltas (host-only, ranked duels only), the host shows its own delta as a
`GameBus.hud_message_requested` toast ("+18 rating" / "-14 rating") and unicasts the
opponent's delta via the new `recv_rating_delta` RPC, which the opponent's
`_on_rating_delta_received` also surfaces as a toast. Both fire once the player is
back in the world (after the result screen's Continue button), not on the result
screen itself.

**Tests:**
- `tests/net_leaderboard_smoke.gd` (new, on-demand `SceneTree` smoke test, mirrors
  `net_world_sync_smoke.gd`'s structure): real ENet loopback proves `recv_leaderboard`
  reaches the client with the exact `SessionState.get_leaderboard()` shape and
  rating-desc ordering, and `submit_leaderboard_request` reaches the authority.
  `godot --headless --path . -s tests/net_leaderboard_smoke.gd` → PASS.
- No new pure-unit test file: the row shape is already covered by TID-370's
  `tests/unit/test_session_state.gd` (`test_leaderboard_sorts_by_rating_desc` /
  `test_leaderboard_respects_limit`), and the new RPCs send that data directly with
  no additional encode/decode logic to test in isolation (per the task's own guidance
  for this case).

**Validation:** headless import (`godot --headless --editor --quit`) clean (no Parse
Error / Compile Error / Failed to load script lines). Full suite
(`godot --headless --path . -s tests/runner.gd`): **1712 passed, 0 failed, 1 pending**
— unchanged from before this task's changes. Re-ran `net_pvp_smoke.gd`,
`net_pvp_client_smoke.gd`, `net_session_smoke.gd`, `net_coop_npeer_smoke.gd`,
`net_coop_smoke.gd`, `net_rehost_smoke.gd`, and the new `net_leaderboard_smoke.gd` —
all PASS.

**Backlog filed:** `tasks/backlog/BID-026--wager-challenge-button-missing.md` — found
`WorldScene._request_wager_challenge(ante_coins)` has zero callers anywhere in the
codebase (no HUD button wires to it), so the wagered-duel-with-custom-ante flow
described in `multiplayer-coop.md` ("Rewards & end states") is currently only
reachable as the *responder* (accepting `request_battle_wager`), never as the
*initiator* with a player-chosen ante. Pre-existing gap, unrelated to this task's
scope — logged rather than fixed opportunistically given the size of a proper
ante-amount-picker UI.

## Documentation Updates

Updated `docs/agent/multiplayer-coop.md`:
- Added a new **"Ranked UI & Leaderboard (GID-102 / TID-373)"** subsection directly
  after the existing "Champion record (GID-101 / TID-368)" / before "Spectating a
  duel" content, inside the PvP Card Battles section — covering the leaderboard cache
  + broadcast points, roster rating badge, the `GameState.ranked` vs `friendly_duel`
  distinction, the ranked toggle UI, and the rating-delta toast mechanism + why it
  can't be same-screen.
- Added the three new RPCs (`recv_leaderboard`, `submit_leaderboard_request`,
  `recv_rating_delta`) to the existing PvP RPC documentation.
- Added `tests/net_leaderboard_smoke.gd` to the Tests table.
- Left the "Limitations / Out of Scope" PvP bullet and all surrounding content
  untouched — edited surgically since TID-374/TID-375 are editing this same file in
  parallel worktrees.
