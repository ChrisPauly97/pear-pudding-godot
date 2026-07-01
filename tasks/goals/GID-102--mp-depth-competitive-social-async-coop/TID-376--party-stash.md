# TID-376: Shared party stash (deposit/withdraw)

**Goal:** GID-102
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Card trading is **peer-to-peer** (GID-101 / TID-366) and requires both players present. A
**shared party stash** is a session-owned chest any member can deposit cards/coins into and
withdraw from — a persistent communal pool that smooths gearing the whole party. It also
provides the transfer plumbing the auction house (TID-378) reuses.

## Research Notes

- **Storage — `game_logic/net/SessionState.gd`.** Add a shared `stash: Dictionary`
  (authority-owned, persisted) shaped `{cards: Array, coins: int}` where `cards` are full card
  *instances* (same shape as a member's `owned_cards`, built via
  `game_logic/CardInstanceUtil.gd`). Bump `CURRENT_SESSION_VERSION` (coordinate with TID-370 —
  if TID-370 went to v4, this is v5) with a migration adding `stash = {cards: [], coins: 0}`.
  Add to `to_dict`/`from_dict` (lines 63–101).
- **Transfer plumbing — reuse TID-366.** The dupe-proof card move already exists:
  `_transfer_card_in_session` (removes the instance from giver's `owned_cards`/`player_deck`,
  re-keys the UID into the receiver's namespace, adds to receiver's `owned_cards` — see
  `multiplayer-coop.md` → "Card trading & gifting"). Generalise it (or add a sibling) to move
  an instance **member ⇄ stash**: deposit re-keys into a `stash`-namespaced UID; withdraw
  re-keys into the withdrawing member's namespace. Coins are a simple int move
  (`SessionStore` member coins ⇄ `stash.coins`). **Unique cards** (`is_unique`) are blocked
  from the stash, same as trading.
- **RPCs — `scenes/world/NetSync.gd`.** Mirror the trade flow (proximity not required — the
  stash is global to the session):
  - `submit_stash_deposit(payload)` / `submit_stash_withdraw(payload)` (client → authority,
    reliable). Authority validates ownership (deposit: giver still owns it; withdraw: stash
    has it), executes the move, persists via `SessionStore.mark_dirty`, then broadcasts.
  - `recv_stash_update(snapshot)` (authority → all, reliable) — current stash contents, so all
    members' panels stay in sync. Late-join: include the stash in the existing character/world
    snapshot fan-out (`_send_character_to_peer`).
- **HUD panel.** A stash overlay (BaseOverlay pattern) reachable from the world HUD: two
  columns (my deck/collection ↔ stash) with deposit/withdraw buttons + a coins row. Reuse the
  deck-builder card-list widgets if cheap. Viewport-relative, mobile parity.
- **Authority-only writes.** Clients never mutate `SessionState`; only the authority does
  (isolation invariant — all persistence via `SessionStore`, never `save_slot_*.json`).
- **Tests:** extend `tests/unit/test_session_state.gd` (stash field default, round-trip,
  migration, unique-card block); a deposit/withdraw round-trip on the transfer helper. A
  loopback smoke (`net_stash_smoke.gd`) optional, mirroring `net_session_smoke.gd`.
- **Docs:** update `docs/agent/multiplayer-coop.md` (new "Party stash" subsection + RPC table
  + Tests table).

## Plan

1. **`game_logic/net/SessionState.gd`**
   - Bump `CURRENT_SESSION_VERSION` 4 → 5 (v5: adds shared `stash`).
   - Add `var stash: Dictionary = {"cards": [], "coins": 0}`.
   - `to_dict`: `"stash": stash.duplicate(true)`.
   - `from_dict`: defensive read (dict-or-default), duplicated.
   - `_apply_migrations`: `if ver < 5: if not data.has("stash"): data["stash"] = {"cards": [], "coins": 0}` then stamp version 5.

