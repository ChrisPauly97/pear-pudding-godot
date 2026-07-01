# TID-381: Party loot rolls (need/greed on drops)

**Goal:** GID-102
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Shared loot today is **first-opener-takes** for chests (GID-096) and **soulbound-to-everyone**
for co-op boss drops (GID-099). A classic party-RPG alternative is a **need/greed roll**: when
a shareable drop appears, every present member rolls and the highest roll wins it. This task
adds an opt-in roll flow for shared chest drops (and optionally a bonus boss drop), keeping
first-opener-takes as the default.

## Research Notes

- **Pure roll helper — new `game_logic/net/LootRoll.gd`** (scene-free, unit-tested, mirrors
  `WorldObjectSync`): encode/decode for a roll session `{roll_id, item, rolls: {token: value},
  resolved, winner_token}` and individual roll intents. The **authority** rolls the RNG (so
  it's tamper-proof) — clients only submit `need` / `greed` / `pass` choices; the authority
  assigns the random value. Need beats greed; ties broken by highest value.
- **Trigger.** When a shared chest is opened in co-op (the `_on_chest_opened_coop` branch,
  `multiplayer-coop.md` → "Loot rule — first-opener-takes"), if **roll mode** is enabled for
  the session, instead of dropping locally for the opener, the authority opens a **roll
  session** for that drop and broadcasts a prompt to all same-map members. This *replaces* the
  first-opener-takes branch only when roll mode is on; default stays first-opener.
- **RPCs — `scenes/world/NetSync.gd`** (reliable):
  - `recv_loot_roll_start(payload)` (authority → all same-map) — show the roll prompt
    (item + Need/Greed/Pass buttons + a short timer).
  - `submit_loot_roll_choice(roll_id, choice)` (client → authority).
  - `recv_loot_roll_result(roll_id, winner_token, rolls)` (authority → all) — announce the
    winner; the authority grants the item to the winner's session character (reuse the
    GID-096 local-loot grant, but to the winner instead of the opener) and persists.
- **Settle.** Authority waits for all present members' choices or a timeout (auto-pass), rolls
  values for need/greed entrants, picks the winner, grants the loot into that member's GID-095
  character via `SessionStore`, broadcasts the result. No item is ever granted twice
  (authority-only grant, persisted into `opened_chests` exactly as today).
- **Mode toggle.** A session setting (host/lobby) "Loot: first-opener / need-greed". Store on
  `SessionState` (a simple `loot_mode: String`) or as a host-only runtime flag broadcast on
  join. Recommend `SessionState` so it persists; bump version with a migration (after the
  other Phase tasks).
- **Boss drops (optional).** GID-099 boss wins drop a soulbound card to **every** ally — that
  is generous and arguably shouldn't change. If a *bonus* roll item is desired, add it as an
  extra drop resolved by the same roll path; otherwise leave boss drops as-is and scope this
  task to **chest** drops.
- **UI.** A transient roll panel (BaseOverlay or a HUD popup): item icon + Need/Greed/Pass +
  countdown; a result toast naming the winner. Viewport-relative, mobile parity.
- **Tests:** `tests/unit/test_loot_roll.gd` — need>greed precedence, tie-break, all-pass,
  timeout-as-pass, encode/decode round-trip + garbage tolerance. Authority-RNG determinism
  with a seeded RNG for the test.
- **Docs:** update `docs/agent/multiplayer-coop.md` (extend the loot-rule section with the
  need/greed alternative + RPC + Tests tables).

## Plan

