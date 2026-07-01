# TID-379: Global leaderboards (Spire + co-op clears)

**Goal:** GID-102
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Single-player has score-y modes — the **Endless Spire** roguelike draft (GID-038) and co-op
**joint boss clears** (GID-099). This task records best results to authority-persisted
leaderboards so the party/session can compete on more than just PvP rating (TID-370 covers
PvP; this covers PvE achievement).

## Research Notes

- **What to rank.**
  - **Endless Spire:** highest floor / longest run per player (GID-038 — grep
    `Spire` in `autoloads`/`scenes` for the run-end signal + the score it already computes).
  - **Co-op boss clears:** fastest clear / highest party size / boss tier defeated (GID-099 —
    `coop_battle_ended` payload + `CoopBattleScaling` tier). Record per-party or per-player.
- **Storage — `game_logic/net/SessionState.gd`.** Add `leaderboards: Dictionary` shaped
  `{spire: Array, coop_clears: Array}` where each entry is `{token, name, value, day}`,
  authority-owned + persisted, kept sorted + capped (top N). Bump
  `CURRENT_SESSION_VERSION` (after the other Phase tasks) with a migration adding the field.
  Add a `SessionState.record_leaderboard(board, token, name, value)` that inserts/updates the
  player's best and re-sorts.
- **Submission path.** Spire and co-op battles already end with signals/handlers
  (`GameBus.coop_pve_battle_ended`, the Spire run-end). On run/clear end:
  - **Authority:** call `SessionState.record_leaderboard` directly via `SessionStore`.
  - **Client:** `NetSync.submit_leaderboard_score(board, value)` (reliable) → authority
    records + broadcasts. (Spire is single-player, so a co-op session may not be active during
    a Spire run — only submit when `NetworkManager.is_active()`; otherwise it's a local-only
    best. Decide in Plan whether to also keep a device-local best in `MpProfile` for offline.)
- **Broadcast/snapshot.** `NetSync.recv_leaderboards(snapshot)` (authority → all, reliable)
  on join + after each update; reuse the party-bounties late-join snapshot pattern.
- **UI.** A Leaderboards overlay (BaseOverlay) with tabs (Spire / Co-op clears / and link to
  the PvP rating board from TID-373 if it lands — consider one unified "Rankings" overlay).
  Viewport-relative, mobile parity.
- **Note vs TID-373.** TID-373 builds the *PvP rating* board; this builds *PvE* boards. If
  both land, unify them into one "Rankings" overlay with tabs to avoid two near-identical
  panels — coordinate ordering.
- **Tests:** extend `test_session_state.gd` (leaderboards field default, record/sort/cap,
  round-trip, migration). Pure `record_leaderboard` sort/cap unit-tested.
- **Docs:** update `docs/agent/multiplayer-coop.md` (new "Leaderboards" subsection + RPC +
  Tests tables); cross-link the GID-038 Spire doc if one exists.

## Plan

**Naming (no collision with TID-373):** all new symbols use a `_pve_`/`pve` prefix:
- `SessionState.leaderboards: Dictionary` `{spire: Array, coop_clears: Array}`, entries
  `{token, name, value, day}`.
- `SessionState.record_pve_score(board, token, name, value, day) -> void` — pure,
  insert-or-update-if-better, sort desc by value, cap to `PVE_LEADERBOARD_CAP = 20`.
- `SessionState.get_pve_leaderboard(board, limit=20) -> Array` — read accessor (mirrors
  `get_leaderboard()` for PvP), used by the authority to build the broadcast snapshot.
- `NetSync.submit_pve_leaderboard_score(board: String, value: int)` (client → authority,
  reliable).
- `NetSync.recv_pve_leaderboards(snapshot: Dictionary)` (authority → all, reliable). Snapshot
  shape: `{spire: Array, coop_clears: Array}` (both boards sent together — simpler than two
  separate RPCs, mirrors how `recv_party_bounties_snapshot` sends the whole list at once).