2. **New pure transfer module — `game_logic/net/StashTransfer.gd`** (mirrors `CardInstanceUtil`/
   `RatingMath`: pure `RefCounted`, no scene deps, fully unit-testable — this is the
   "generalizable plumbing" TID-378 (auction house) will reuse):
   - `deposit_card(stash: Dictionary, member_rec: Dictionary, card_uid: String) -> Dictionary`
     returns `{ok: bool, stash: Dictionary, member: Dictionary}` — finds the card in
     `member_rec.owned_cards`, blocks if `is_unique` true, removes it + its deck UID,
     re-keys uid into a stash-namespaced uid (`card_uid + "_stash_" + counter`), appends to
     `stash.cards`.
   - `withdraw_card(stash, member_rec, stash_uid, member_token) -> Dictionary` — inverse:
     finds the card in `stash.cards`, removes it, re-keys into the member's namespace
     (`stash_uid + "_w_" + member_token.substr(0,4)`), appends to `member_rec.owned_cards`.
   - `deposit_coins(stash, member_rec, amount) -> Dictionary` / `withdraw_coins(...)` — simple
     int moves with insufficient-funds guards (amount <= 0 or balance < amount → no-op/ok=false).
   - WorldScene calls into this module and applies the returned dicts back onto `SessionStore`
     member records + `st.stash`, mirroring how `_transfer_card_in_session` mutates `st`.

3. **RPCs — `scenes/world/NetSync.gd`** (mirror trade RPC style, reliable, any_peer/call_remote):
   - `submit_stash_deposit(payload: Dictionary)` — client → authority. payload:
     `{kind: "card"|"coins", card_uid, amount}`.
   - `submit_stash_withdraw(payload: Dictionary)` — client → authority. Same payload shape.
   - `recv_stash_update(snapshot: Dictionary)` — authority → all. `{cards: Array, coins: int}`.

4. **WorldScene handlers** (new section near trading, guarded by `NetworkManager.is_host()`
   for the mutating side, like `_on_trade_confirm_submitted`):
   - `_on_stash_deposit_submitted(sender, payload)` / `_on_stash_withdraw_submitted(sender, payload)`
     — host-only, resolve sender's token via `_session_token_by_peer` (fallback to local
     `MpProfile.get_token()` when sender is the host itself), call `StashTransfer`, persist via
     `SessionStore.update_member` + `st.stash = ...` + `SessionStore.mark_dirty()`, broadcast
     `recv_stash_update`.
   - `_broadcast_stash_update(target_peer := 0)` helper mirroring `_broadcast_leaderboard`.
   - `_on_stash_update_received(snapshot)` — cache `_stash_cache`, refresh overlay if open.
   - Local convenience wrappers `_request_stash_deposit_card` / `_request_stash_withdraw_card` /
     `_request_stash_deposit_coins` / `_request_stash_withdraw_coins` used by the HUD overlay —
     host executes directly (calls the `_on_..._submitted` handler with its own peer id),
     client sends the submit RPC to peer 1.
   - Late-join: extend `_send_character_to_peer` to also unicast `recv_stash_update` with the
     current stash snapshot (alongside character/party-bounty/leaderboard sends).

5. **HUD overlay — `scenes/ui/PartyStashOverlay.gd`** (new), following `LeaderboardOverlay.gd`
   exactly: `extends "res://scenes/ui/BaseOverlay.gd"`, instantiated via `.new()`,
   viewport-relative, rebuilt on `NOTIFICATION_RESIZED`. Two-column layout: left = my
   collection (deposit buttons, skip unique cards from the list), right = stash contents
   (withdraw buttons); a coins row with deposit/withdraw amount stepper buttons (+10/+100).
   `refresh(my_cards, stash_snapshot)` called by WorldScene. No `.uid` needed — plain `.gd`.
   HUD button "Stash" added next to the Leaderboard button, always visible while co-op
   active (global, not proximity-gated, same as Leaderboard).