1. **`game_logic/net/LootRoll.gd`** (new, scene-free, mirrors `WorldObjectSync.gd`):
   - Choice constants `CHOICE_NEED`/`CHOICE_GREED`/`CHOICE_PASS`.
   - `encode_start(roll_id, item, participant_tokens) -> Dictionary` / `decode_start(payload) -> Dictionary`
     for the authority's roll-prompt broadcast.
   - `encode_choice(roll_id, choice) -> Array` / `decode_choice(payload) -> Dictionary` for the
     client→authority intent.
   - `encode_result(roll_id, winner_token, rolls) -> Dictionary` / `decode_result(payload) -> Dictionary`
     for the authority's announcement.
   - `static func resolve_winner(choices: Dictionary, rng: RandomNumberGenerator) -> Dictionary`
     — the core pure resolver. `choices` is `{token: "need"|"greed"|"pass"}`. Rolls a value
     1-100 per non-pass entrant via the injected RNG (testable/deterministic with a seeded
     RNG), picks need over greed, ties broken by highest rolled value, returns
     `{winner_token: String, rolls: {token: int}}` (`winner_token == ""` when everyone passed).
   - Garbage-tolerant decode (missing/short arrays never throw).
2. **`SessionState.gd`**: add `loot_mode: String = "first_opener"` field (`LOOT_MODE_FIRST_OPENER` /
   `LOOT_MODE_NEED_GREED` constants), thread through `to_dict`/`from_dict`, bump
   `CURRENT_SESSION_VERSION` to 5 with a v5 migration defaulting `loot_mode` when absent.
3. **`NetSync.gd`** — 3 new reliable RPCs: `recv_loot_roll_start(payload: Dictionary)`,
   `submit_loot_roll_choice(roll_id: String, choice: String)`, `recv_loot_roll_result(payload: Dictionary)`,
   each routed to a `WorldScene` handler, mirroring the existing RPC-forwarding pattern exactly.