- `WorldScene._pve_leaderboards: Dictionary` cache (defaults `{spire: [], coop_clears: []}`),
  `_broadcast_pve_leaderboards(target_peer := 0)`, `_on_pve_leaderboards_received(snapshot)`,
  `_on_pve_leaderboard_score_submitted(sender, board, value)`, `_submit_pve_score(board, value)`
  (routes to direct-record-on-host or RPC-to-host-on-client).
- Version bump: `SessionState.CURRENT_SESSION_VERSION` 5 → 6 (renumbered during
  integration; TID-376's party stash claimed v5 first), migration backfills
  `leaderboards = {spire: [], coop_clears: []}` if missing.

**Submission hooks:**
- Spire: connect `GameBus.spire_run_ended(stats)` in WorldScene (new handler
  `_on_spire_run_ended`, connected in `_setup_coop` since Spire runs happen while the world
  is loaded and NetworkManager may or may not be active). Only submits when
  `NetworkManager.is_active()` — guarded per task notes; otherwise purely local (Spire
  already has its own local best via `SaveManager.spire_best_floor`, so no MpProfile
  duplication needed — **decision: skip device-local MpProfile best**, per task's default,
  since `SaveManager.spire_best_floor` already covers the fully-offline single-player case
  and adding a second offline-best store would duplicate that source of truth). Value =
  `floors_cleared`. name/token = local `MpProfile`.
- Co-op clears: connect `GameBus.coop_pve_battle_ended(did_win)` in WorldScene (permanent
  connection like `_on_pvp_battle_ended_coop`/`_on_team_battle_ended_coop`, since WorldScene
  detaches during battle). On `did_win == true` and `NetworkManager.is_active()`, submit
  value = `SceneManager` co-op boss tier if available, else fall back to connected-peer
  count (party size) — value chosen as `boss tier defeated` when `_coop_pve_boss_tier` is
  captured (new small WorldScene field set right before `enter_coop_pve_battle`-style
  triggers are — actually not currently called from WorldScene directly, so simplest robust
  proxy: **value = party size at battle end** = `multiplayer.get_peers().size() + 1`,
  documented as a v1 simplification since fastest-clear timing isn't tracked anywhere yet
  and boss tier isn't threaded to WorldScene). Keep this simple and pure — no new timing
  infra.
- **Authority path:** call `SessionState.record_pve_score` directly on `SessionStore.get_state()`,
  mark dirty, broadcast.
- **Client path:** `_net_sync.rpc_id(1, "submit_pve_leaderboard_score", board, value)`.

**Broadcast/snapshot:** `_send_character_to_peer` gets one more line unicasting
`recv_pve_leaderboards` alongside the existing character/party-bounty/leaderboard sends
(late-join). Also broadcast after every `record_pve_score` write.

**UI — extend LeaderboardOverlay with tabs:** add a `TabBar`-style row of 3 buttons
("Ranked" / "Spire" / "Co-op Clears") above the existing header row; `_active_tab: int`
picks which cached array renders (`_rows_cache` becomes tab-specific: keep the existing
`_rows_cache` for Ranked, add `_spire_cache`/`_coop_cache`; a single `_render_rows()` reads
from whichever is active and adapts columns: Ranked shows Rating/W-L, Spire/Co-op show
Value/Day). `refresh_rows(rows)` stays for backward compat (Ranked tab); add
`refresh_pve_rows(spire_rows, coop_rows)` for the new boards. WorldScene calls both refreshers
whenever any snapshot arrives (rating or PvE) so the overlay always stays current regardless
of which tab is open.

**Tests:** extend `tests/unit/test_session_state.gd` with a new section: leaderboards default
empty dict with both keys, `record_pve_score` insert/update(own better score
overwrites)/update(worse score is a no-op)/sort-desc/cap-at-20, round trip, migration v5→v6
backfill (including tolerating a pre-existing `leaderboards` key untouched, and a garbage
non-dict `leaderboards` value falling back to defaults).

**Docs:** add a new "Leaderboards (GID-102 / TID-379)" sub-subsection to
`docs/agent/multiplayer-coop.md` right after the existing "Ranked UI & Leaderboard
(GID-102 / TID-373)" subsection, documenting the PvE boards, RPCs, unified-overlay-tabs
decision, and the offline-best / value-proxy decisions above.

**Backlog:** log the "co-op boss tier not threaded to WorldScene at battle-end" gap (the
value proxy is party-size, not boss-tier, because of this) as a new BID.

## Changes Made

**Note on branch state:** this worktree branched before TID-370/TID-373 (PvP rating +
ranked leaderboard UI) had merged, even though they were described as "already landed."
Fast-forward merged `worktree-agent-acf9c22232607c15c` (commits `be586ed` TID-370,
`a37f7cf` TID-373) into this branch first — clean fast-forward, no conflicts — so the
collision-avoidance naming instructions and the "extend, don't duplicate" UI guidance
were actually buildable as specified.

- **`game_logic/net/SessionState.gd`** — added `leaderboards: Dictionary` field
  (`{spire: [], coop_clears: []}` default), `PVE_LEADERBOARD_CAP = 20`,
  `record_pve_score(board, token, name, value, day=0)` (pure insert-or-update-if-better +
  sort-desc-by-value + cap), `get_pve_leaderboard(board, limit)`,
  `get_pve_leaderboards_snapshot()`, `_sanitized_leaderboards()` tolerant-fallback helper.
  Bumped `CURRENT_SESSION_VERSION` 5 → 6 (renumbered during integration) with a
  migration backfilling `leaderboards` when
  absent (existing values are left untouched); `to_dict`/`from_dict` round-trip the field.
- **`scenes/world/NetSync.gd`** — added `submit_pve_leaderboard_score(board, value)`
  (client → authority, reliable), `recv_pve_leaderboards(snapshot)` (authority → all,
  reliable), `submit_pve_leaderboard_request()` (client → authority, reliable). Distinct
  names from TID-373's `recv_leaderboard`/`submit_leaderboard_request` — no collision.
- **`scenes/world/WorldScene.gd`** —
  - New cache `_pve_leaderboards: Dictionary` (defaults `{spire: [], coop_clears: []}`).
  - Two **permanent** signal connections added in `_ready` (same "WorldScene detaches
    during battle" reasoning as the existing `pvp_battle_ended` connection):
    `GameBus.coop_pve_battle_ended.connect(_on_coop_pve_battle_ended_leaderboard)` and
    `GameBus.spire_run_ended.connect(_on_spire_run_ended_leaderboard)`.
  - `_on_spire_run_ended_leaderboard(stats)` — submits `floors_cleared` to the `"spire"`
    board only when `NetworkManager.is_active()`.
  - `_on_coop_pve_battle_ended_leaderboard(did_win)` — submits party size
    (`multiplayer.get_peers().size() + 1`) to `"coop_clears"` on a win, when
    `NetworkManager.is_active()`.
  - `_submit_pve_score(board, value)` — host records directly via `SessionStore` +
    broadcasts; client sends the new RPC.
  - `_on_pve_leaderboard_score_submitted(sender, board, value)` — host resolves the
    sender's token via the existing `_session_token_by_peer` map, records, broadcasts.
  - `_broadcast_pve_leaderboards(target_peer=0)`, `_on_pve_leaderboards_received(snapshot)`,
    `_on_pve_leaderboard_request_submitted(sender)` — mirror the TID-373 ranked-board
    broadcast/receive/request trio structurally.
  - `_send_character_to_peer` — added one line unicasting `recv_pve_leaderboards` to a
    newly-identified peer, alongside the existing character/party-bounty/ranked-leaderboard
    sends (late-join snapshot).
  - `_setup_session` — seeds `_pve_leaderboards` from the host's own `SessionStore` state on
    session adopt (mirrors the existing `_leaderboard_rows` seeding for TID-373).
  - `_toggle_leaderboard_overlay()` — now also requests/broadcasts the PvE snapshot and
    calls `refresh_pve_rows` on open, alongside the existing ranked-rating flow.
- **`scenes/ui/LeaderboardOverlay.gd`** — extended in place (not duplicated) with a
  3-button tab row (Ranked / Spire / Co-op Clears). `_active_tab` picks the rendered
  dataset; `refresh_rows(rows)` (pre-existing) still feeds Ranked; new
  `refresh_pve_rows(snapshot: Dictionary)` feeds Spire/Co-op from the
  `{spire, coop_clears}` shape. Header columns adapt per tab (Ranked: Rating/W-L;
  Spire/Co-op: Value/Day). Deviated from the Plan's sketch of
  `refresh_pve_rows(spire_rows, coop_rows)` (two array args) in favor of a single
  `snapshot: Dictionary` param — simpler 1:1 match with
  `SessionState.get_pve_leaderboards_snapshot()`'s return shape and the wire payload,
  no unpacking needed at either call site.
- **`tests/unit/test_session_state.gd`** — added 15 new tests covering: leaderboards
  default shape, `record_pve_score` insert/own-better-overwrites/worse-is-no-op/
  equal-is-no-op/sort-desc/cap-at-20/unknown-board-no-op/blank-token-no-op,
  `get_pve_leaderboard` limit, round-trip, snapshot shape, migration v6 backfill +
  preserves-existing-value + garbage-field tolerance.
- **`tasks/backlog/BID-031--coop-clear-value-lacks-boss-tier-and-timing.md`** — new
  backlog item documenting that boss tier / clear timing aren't threaded from
  BattleScene back to WorldScene, so the co-op-clears leaderboard value is currently
  a party-size proxy rather than a difficulty/speed-aware score.

**Version bump used:** `SessionState.CURRENT_SESSION_VERSION` 5 → **6** (renumbered
during integration; TID-376 claimed v5 for party stash first).

**RPC/variable names (confirmed no collision with TID-373):**
`submit_pve_leaderboard_score`, `recv_pve_leaderboards`, `submit_pve_leaderboard_request`
(NetSync); `_pve_leaderboards`, `_on_spire_run_ended_leaderboard`,
`_on_coop_pve_battle_ended_leaderboard`, `_submit_pve_score`,
`_on_pve_leaderboard_score_submitted`, `_broadcast_pve_leaderboards`,
`_on_pve_leaderboards_received`, `_on_pve_leaderboard_request_submitted` (WorldScene);
`leaderboards`, `record_pve_score`, `get_pve_leaderboard`,
`get_pve_leaderboards_snapshot`, `PVE_LEADERBOARD_CAP` (SessionState).

**Offline-best decision:** skipped a device-local `MpProfile` PvE best. Endless Spire's
fully-offline case is already covered by the pre-existing `SaveManager.spire_best_floor`
(drives the "New Record!" badge on `RunSummaryScene`); duplicating that into MpProfile
would only create a second source of truth for the same fact. Co-op clears have no
single-player/offline mode at all (co-op is required), so no offline-best question
applies there.

**Validation:**
- `godot --headless --editor --quit` → filtered grep for Parse/Compile/Failed-to-load
  errors: **empty** (clean).
- `godot --headless --path . -s tests/runner.gd` → **1727 passed, 0 failed, 1 pending**
  (the 1 pending is a pre-existing `test_world_event_manager` skip unrelated to this task).
  Note: this worktree's merged history doesn't include TID-374/375 (chat/friends), so the
  ~1772 baseline mentioned in the task instructions doesn't apply here; all tests present
  in this branch pass.

## Documentation Updates

- **`docs/agent/multiplayer-coop.md`** — added a new "### Leaderboards (GID-102 /
  TID-379)" sub-subsection immediately after the existing "### Ranked UI & Leaderboard
  (GID-102 / TID-373)" subsection (surgical insert, no other reflow), covering: storage
  shape + `record_pve_score` semantics + version bump, the two permanent submission
  hooks (Spire/co-op clears) and their guards, the offline-best decision, the
  authority-records-then-broadcasts routing, the late-join/on-demand snapshot RPCs, and
  the tabs-not-a-second-panel UI decision.
  Also updated the `test_session_state.gd` row in the "## Tests" table (single-line
  edit) to mention the new PvE leaderboard coverage and corrected case count (45).