6. **Tests**
   - New `tests/unit/test_stash_transfer.gd`: deposit moves card + re-keys uid + removes from
     deck, deposit blocks `is_unique`, deposit no-ops on missing card, withdraw moves card back
     + re-keys, withdraw no-ops on missing stash card, coin deposit/withdraw incl.
     insufficient-funds guards, round-trip (deposit then withdraw restores an equivalent card
     to owned_cards, minus the uid rename).
   - Extend `tests/unit/test_session_state.gd`: stash field default `{cards: [], coins: 0}`,
     round-trip (cards + coins survive to_dict/from_dict), migration v4→v5 backfill on an
     existing v4 dict without `stash`.
   - Skip the optional loopback smoke test (`tests/net_stash_smoke.gd`) per task guidance —
     unit coverage on the transfer logic + RPC wiring is the more important bar given time.

7. Validate: headless import clean, full test suite 0 new failures (baseline ~1772 passing).

8. Update `docs/agent/multiplayer-coop.md`: new "Party stash (GID-102 / TID-376)" subsection
   near trading/bounties; add `StashTransfer.gd` + `PartyStashOverlay.gd` + new test file to
   the relevant tables. Surgical edit only (other parallel tasks touch this same doc).

9. Log a backlog item: trading's `_transfer_card_in_session` (GID-101/TID-366) never actually
   checks `is_unique` despite docs/task text claiming unique cards are blocked from trading —
   a real pre-existing gap discovered while building the stash's (correctly enforced) block.
   File as BID-030 (next after BID-029, will state uncertainty in final report).

10. Commit `TID-376: <description>`.

## Changes Made

