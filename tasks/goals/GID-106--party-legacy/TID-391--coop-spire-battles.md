# TID-391: Co-op Spire — Joint Floor Battles & Leaderboard

**Goal:** GID-106
**Type:** agent
**Status:** done (headless import + test run unverified in-sandbox — see Validation note)
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

**Verified against actual code (not just Research Notes):**

- Spire floors are plain `WorldScene` maps named `spire_floor_<floor>_<seed>`
  (`SpireFloorGen.generate`), each with exactly **one** enemy entity, fixed id
  `"spire_enemy"`. There is no separate `SpireScene`. Single-player routing:
  normal `EnemyNPC.engage()` → `GameBus.enemy_engaged` → `SceneManager._on_enemy_engaged`
  (`autoloads/SceneManager.gd:416`) starts a solo `BattleScene`; on win,
  `SceneManager._on_battle_won` (`:943`) shows the draft overlay (`_show_spire_draft`);
  the picked card is appended and the **player walks through the arena's exit door**
  (`flag_key` = `cleared_flag_for`), which special-cases `SceneManager.exit_map()`
  (`:355`) to call `_advance_spire_floor()` (loads the next floor map) instead of
  popping the map stack.
- TID-390 already built: `SceneManager._coop_spire_run` (transient run state: floor,
  seed, shared_deck, picker_order/idx), `enter_spire_coop`/`add_coop_drafted_card`/
  `advance_coop_spire_picker`/`advance_coop_spire_floor`/`end_coop_spire_run`/
  `set_coop_spire_run_mirror`; `WorldScene._start_coop_spire()` (Party-panel entry,
  host-only, transitions to floor 1); a **complete** draft-orchestration engine
  (`_start_coop_spire_draft`, `_on_spire_draft_start_received`,
  `_submit_coop_spire_draft_choice`, `_on_spire_draft_choice_submitted`,
  `_tick_coop_spire_draft`, `_resolve_coop_spire_draft`, `_on_spire_draft_choice_received`)
  — confirmed via grep that `_start_coop_spire_draft` has **zero callers**, and
  `_resolve_coop_spire_draft` never advances the floor or starts a battle. That's
  the exact gap this task closes.
- GID-099's joint PvE engine is generic (`SceneManager.enter_coop_pve_battle`,
  `BattleScene._build_coop_pve_state`, `CoopBattleScaling`). The real precedent for
  routing a world-map boss into it is Co-op Town Siege
  (`WorldScene._coop_engage_siege_boss` / `_coop_start_siege_boss_battle`,
  `WorldScene.gd:2583-2634`): authority gathers `abs_peer_ids`, builds one deck
  array per peer, RPCs each client `notify_coop_pve_start(idx, all_decks, edata)`,
  then calls `enter_coop_pve_battle(0, all_decks, edata)` locally. Every peer's own
  `BattleScene._finish_coop_pve` independently emits `GameBus.coop_pve_battle_ended(did_win)`
  once it has the authoritative result (host computes + broadcasts, clients receive
  via the `coop_battle_ended` RPC) — so a listener on that signal fires on **every**
  peer with the same `did_win`, which is what `_on_coop_pve_battle_ended_leaderboard`
  and `_on_coop_siege_battle_ended` already rely on.