4. **`WorldScene.gd`** wiring:
   - New state: `_loot_roll_active: Dictionary` (host: roll_id -> {item, tier, expected_tokens,
     choices, timer_accum}), `_pending_loot_roll: Dictionary` (client: current prompt payload or
     {}), a small roll-prompt panel builder + result toast.
   - Insertion point in `_handle_interact`'s chest branch: after `_on_chest_opened_coop(cid)`,
     branch on `_coop_loot_mode_is_need_greed()`. When true and co-op is active: skip the
     immediate `_spawn_card_items`/`_spawn_coin_piles`/`_maybe_drop_equipment_from_chest` calls
     for the opener and instead call `_start_loot_roll(chest_pos, chest_card_ids, chest_tier, cid)`
     which computes the same drop payload once (so it can't reroll if resubmitted) and, if this
     peer is the authority, opens a roll session and broadcasts the prompt to all same-map
     session members (`multiplayer.get_peers()` + local); if this peer is a client, it still
     needs the drop payload to send to host as part of a "resolve now" intent — simplify: the
     opener (whether host or client) sends the resolved drop description to the authority via a
     new lightweight `submit_world_event`-style path is unnecessary complexity; instead the
     **authority always resolves the drop `Dictionary` locally** (same tier/card_ids the opener
     already computed and sent along in `recv_loot_roll_start`'s originating call), so client
     openers relay {tier, card_ids, chest_pos} to the host via a small helper on the existing
     `submit_world_event`-adjacent channel — see step-by-step below for exact call sites.
   - Default path (`loot_mode == "first_opener"` or solo/non-coop) is **completely unchanged** —
     confirmed by re-reading the full `_handle_interact` chest branch before editing.
   - `_start_loot_roll` (opener side, any peer): if authority, calls `_authority_open_loot_roll`
     directly; if client, `rpc_id(1, "submit_world_event"...)` is not reused (wrong shape) —
     instead add a tiny direct call: client owners just call `_net_sync.rpc_id(1,
     "submit_loot_roll_choice", ...)`? No — simplify further: the **opener never needs to relay**
     because the authority already knows the chest id/tier/card_ids from the map's static chest
     data (`_active_chest_data`), which is deterministic on all peers (spawned from the same
     `.tres`/map file, per the GID-096 determinism invariant). So `_authority_open_loot_roll(cid)`
     re-derives `chest_pos`/`chest_card_ids`/`chest_tier` from `_active_chest_data[cid]` itself —
     no wire payload needed for the item shape, keeping this fully consistent with the
     "deterministic spawn, only discrete sync" invariant already documented for GID-096. A client
     opener's `_on_chest_opened_coop(cid)` submit (existing `EV_CHEST_OPENED`) already reaches the
     host; hook the roll-start there instead of a new intent.
   - Concretely: extend `_on_world_event_submitted`'s `EV_CHEST_OPENED` arm and
     `_on_chest_opened_coop`'s host branch — after recording the chest opened, if
     `loot_mode == need_greed`, call `_authority_open_loot_roll(cid, chest_pos, chest_card_ids,
     chest_tier)` instead of leaving loot to the opener; the **opener's own local loot spawn is
     skipped** by checking the mode before calling `_spawn_card_items` etc. in `_handle_interact`.
   - `_authority_open_loot_roll`: builds `participant_tokens` from `_session_token_by_peer.values()`
     plus the host's own token (present session members only — "present" simplified to "connected
     to the session", not a same-map/proximity check, documented as a v1 scope decision), stores
     the pending roll state keyed by a generated `roll_id`, and `_net_sync.rpc("recv_loot_roll_start",
     ...)` to all (host applies to itself directly, matching the existing `recv_world_event`
     self-apply pattern used elsewhere... actually simpler: call the local handler directly for
     self, rpc to others).
   - `_process` tick: while `_loot_roll_active` has entries, accumulate elapsed time; on
     `LOOT_ROLL_TIMEOUT = 15.0` seconds (or all expected tokens responded), call
     `_settle_loot_roll(roll_id)`.
   - `_settle_loot_roll` (authority only): builds `choices` from received submissions (missing
     tokens auto-pass), calls `LootRoll.resolve_winner`, grants the loot to the winner's session
     character (new `_grant_chest_loot_to_token(token, chest_card_ids, chest_tier, chest_pos)`
     helper — cards via `CardDropUtil` + `CardInstanceUtil.make` appended to
     `SessionStore`'s member record `owned_cards` (not `player_deck`, consistent with how a
     chest card is "owned" but not auto-decked in single-player either — confirm against
     `_spawn_card_items`/pickup path), coins via a coins field bump on the member record), marks
     dirty, and broadcasts `recv_loot_roll_result`.
   - Client handlers: `_on_loot_roll_start_received` shows the prompt panel (item description +
     Need/Greed/Pass + countdown label refreshed in `_process`), sending the choice via
     `submit_loot_roll_choice`; `_on_loot_roll_result_received` closes the prompt (if open) and
     shows a `GameBus.hud_message_requested` toast naming the winner.
   - **Equipment drops**: `_maybe_drop_equipment_from_chest` writes to `SceneManager.save_manager`
     (local-only, single-player-shaped API) — no session-store equivalent exists. Scope decision:
     **coins + cards are roll-eligible; the bonus equipment roll is left as first-opener-takes
     (folded into the winner too, keeping it simple) — actually simplest + least surprising:
     skip equipment drops entirely during a need/greed roll** (document as a v1 scope cut; no
     session-store equipment inventory exists to grant it to an arbitrary winner) — log a BID
     for adding session-scoped equipment storage if desired later.
5. **Tests — `tests/unit/test_loot_roll.gd`**: need-beats-greed, tie-break-by-highest-value
   within a tier, all-pass (no winner), timeout-as-pass (modeled as: missing token => treated as
   pass by the caller before calling `resolve_winner`, tested at the WorldScene-adjacent level is
   out of scope for a pure test — test the pure contract: `resolve_winner` with an explicit
   `"pass"` entry produces the same result as an absent one when the caller pre-fills defaults),
   encode/decode round-trip + garbage tolerance for all three wire helpers.
6. **Docs** — extend `docs/agent/multiplayer-coop.md`'s "Loot rule — first-opener-takes" section
   surgically (small insertion, not a rewrite) with the opt-in need/greed alternative + new RPCs
   + new pure helper row + tests summary.
7. Validate via headless import + full test run. Commit.

## Changes Made

- **`game_logic/net/LootRoll.gd`** (new) — pure, scene-free, unit-tested need/greed roll
  helper mirroring `WorldObjectSync.gd`'s style. `CHOICE_NEED`/`CHOICE_GREED`/`CHOICE_PASS`
  constants; `normalize_choice`; `encode_start`/`decode_start` (roll prompt: roll_id, item
  dict, participant tokens); `encode_choice`/`decode_choice` (client intent, `Variant`-typed
  decode params for garbage tolerance); `encode_result`/`decode_result` (winner + rolled
  values). Core `static func resolve_winner(choices: Dictionary, rng:
  RandomNumberGenerator) -> Dictionary` — need beats greed beats pass; ties within a tier
  broken by highest rolled value (1–100, injected RNG so the authority/tests are
  deterministic); `winner_token == ""` when everyone passes.
- **`game_logic/net/SessionState.gd`** — added `loot_mode: String` field (`LOOT_MODE_FIRST_OPENER`
  default / `LOOT_MODE_NEED_GREED`), threaded through `to_dict`/`from_dict`; bumped
  `CURRENT_SESSION_VERSION` **3 → 4** with a v4 migration that backfills `loot_mode` for
  existing session files (this worktree was at v3 pre-task; the task brief anticipated a
  larger number since parallel tasks bump concurrently — the orchestrator resequences
  version numbers across parallel branches during integration).
- **`autoloads/SessionStore.gd`** — added `get_loot_mode()` / `set_loot_mode(mode)`
  convenience wrappers (mirrors `ensure_member`/`update_member`'s delegate-to-state +
  mark-dirty pattern).
- **`scenes/world/NetSync.gd`** — 4 new reliable RPCs: `recv_loot_roll_start(payload)`,
  `submit_loot_roll_request(cid, chest_tier)` (client → authority: "start a roll for the
  chest I just opened" — not in the original 3-RPC list in the task brief, added because the
  authority needs to know *which* chest to open a roll for when the opener is a client, but
  never needs the item shape itself since it re-derives that from its own deterministic
  chest data), `submit_loot_roll_choice(roll_id, choice)`, `recv_loot_roll_result(payload)`.
- **`scenes/world/WorldScene.gd`**:
  - New consts: `_LootRoll`, `_CardDropUtil`, `_CardInstanceUtil`, `_SessionState` preloads.
  - New state: `_loot_rolls_active` (authority: roll_id -> in-flight roll dict),
    `_LOOT_ROLL_TIMEOUT = 15.0`, `_pending_loot_roll`, `_loot_roll_panel`,
    `_loot_mode_toggle_btn`.
  - **Insertion point** (exactly as specified in the task): after the existing
    `_on_chest_opened_coop(cid)` call and the tier computation, inserted a single guarded
    branch — `if _coop_active and _coop_loot_mode_is_need_greed(): _start_loot_roll(cid,
    chest_tier); return` — immediately before the pre-existing "20% chance to drop a map
    fragment" comment. Confirmed via full re-read of `_handle_interact` before editing that
    the default (`first_opener` or solo) path is **byte-for-byte unchanged** below this
    point.
  - New functions: `_coop_loot_mode_is_need_greed`, `_start_loot_roll`,
    `_on_loot_roll_request_submitted`, `_authority_open_loot_roll`, `_loot_roll_by_chest`,
    `_on_loot_roll_start_received`, `_submit_loot_roll_choice`,
    `_on_loot_roll_choice_submitted`, `_tick_loot_rolls`, `_settle_loot_roll`,
    `_grant_chest_loot_to_token`, `_on_loot_roll_result_received`, `_display_name_for_token`,
    `_show_loot_roll_panel`, `_ensure_loot_mode_toggle_button`,
    `_refresh_loot_mode_toggle_button`, `_on_loot_mode_toggle_pressed`.
  - `_grant_chest_loot_to_token` grants cards (via `CardDropUtil` rarity/stat rolls +
    `CardInstanceUtil.make`, token-salted uid) + a flat `randi_range(5,20)*3` coin reward
    directly into the winner's `SessionState` member record via `SessionStore` (the same
    direct-write pattern as `_transfer_card_in_session`/party-bounty rewards) — **not** the
    physical `WorldItem` pickup path, since the winner may not be the local player.
    Equipment drops are explicitly out of scope (see BID-033).
  - `_process`: added `_tick_loot_rolls(delta)` inside the existing `if _coop_active:` block.
  - `_setup_coop`: host-only, non-dedicated-server, calls `_ensure_loot_mode_toggle_button()`.
  - `_on_coop_session_ended`: clears loot-roll state + frees the toggle button/panel.
  - Host-only in-world HUD toggle button (`Loot: First-Opener` / `Loot: Need/Greed`),
    viewport-relative, placed beneath the session roster panel — documented placement
    decision: `SessionStore` only opens once `_setup_session()` runs inside `_setup_coop()`,
    so a pre-connection lobby toggle has no session to act on yet.
  - Fixed a type bug caught by the mandatory headless-import check: `_loot_roll_panel` was
    initially typed `Control` but holds a `CanvasLayer` (matches `_challenge_accept_panel`/
    `_trade_window`'s existing `Node`-typed pattern) — retyped to `Node`.
- **`tests/unit/test_loot_roll.gd`** (new, 24 cases) — need-beats-greed across 20 seeds,
  need-beats-multiple-greed, greed-beats-pass, tie-break-by-highest-rolled-value (verified
  against the actual returned `rolls` dict, not just re-running the RNG), determinism across
  repeated seeded calls, all-pass/empty-choices → no winner, unrecognized choice → pass,
  timeout-as-pass equivalence (explicit pass vs. omitted participant produce identical
  results), `normalize_choice` mapping, and full encode/decode round-trip + garbage/null/
  non-container tolerance for all three wire helpers (start/choice/result).
- **`tasks/backlog/BID-033--no-session-scoped-equipment-inventory.md`** (new; originally
  self-numbered BID-025, renumbered during integration since BID-025 was already claimed
  by an unrelated finding on the integration branch) — logged the
  equipment-drop scope cut: no `owned_weapons`/`owned_armor` field exists on a `SessionState`
  character record, so the roll path can't grant equipment to an arbitrary (possibly remote)
  winner the way `_maybe_drop_equipment_from_chest` does locally today.

### Validation

- `godot --headless --editor --quit` filtered for Parse/Compile/Failed-to-load errors: **empty**.
- `godot --headless --path . -s tests/runner.gd`: **1714 passed, 0 failed, 1 pending**
  (pending is a pre-existing unrelated headless-environment skip in
  `test_world_event_manager`; baseline before this task was ~1690 passing — the 24 new
  `test_loot_roll` cases account for the delta).

## Documentation Updates

- `docs/agent/multiplayer-coop.md`:
  - Retitled "Loot rule — first-opener-takes" to "Loot rule — first-opener-takes (default),
    opt-in need/greed (GID-102 / TID-381)" and added a full explanation of the mode toggle,
    the deterministic-chest-data trick that avoids sending the item shape over the wire, the
    authority-only-RNG/tamper-proof design, the direct-SessionStore-grant path vs. the
    physical pickup path, and the equipment-drop scope cut (with a BID-033 pointer).
  - Added a `game_logic/net/LootRoll.gd` row to the existing "Pure helpers" table.
  - Added 4 new rows to the existing RPCs table (`recv_loot_roll_start`,
    `submit_loot_roll_request`, `submit_loot_roll_choice`, `recv_loot_roll_result`).
  - Added a `tests/unit/test_loot_roll.gd` row to the main "Tests" table.
  - Edits were surgical insertions/extensions of existing sections/tables, not rewrites, per
    the instruction that four other parallel tasks are editing the same file.