**`game_logic/net/SessionState.gd`** — bumped `CURRENT_SESSION_VERSION` 3 → 4 (this
worktree's branch predates TID-370's rating fields, which are v4 on a more-merged
branch; the orchestrator will renumber/sequence version bumps across parallel tasks
during integration, per the task's own instructions). Added `stash: Dictionary =
{"cards": [], "coins": 0}`; wired into `to_dict`/`from_dict` (defensive, garbage-
tolerant parsing) and a new `if ver < 4:` migration block that backfills a missing
`stash` key.

**`game_logic/net/StashTransfer.gd`** (new) — pure, unit-tested `RefCounted` module
(no scene deps) generalizing the trading `_transfer_card_in_session` re-key mechanic to
member ⇄ stash moves: `deposit_card`, `withdraw_card`, `deposit_coins`,
`withdraw_coins`. All four return `{ok, reason, stash, member}`. `deposit_card` blocks
`is_unique` cards by looking up the card's template via `CardRegistry.get_template
(template_id)` (instance dicts never carry `is_unique` themselves — see BID-025). This
is the "generalizable plumbing" the task asked for so TID-378 (auction house) can reuse
the same low-level re-key helpers.

**`scenes/world/NetSync.gd`** — added 3 new RPCs mirroring the trade RPC style:
`submit_stash_deposit(payload)` / `submit_stash_withdraw(payload)` (client → authority,
reliable) and `recv_stash_update(snapshot)` (authority → all/one, reliable).

**`scenes/world/WorldScene.gd`** —
- New state: `_stash_btn`, `_stash_overlay`, `_stash_cache`, plus `_StashTransfer` /
  `_PartyStashOverlay` preload consts.
- New handlers: `_stash_token_for_peer`, `_on_stash_deposit_submitted`,
  `_on_stash_withdraw_submitted`, `_broadcast_stash_update`, `_on_stash_update_received`,
  `_refresh_stash_overlay`, `_my_collection_for_stash_ui`, `_toggle_stash_overlay`, and
  the four HUD-facing wrappers `request_stash_deposit_card` /
  `request_stash_withdraw_card` / `request_stash_deposit_coins` /
  `request_stash_withdraw_coins` (host executes directly; a client sends the submit RPC
  to peer 1).
- `_apply_updated_member_to_actor` (new): after a stash transfer, re-adopts the acting
  peer's in-memory character (host: `adopt_session_character` directly; remote client:
  a fresh `recv_character(record, resume=false)` push) so the periodic 5 s
  `_tick_session_persist` tick doesn't clobber the just-mutated `SessionState` member
  record with stale in-memory data. (Trading has this same latent gap and does not fix
  it — noted, not touched, since it's out of scope for this task.)
- `_send_character_to_peer` extended to also unicast `recv_stash_update` with the
  current stash snapshot for late-joiners, alongside the existing character/party-bounty
  sends.
- `_ensure_social_buttons` gained a "Stash" HUD button (always visible while co-op is
  active, viewport-relative sizing, next to the existing Trade/Spectate buttons) — no
  proximity gate, mirroring the rationale documented for the (later) leaderboard button.

**`scenes/ui/PartyStashOverlay.gd`** (new) — `extends "res://scenes/ui/BaseOverlay.gd"`
by path string, instantiated via `.new()` (matches `SettingsScene` /
`MultiplayerLobbyScene` convention), viewport-relative throughout, rebuilt on
`NOTIFICATION_RESIZED`. Two scrollable columns (My Collection / Stash) with per-card
Deposit/Withdraw buttons; unique cards are filtered out of "My Collection" (defense in
depth — the authority also blocks them via `StashTransfer`); a coins row with
fixed-step (50) deposit/withdraw buttons.

**Tests:**
- `tests/unit/test_stash_transfer.gd` (new, 16 cases): deposit moves + re-keys uid,
  deposit blocks unique cards, deposit no-ops on missing card / blank uid, withdraw
  moves + re-keys uid, withdraw no-ops on missing stash card, deposit-then-withdraw
  round-trip, coin deposit/withdraw incl. insufficient-funds and non-positive-amount
  guards, coin round-trip is neutral, garbage-stash-shape tolerance.
- `tests/unit/test_session_state.gd` extended (+6 cases): stash default shape,
  round-trip (cards + coins), garbage-field / garbage-cards-field tolerance, v3→v4
  migration backfill, versionless-dict still gets the stash default.
- Skipped the optional `tests/net_stash_smoke.gd` loopback smoke per the task's own
  time-tradeoff guidance — unit coverage on `StashTransfer` + the RPC wiring was judged
  the more important bar given time; the RPC shapes exactly mirror the already-smoke-
  tested trade/bounty RPCs (`recv_trade_update`, `recv_party_bounties_snapshot`), so the
  transport-level risk is low.

**Backlog:** logged `BID-025--trading-unique-check-not-enforced.md` — discovered that
card trading (GID-101/TID-366) never actually enforces the documented "unique cards are
blocked" invariant anywhere in the code path, unlike the new stash feature which does.
Note: this worktree's `tasks/backlog/` only goes up to BID-024 (it's an earlier branch
point than the parent checkout, which had BID-029); flagged the numbering uncertainty
in the BID file itself for the orchestrator to reconcile against sibling tasks' backlog
items during integration.

**Validation:** `godot --headless --editor --quit` produced zero Parse/Compile/
Failed-to-load-script lines (clean). Full suite (`godot --headless --path . -s
tests/runner.gd`): **1712 passed, 0 failed, 1 pending** (this worktree's baseline,
which is lower than the "~1772" figure in the task brief because this branch predates
several sibling GID-102 tasks merging in — no regressions either way).

## Documentation Updates

`docs/agent/multiplayer-coop.md`:
- New **"Party stash (GID-102 / TID-376)"** subsection inserted directly after "Card
  trading & gifting" (before "Shared party bounties"), covering storage, the
  `StashTransfer` module, RPCs, the authority flow (including the in-memory-character
  re-sync fix), late-join snapshot, and the HUD overlay.
- Updated the `test_session_state.gd` Tests-table row to mention the stash cases
  (25 → 31 total cases) and added a new row for `tests/unit/test_stash_transfer.gd`
  (16 cases).
- Edit was surgical (only the trading-adjacent subsection + two Tests-table lines
  touched) since 4 other parallel GID-102 tasks (TID-377, 379, 380, 381) edit this same
  doc file in separate worktrees for later merge.