- `_build_coop_pve_state`'s `ally_setup` callable (`BattleScene.gd:3221-3257`) only
  handles `Array[Dictionary]` (owned card instances, siege's per-peer decks) or falls
  back to a hardcoded starter deck — it silently **ignores** a deck array of plain
  card-id `String`s (which is what a co-op Spire shared draft deck is:
  `Array[String]`). Needs a small additive branch.
- **Real risk found and designed around:** `EnemyNPC.engage()` unconditionally emits
  `GameBus.enemy_engaged`, which **both** `SceneManager._on_enemy_engaged` (starts a
  normal solo battle, connected at autoload boot — always first) **and**
  `WorldScene._on_enemy_engaged_coop` (siege/spire joint-battle routing, connected
  later, per-map) receive, in that connection order. `SceneManager._on_enemy_engaged`
  has no id/coop-aware guard today, so for a co-op Spire boss it would flip
  `_state` to `BATTLE` and start a **solo** battle before the joint-battle handler
  ever runs (which would then no-op, since `enter_coop_pve_battle` itself guards on
  `_state == State.WORLD`). Fixing this generally (it may also affect the existing,
  separately-flagged "unverified in-sandbox" siege code) is out of scope for this
  task — logged as **BID-044**. This task's own new code is made unambiguously
  correct by adding one targeted guard at the top of `_on_enemy_engaged`: skip the
  solo-battle start when `NetworkManager.is_active() and
  SceneManager.is_coop_spire_active() and enemy_data.id == "spire_enemy"` (the
  co-op-spire boss is always routed by `WorldScene._on_enemy_engaged_coop` instead).

**Decisions made (documented per the task's own "decide in Plan" call-outs):**

1. **Board/hand model:** each ally keeps their own board/hand/mana on a shared
   field, fighting one shared boss — i.e. use GID-099's `_coop_pve` engine exactly
   as shipped, no new battle-layer changes beyond the deck-format fix above. This
   matches the Research Notes' own suggested fallback ("can be used as-is").
2. **Hero HP across floors:** **no carryover** — every floor battle starts all
   allies at full HP (the engine's normal default). Solo Spire persists
   `hero_hp` across floors for escalating tension, but the co-op equivalent would
   need per-ally HP tracked through picker rotation, disconnects, and floor-to-floor
   `WorldScene` teardown/rebuild — real complexity for a v1 payoff that's already
   delivered by the boss-tier/HP scaling per floor and per party size
   (`CoopBattleScaling`). Documented simplification, not an oversight.
3. **Rewards on a floor win:** left as the **unmodified default** GID-099 behavior
   (each ally gets coins/xp/a soulbound card from `_apply_coop_pve_rewards`) — the
   task's Research Notes explicitly frame this as reusing the engine "as-is", and
   (unlike PvP duels) nothing in this goal calls out "no card/coin rewards" for
   Spire. The draft is the *additional* shared-deck-building reward on top.
4. **Floor→floor transition:** fully automatic, no reliance on the arena's authored
   exit door/`flag_key` (that mechanism is single-player-only machinery living in
   `SceneManager.exit_map()`, which checks `save_manager.is_spire_active()` — always
   false in co-op, since the co-op run deliberately never touches `save_manager`).
   Immediately after the authority resolves a draft pick
   (`_resolve_coop_spire_draft`), it also calls
   `SceneManager.advance_coop_spire_floor()` and broadcasts the next floor's map via
   the existing `recv_map_transition` RPC (same one `_start_coop_spire` already
   uses) — no map-authoring, no new RPC. `SceneManager.exit_map()` gets one more
   guarded branch so that if a peer's world-object-sync incidentally still reaches
   the (now-vestigial) exit door before the auto-transition lands, it's a safe no-op
   instead of falling through to `go_to_menu()` (empty `map_stack` in co-op).
5. **Run end (loss):** the **authority only** (`NetworkManager.is_host()`) calls
   `SceneManager.end_coop_spire_run()`, submits the enriched leaderboard score, and
   broadcasts a new reliable RPC `recv_coop_spire_run_ended(payload)` carrying the
   final stats + party roster to every peer (including itself, called directly,
   matching this file's existing "rpc to others + call local handler directly"
   idiom). Every peer shows a co-op-flavored `RunSummaryScene` **as a child overlay
   of the still-alive `WorldScene`** (not `change_scene_to_node`, which is
   solo-only and would kick the whole co-op session to the main menu) with a
   **"Continue" button** (new — today `RunSummaryScene` only has "Return to Menu")
   that performs the standard shared map transition back to `"madrian"`
   (`recv_map_transition("madrian", "")`, same TID-355 mechanism as every other
   shared-map exit) and frees the overlay. Mid-run disconnect: no special-cased
   removal from `picker_order` — the existing 30 s auto-pick timeout already
   degrades gracefully (an absent picker's turn auto-resolves), and the battle
   itself already tolerates a mid-battle disconnect via the reused PvP disconnect
   handlers (`_connect_pvp_net_signals`). Documented, not implemented further, per
   the task's own explicit simplification guidance ("recording the final survivor
   count is simple and fair").
6. **Leaderboard board name/value:** new board `"coop_spire"` (not a reuse of
   `"coop_clears"`, which stays untouched — it's the generic party-size signal
   shared by *every* joint PvE battle type, siege included, and changing its
   semantics would be an unrelated behavior change). `value = floors_cleared`,
   mirroring the *existing* solo `"spire"` board's own value semantics exactly
   (`stats.floors_cleared`) — this directly satisfies BID-031's ask for a richer
   signal than party size, with zero new encoding scheme to invent. Added via the
   exact `night_hunts` (v9) precedent: `_PVE_BOARDS`, default `leaderboards` dict,
   `_sanitized_leaderboards`, `get_pve_leaderboards_snapshot`, version bump v9→v10
   with a migration entry. **No new `LeaderboardOverlay` tab** — `night_hunts` set
   this precedent (a PvE board with no dedicated UI surface yet is acceptable); the
   goal.md explicitly defers leaderboard UI granularity to a future task.

**Implementation outline:**

1. **`game_logic/net/SessionState.gd`** — add `"coop_spire"` board (as above);
   `CURRENT_SESSION_VERSION` 9 → 10.
2. **`scenes/battle/BattleScene.gd`** — `_build_coop_pve_state`'s `ally_setup`:
   branch on `String` deck entries → `ally.build_deck(ids)`, alongside the existing
   `Dictionary` → `build_deck_from_instances` branch (siege untouched).
3. **`autoloads/SceneManager.gd`**:
   - `_on_enemy_engaged`: new guard (item above) skipping solo-battle start for the
     co-op Spire boss.
   - `exit_map()`: new co-op-spire no-op branch before the `map_stack.is_empty()`
     fallback.
4. **`scenes/world/NetSync.gd`** — two new reliable RPCs, exact style of the
   existing siege/spire-draft trios: `submit_spire_boss_engaged(edata: Dictionary)`
   (client → host) and `recv_coop_spire_run_ended(payload: Dictionary)`
   (authority → all).
5. **`scenes/world/WorldScene.gd`**:
   - `_on_enemy_engaged_coop`: new branch routing `eid == "spire_enemy"` while
     `SceneManager.is_coop_spire_active()` to `_coop_engage_spire_boss(edata)`
     (mirrors the siege branch immediately above it).
   - `_coop_engage_spire_boss(edata)` / `_on_spire_boss_engaged_submitted` /
     `_coop_start_spire_boss_battle(edata)`: mirror the siege trio exactly, except
     every ally's deck is the same `SceneManager.get_coop_spire_run().shared_deck`
     (duplicated per ally — `PlayerState.build_deck` shuffles independently per
     call, so allies don't get identical draw order) instead of per-peer decks.
   - New WorldScene field `_coop_spire_battle_pending: bool` (or reuse a simple
     helper `_in_coop_spire_run() -> bool` = `NetworkManager.is_active() and
     SceneManager.is_coop_spire_active()`) so the result handler only reacts when a
     Spire run is actually active — mirrors `_coop_siege_active`'s role but keyed
     off `SceneManager`'s state instead of a WorldScene-local flag, since the run
     must survive the floor-to-floor WorldScene rebuild.
   - `_on_coop_spire_battle_ended(did_win: bool)`, connected once in `_ready`
     alongside `_on_coop_siege_battle_ended` (same "connected permanently" comment):
     no-op unless `_in_coop_spire_run()`. On win: authority calls
     `_start_coop_spire_draft(floor)` (the existing TID-390 hook — its only call
     site, closing that task's documented gap). On loss: **authority only** builds
     the end-of-run payload (`SceneManager.end_coop_spire_run()` +
     `multiplayer.get_peers().size()+1` party size + roster names from
     `_remote_identities`/`MpProfile`), submits `"coop_spire"` leaderboard score,
     RPCs `recv_coop_spire_run_ended(payload)`, and calls
     `_on_coop_spire_run_ended_received(payload)` locally. Non-authority peers only
     react to the RPC.
   - `_resolve_coop_spire_draft` (extend, don't replace): after committing the pick
     + advancing the picker, also `SceneManager.advance_coop_spire_floor()` and
     broadcast+perform the next-floor `recv_map_transition` (item 4 above).
   - `_on_coop_spire_run_ended_received(payload)`: decode, instantiate
     `RunSummaryScene` as a child overlay (`coop_stats` field, not
     `change_scene_to_node`), wire its new `continue_pressed` signal to a handler
     that broadcasts+performs `recv_map_transition("madrian", "")` and frees the
     overlay, and calls `SceneManager.set_coop_spire_run_mirror({"active": false})`
     so a lingering local mirror can't wedge a future `is_coop_spire_active()`
     check.
   - `_on_coop_session_ended`: add the new overlay/pending state to the existing
     cleanup list (same pattern as the draft overlay cleanup already there).
6. **`scenes/ui/RunSummaryScene.gd`** (+ `.tscn` untouched — built entirely in
   `_ready()`): new `coop_stats: Dictionary` field (checked before `spire_stats` in
   `_ready`'s branch), `signal continue_pressed`, `_build_coop_spire_ui()` (based on
   `_build_spire_ui`, adds a party-roster line, swaps the "Return to Menu" button
   for "Continue" wired to `continue_pressed.emit()` instead of `_on_menu`).
7. **Backlog:** file **BID-044** for the suspected `_on_enemy_engaged` /
   `_on_enemy_engaged_coop` ordering race affecting the existing siege-boss path
   (found during research above; out of scope to fix here).
8. **Tests:** extend `tests/unit/test_scene_manager_state.gd` (the same
   before/after snapshot file TID-390 extended) with cases for the new
   `exit_map()` co-op-spire no-op branch and `end_coop_spire_run` interplay with
   leaderboard-value expectations at the `SessionState` level; add
   `SessionState.record_pve_score("coop_spire", ...)` / `get_pve_leaderboard`
   round-trip cases to whatever file already covers TID-379/383
   (`tests/unit/test_session_state.gd`, to confirm exact name before writing).
9. **Validation:** same sandbox constraint as TID-390 — no Godot binary, egress to
   the release zip returns HTTP 403 (organization policy denial, reconfirmed this
   session). Manual review in lieu of `godot --headless --editor --quit` +
   `tests/runner.gd`, flagged identically in Changes Made.

## Changes Made

_Filled after Build phase._

## Changes Made

- **`game_logic/net/SessionState.gd`** — new `"coop_spire"` PvE leaderboard
  board (value = `floors_cleared`, mirroring the solo `"spire"` board's
  semantics — richer signal than the generic `"coop_clears"` party-size board,
  per BID-031). `_PVE_BOARDS`, default `leaderboards` dict,
  `_sanitized_leaderboards`, `get_pve_leaderboards_snapshot`; migration + doc
  comment; `CURRENT_SESSION_VERSION` 9 → 10.
- **`scenes/battle/BattleScene.gd`** — `_build_coop_pve_state`'s `ally_setup`
  callable gained a branch for plain card-id `String` deck entries
  (`ally.build_deck(ids)`), alongside the existing `Array[Dictionary]` →
  `build_deck_from_instances` branch. Needed because the co-op Spire's shared
  draft deck is `Array[String]`, which the existing code silently ignored
  (fell back to a hardcoded starter deck). Siege's per-peer instance decks are
  unaffected.
- **`autoloads/SceneManager.gd`**:
  - `_on_enemy_engaged`: new guard skipping the solo-battle path for the co-op
    Spire boss (`NetworkManager.is_active() and
    current_map.begins_with("spire_floor_") and id == "spire_enemy"`) —
    prevents a race against `WorldScene._on_enemy_engaged_coop`'s joint-battle
    routing (see BID-044 for the pre-existing, unresolved analogue in siege).
  - `exit_map()`: new co-op-spire no-op branch (checked via `NetworkManager`,
    not `is_coop_spire_active()`, since that flag is host-only-accurate) so
    the arena's now-vestigial exit door can't fall through to `go_to_menu()`.
  - New `enter_coop_map_no_stack(target_map, door_id)` — mirrors
    `_advance_spire_floor`'s non-stack-pushing pattern; used by every co-op
    Spire map transition (entry, floor-to-floor, return to madrian) to avoid
    permanently polluting `map_stack` with a chain of floor names nothing ever
    pops.
  - `enter_coop_pve_battle`'s docstring updated to describe the two accepted
    per-ally deck shapes.
- **`scenes/world/NetSync.gd`** — two new reliable RPCs, exact style of the
  existing siege/spire-draft trios: `submit_spire_boss_engaged(edata)` (client
  → host) and `recv_coop_spire_run_ended(payload)` (authority → all).
- **`scenes/world/WorldScene.gd`**:
  - `_in_coop_spire_floor()` — new helper (`NetworkManager.is_active() and
    map_name.begins_with("spire_floor_")`), used everywhere a peer (not just
    the host) needs to know "is a co-op Spire run active here." Deliberately
    not `SceneManager.is_coop_spire_active()`, which — discovered during this
    task — is **only ever true on the host** (`enter_spire_coop` is
    host-only, and nothing in TID-390 ever mirrored it to clients despite the
    doc claiming otherwise; corrected in docs, see below).
  - `_on_enemy_engaged_coop`: new branch routing the co-op Spire boss
    (`eid == "spire_enemy"`) to `_coop_engage_spire_boss`.
  - `_coop_engage_spire_boss` / `_on_spire_boss_engaged_submitted` /
    `_coop_start_spire_boss_battle`: exact mirror of the siege trio, except
    every ally's deck is the same `SceneManager.get_coop_spire_run().shared_deck`
    (duplicated per ally).
  - `_resolve_coop_spire_draft` (extended): after committing the pick, also
    calls `SceneManager.advance_coop_spire_floor()` and broadcasts+performs
    the next floor's map transition via `enter_coop_map_no_stack`.
  - `_on_map_transition_received`: routes any transition touching a
    `spire_floor_` map (either end) through `enter_coop_map_no_stack` instead
    of the normal stack-pushing `enter_map`.
  - `_on_coop_spire_battle_ended` (new, connected to `GameBus.coop_pve_battle_ended`
    alongside the existing siege/leaderboard listeners): on win, captures the
    next floor number; on loss (authority only), ends the run, submits the
    `"coop_spire"` leaderboard score, and captures the run-ended payload. Runs
    while `WorldScene` is still detached from the tree (same window as the
    pre-existing `coop_pve_battle_ended` listeners) — everything captured here
    is deferred rather than acted on immediately.
  - `_flush_pending_coop_spire_post_battle` (new) + two new pending fields
    (`_pending_coop_spire_draft_floor`, `_pending_coop_spire_run_ended_payload`),
    flushed from `_enter_tree()` (mirrors the existing
    `_pvp_ended_pending_broadcast` pattern) once reattachment makes `get_tree()`
    safe again: opens the next floor's draft (TID-390's previously-uncalled
    `_start_coop_spire_draft` hook — this is its first real caller), or
    RPC-broadcasts + shows the run-ended summary.
  - `_on_coop_spire_run_ended_received` / `_on_coop_spire_summary_continue`
    (new): shows `RunSummaryScene` as a WorldScene child overlay (not
    `change_scene_to_node`, which would exit the whole co-op session);
    "Continue" performs the standard shared `recv_map_transition("madrian", "")`.
  - `_on_coop_session_ended`: added cleanup for the new summary overlay,
    mirroring the existing draft-overlay cleanup.
- **`scenes/ui/RunSummaryScene.gd`** — new `coop_stats: Dictionary` field
  (checked before `spire_stats` in `_ready`), new `continue_pressed` signal,
  and `_build_coop_spire_ui()` (floors cleared, party size, roster list,
  "Continue" button instead of "Return to Menu"). Solo `_build_ui`/
  `_build_spire_ui` paths are untouched.
- **`tests/unit/test_session_state.gd`** — `coop_spire` board coverage:
  defaults, round-trip, snapshot shape, value-overwrite semantics, v10
  migration backfill + preservation (8 new/extended cases).
- **Backlog:** filed **BID-044** for the suspected pre-existing race between
  `SceneManager._on_enemy_engaged` and `WorldScene._on_enemy_engaged_coop` in
  the co-op siege-boss engage path (found while designing this task's own,
  now-guarded, analogous Spire boss engage path).

### Validation

**Could not run `godot --headless --editor --quit` or `tests/runner.gd`** —
same sandbox constraint as TID-390: the documented install recipe
(`wget .../Godot_v4.6-stable_linux.x86_64.zip`) returns HTTP 403 from the
agent proxy (organization policy denial, reconfirmed this session via
`curl -sSI` and `$HTTPS_PROXY/__agentproxy/status`), and no cached Godot
binary exists in this environment.

In lieu of the automated check: full manual review, including — brace/paren/
bracket balance check across every touched file (Python script counting
delimiters; `WorldScene.gd`'s pre-existing raw off-by-one, documented by
TID-390, is unchanged by this diff — my 127 added opens exactly match 127
added closes); every `:=` inference site checked against a concretely-typed
RHS; every new RPC/handler name cross-checked end-to-end (NetSync forwarder ↔
WorldScene handler ↔ call site); traced the exact signal/tree-attachment
timing of `GameBus.coop_pve_battle_ended` (fires while `WorldScene` is
detached from the tree, mid-`TransitionManager.transition`'s async fade) and
found this task's new code was the first in this chain to touch
`get_tree()` from that window — fixed via a pending-flag +
`_enter_tree()`-flush deferral (see Changes Made) rather than assuming it
would silently work; and discovered mid-review that
`SceneManager.is_coop_spire_active()` never actually becomes true on a
non-host peer in the shipped TID-390 code (no call site for
`set_coop_spire_run_mirror` existed) — routed around it with a
map-name-based check instead of attempting a deeper fix to the mirror.

**Needs a real headless import + `tests/runner.gd` run before merging** —
same flag as GID-102/103/105/106(TID-390)/110's precedent in `tasks/index.md`.

## Documentation Updates

- `docs/agent/multiplayer-coop.md`:
  - Corrected the TID-390 "Co-op Endless Spire" subsection's claim that the
    client-side `_coop_spire_run` mirror was "updated via the draft-choice
    broadcast" — no such call site ever existed; `is_coop_spire_active()` was
    always false on non-host peers. Documented the actual fix (map-name-based
    `_in_coop_spire_floor()` check) and the mirror's real, narrower purpose
    (reset to inactive at run end only).
  - Added a new `### Co-op Endless Spire — joint floor battles & leaderboard
    (TID-391)` subsection: floor battle routing, the engage-signal race and
    its guard (+ pointer to BID-044), automatic floor advancement and the
    `map_stack` hygiene fix, run-end leaderboard submission + the new
    `"coop_spire"` board, the tree-detachment deferral pattern, the co-op
    run-summary overlay, and test coverage.
