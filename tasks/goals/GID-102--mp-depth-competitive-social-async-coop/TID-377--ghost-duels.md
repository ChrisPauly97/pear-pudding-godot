# TID-377: Ghost duels vs stored deck snapshots

**Goal:** GID-102
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

PvP needs both players online and on the same LAN/host. A **ghost duel** lets a player battle
an **AI-piloted snapshot** of another player's deck while that player is offline — async
competition with zero live networking. It reuses the existing single-player battle engine +
`BasicAI`; only the *opponent deck source* changes.

## Research Notes

- **Snapshot source.** A "deck snapshot" is just a deck list + display name + (optional) color
  + rating. The authority already holds every member's `player_deck` + `owned_cards` in
  `SessionState` (GID-095). Capture a snapshot `{token, name, color, deck: [template_ids],
  rating}` per member — either derive on demand from the session roster, or persist a
  `ghost_snapshots` list in `SessionState` updated when a member logs off / on a timer. Prefer
  **deriving from `members`** to avoid a second source of truth; persistence already covers it.
  Note: the deck is stored as UID instances — resolve each UID to its **template id** for the
  ghost (the ghost doesn't need the opponent's specific instances, just a playable deck).
- **No live net.** A ghost duel is a **local single-player battle** against an AI whose deck is
  the snapshot. This is the existing solo battle path (`_local_player_idx == 0`, `is_ai`
  opponent, `BasicAI`), **not** the PvP host-authoritative path — so there is no
  `BattleNetSync`, no mirror, no reconnection concern. Add a `SceneManager.enter_ghost_duel(
  opponent_snapshot)` that builds the AI opponent deck from the snapshot and launches
  BattleScene like an NPC duel. Reuse the NPC-duel scaffolding (`docs/agent` references the
  tavern duel / `enter_pvp_battle` siblings — grep `enter_` in SceneManager).
- **Entry point.** Surface ghost opponents in the lobby or a "Challenge a Rival" panel:
  list known snapshots (from the session roster + friends from TID-375 if their snapshot was
  cached). Show name/color/rating. One tap → `enter_ghost_duel`.
- **Rewards.** Keep modest and clearly *async* — e.g. a small coin reward on win, optionally
  feed TID-370 rating with a **reduced K** or no rating change (ghost is AI-piloted, not the
  real player — recommend **no rating change**, coins only, to avoid farming). Decide in Plan;
  default to coins-only.
- **Deck resolution helper.** Building a playable AI deck from template ids already happens for
  NPC/enemy decks (`EnemyRegistry`, `player.build_deck` with a typed `Array[String]` — see
  CLAUDE.md "assign()" guidance). Reuse it; annotate arrays as `Array[String]` to avoid the
  Variant-inference errors documented in CLAUDE.md.
- **Tests:** a unit test for snapshot extraction (member record → `{name, deck template ids}`),
  including UID→template resolution and empty/garbage tolerance. The battle itself is covered
  by existing battle tests.
- **Docs:** update `docs/agent/multiplayer-coop.md` (new "Ghost duels" subsection); note it is
  the only PvP-flavored mode that needs **no** live connection.

## Plan

**Scope note:** this worktree branches off GID-102 before TID-370 (rating),
TID-373 (leaderboard UI) and TID-375 (friends list) land — `SessionState`
here is v3 (no `pvp_rating`/`get_leaderboard`), and `MpProfile` has no
friends API yet. TID-377 has no formal dependency on those, so this plan
reads `pvp_rating` defensively (`get("pvp_rating", 1000)`, forward-compatible
once TID-370 merges) and builds its own minimal entry point from the
session roster rather than assuming a friends list exists.

**1. Snapshot helper — `SessionState.get_ghost_snapshot(token: String) -> Dictionary`.**
Pure, derived on demand (no second source of truth, per the task's explicit
preference). Looks up `members[token]`; returns `{}` for a blank token, an
unknown token, or a non-Dictionary record — never throws. Resolves the
member's `player_deck` (UID list) to template ids by scanning `owned_cards`
for the matching `uid` (a UID with no matching owned-card entry is skipped,
not a crash — the ghost just fields a slightly smaller deck rather than
failing outright). Returns
`{token, name, deck: Array[String], rating}` — `name` from `display_name`
(default "Player"), `rating` from `pvp_rating` defaulting to 1000 (matches
`make_starter_character`'s default so this reads correctly whether or not
TID-370 has landed yet). No `color` field: character records don't store a
color (that's a device-local `MpProfile`/identity concept the session model
doesn't track) — the caller can display without one.

**2. No live net — `SceneManager.enter_ghost_duel(opponent_snapshot: Dictionary) -> void`.**
New function mirroring `_on_duel_requested`'s NPC-duel body: builds an
`enemy_data` dict (`display_name`, `enemy_type: ""`, `is_boss: false`,
`drop_pool: []`, `coin_reward: 0`, `enemy_deck: opponent_snapshot.deck`) and
enters through the exact same `_battle_scene_packed.instantiate()` +
`TransitionManager.transition` path `_on_duel_requested` uses — same deck-min
guard (`save_manager.player_deck.size() < IsoConst.DECK_MIN`). Sets a new
`_battle_overlay.set("_ghost_duel", true)` and
`_battle_overlay.set("_ghost_duel_reward", GHOST_DUEL_COIN_REWARD)` instead of
`duel_wager` — deliberately NOT reusing `duel_wager`/`friendly_duel`, because
`BattleResultUI.show_duel_loss` deducts the wager amount as a real stake
(`coins -= wager`) on loss, which is wrong for an async ghost (nothing was
ever staked). No `_pvp`/`_coop_pve` flags are touched, so BattleScene's plain
`else` branch runs untouched and `_state.players[1]` is built via
`enemy_data["enemy_deck"]` exactly like an NPC duel (`BasicAI`-driven,
`Array[String]` + `.assign()`).

**3. BattleScene — new `_ghost_duel: bool` + `_ghost_duel_reward: int` fields**
(alongside the existing `_pvp`/`_coop_pve` inert-unless-set fields). In
`_check_game_over`, add a branch checked **before** the `friendly_duel` branch:
when `_ghost_duel`, call `_result_ui.show_ghost_duel_result(w == 0,
_ghost_duel_reward)` and return (skips capture-tracker/card-drop/enemy-defeat
logic entirely, same as `friendly_duel` already does one level up via the
`not _state.puzzle_mode and not _state.friendly_duel and not _pvp` capture-init
guard — `_ghost_duel` needs its own guard added there too so no capture
tracker is created for a ghost duel).

**4. `BattleResultUI.show_ghost_duel_result(did_win: bool, coin_reward: int)`** —
new function mirroring `show_pvp_result`'s structure (title "Victory!"/
"Defeated", explanatory subtitle, a coin line shown only when
`did_win and coin_reward > 0`, single "Continue" button). The button emits a
new `GameBus.ghost_duel_ended(did_win: bool)` signal — **no coin mutation
inside BattleResultUI** (unlike the NPC wager duel) — coin granting happens
exactly once in `SceneManager._on_ghost_duel_ended`, mirroring how
`_on_pvp_battle_ended`-adjacent handlers own the one-shot reward application
rather than a button callback.

**5. `SceneManager._on_ghost_duel_ended(did_win: bool)`** connected in `_ready`'s
signal-wiring block: on win, `save_manager.add_coins(GHOST_DUEL_COIN_REWARD)`
+ `save_manager.save()`; on loss, nothing (no stake existed). Then the same
`_battle_overlay.queue_free()` / `_restore_world()` sequence `_on_duel_won`/
`_on_duel_lost` use. `const GHOST_DUEL_COIN_REWARD: int = 25` — modest,
clearly async (roughly half a basic-enemy coin reward), placed near the top
of SceneManager next to other reward constants.

**6. Rating decision (explicit, per task instructions): NO rating change,
win or lose.** A ghost is an AI-piloted snapshot, not the real remote player
— moving anyone's ELO from a battle they didn't play would let a player farm
their own cached snapshot (or a stale/offline friend's) for free rating with
zero skill-matched risk. Ghost duels only ever grant coins. This is
documented in the docs/agent update and in this Plan so the decision isn't
silently made by omission.

**7. Entry point — WorldScene "Ghost Duels" HUD button (host-only, viewport-relative,
mobile+desktop parity).** Gated on `SessionStore.is_open()` (true only for the
host of an active/adopted co-op session — mirrors `_setup_session`'s existing
host-only precondition; a client has no local `SessionState` to read, a
documented pre-existing constraint of the session model, not something this
task can fix). Opens a new `GhostDuelOverlay` (`extends
"res://scenes/ui/BaseOverlay.gd"`, `.new()`-instantiated, viewport-relative,
rebuilt on `NOTIFICATION_RESIZED` — mirrors the existing overlay pattern, e.g.
`MultiplayerLobbyScene`/`SettingsScene`) listing every `members` entry except
the local host's own token (self-dueling your own live snapshot is a no-op
curiosity, not the intended use), each row showing name + rating + a "Ghost
Duel" button calling
`SceneManager.enter_ghost_duel(SessionState.get_ghost_snapshot(token))`
(`SessionStore.get_state()` supplies the `SessionState` instance; the overlay
is handed the plain `Dictionary` rows, not the SessionState object itself, to
keep it decoupled). Simple list + button — no color swatch (session records
carry no color); good enough for v1 and consistent with the task's "keep this
UI genuinely simple" guidance.

**8. Tests — `tests/unit/test_session_state.gd`** gains a new
"Ghost duel snapshot (GID-102 / TID-377)" section: populated member → correct
`{name, deck, rating}` shape + UID→template_id resolution against
`owned_cards`; blank token, unknown token, and a member dict that isn't a
Dictionary (garbage `from_dict` input) all return `{}` without throwing; a
`player_deck` UID with no matching `owned_cards` entry is skipped rather than
crashing (deck comes back shorter, not broken).

**9. Docs** — new "### Ghost duels (GID-102 / TID-377)" subsection in
`docs/agent/multiplayer-coop.md`, placed after the "PvP Card Battles" major
section (sibling to it, not nested under it, since it explicitly has zero
live networking) — explicitly noting it is the only PvP-flavored mode
needing zero live connection, the host-only entry-point constraint, and the
no-rating-change decision.

## Changes Made

**Scope note:** this worktree's base commit predates TID-370 (rating model),
TID-373 (leaderboard UI), and TID-375 (friends list) — all parallel GID-102
tasks with no formal dependency from TID-377. `SessionState` here is v3 (no
`pvp_rating`); `pvp_rating` is read defensively via `get("pvp_rating", 1000)`
so this becomes forward-compatible once TID-370 merges without any further
change. The entry point uses the session roster directly rather than a
friends list, since TID-375 isn't present in this branch.

- **`game_logic/net/SessionState.gd`**: new `get_ghost_snapshot(token: String)
  -> Dictionary`, pure and derived on demand (no second source of truth).
  Returns `{}` for a blank token, unknown token, or non-Dictionary member
  record. Resolves `player_deck` (a list of card-instance UIDs) to template
  ids via `owned_cards`, skipping any UID with no matching owned-card entry
  rather than crashing. Returns `{token, name, deck: Array[String], rating}`.
- **`autoloads/GameBus.gd`**: new `signal ghost_duel_ended(did_win: bool)`.
- **`autoloads/SceneManager.gd`**: new `const GHOST_DUEL_COIN_REWARD: int =
  25`; new `enter_ghost_duel(opponent_snapshot: Dictionary) -> void` (mirrors
  `_on_duel_requested`'s NPC-duel setup — same `DECK_MIN` guard, same
  `TransitionManager.transition` + `_battle_scene_packed.instantiate()`
  path, no `_pvp`/`_coop_pve` flags); new `_on_ghost_duel_ended(did_win:
  bool)` connected to `GameBus.ghost_duel_ended` in `_ready` — grants the
  flat coin reward exactly once on a win, nothing on a loss (no stake ever
  existed), then restores the world exactly like `_on_duel_won`/
  `_on_duel_lost`.
- **`scenes/battle/BattleScene.gd`**: new inert-unless-set fields
  `_ghost_duel: bool` / `_ghost_duel_reward: int` (same pattern as `_pvp`/
  `_coop_pve`). `_check_game_over` gained a `_ghost_duel` branch (checked
  before the `friendly_duel` branch) that calls the new
  `_result_ui.show_ghost_duel_result(w == 0, _ghost_duel_reward)` instead of
  the enemy-defeat/card-drop path. The capture-tracker init guard now also
  excludes `_ghost_duel` (alongside `puzzle_mode`/`friendly_duel`/`_pvp`).
- **`scenes/battle/BattleResultUI.gd`**: new `show_ghost_duel_result(did_win:
  bool, coin_reward: int)`, structurally mirroring `show_pvp_result` — no
  coin mutation happens on the button press (unlike `show_duel_loss`, which
  deducts a real wager stake); the Continue button only emits
  `GameBus.ghost_duel_ended(did_win)`, so the actual reward grant happens
  exactly once in `SceneManager._on_ghost_duel_ended`.
- **`scenes/ui/GhostDuelOverlay.gd`** (new, + `.gd.uid` auto-generated by the
  headless import): `extends "res://scenes/ui/BaseOverlay.gd"` by path
  string, `.new()`-instantiated, viewport-relative, rebuilt on
  `NOTIFICATION_RESIZED` — mirrors `MultiplayerLobbyScene`. Lists
  `{token, name, rating}` rows (set via `set_rows`) with a "Ghost Duel"
  button per row; `on_duel_requested: Callable` lets the caller resolve the
  snapshot and launch the battle, keeping the overlay decoupled from
  `SessionStore`/`SessionState`.
- **`scenes/world/WorldScene.gd`**: new host-only "Ghost Duels" HUD button
  (`_ensure_ghost_duel_button`, called right after `_setup_session()` inside
  `_setup_coop`) gated on `SessionStore.is_open()` (not
  `NetworkManager.is_active()`) — naturally host-only, since only the
  authority ever opens `SessionStore` (`_setup_session` early-returns for
  non-hosts). `_toggle_ghost_duel_overlay` builds the roster row list from
  `SessionStore.get_state().members` (excluding the local host's own token)
  and opens `GhostDuelOverlay`, wiring `on_duel_requested` to
  `SessionState.get_ghost_snapshot(token)` + `SceneManager.enter_ghost_duel`.
- **`tests/unit/test_session_state.gd`**: 9 new test cases under a new
  "Ghost duel snapshot (GID-102 / TID-377)" section — populated-member shape
  (name/deck/rating), UID→template_id resolution (including proving the raw
  UID never leaks into the deck), custom-rating passthrough, blank token,
  unknown token, a non-Dictionary member record (corrupt-file tolerance), a
  `player_deck` UID with no matching `owned_cards` entry (dangling-UID
  tolerance — skipped, not a crash), an entirely empty `owned_cards` list,
  and a missing `display_name` defaulting to `"Player"`.
- **`tasks/backlog/BID-032--ghost-duels-host-only-entry-point.md`** (new; originally
  self-numbered BID-025, renumbered during integration since BID-025 was already
  claimed by an unrelated finding on the integration branch):
  logs the discovered gap that ghost duels are host-only in this slice (a
  client has no local `SessionState` to read a roster from) as a follow-up,
  with a concrete suggested RPC-based fix.
- Validation: `godot --headless --editor --quit` parse/compile-error grep is
  empty. Full suite `godot --headless --path . -s tests/runner.gd` reports
  **1699 passed, 0 failed, 1 pending** (pending is pre-existing and
  unrelated; baseline before this task was 1690 passed, 0 failed, 1
  pending — this task added exactly 9 new passing tests, no regressions).

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: new top-level "## Ghost duels (GID-102 /
  TID-377)" section (placed after "Shared party bounties", before
  "Persistent Sessions" — sibling to "PvP Card Battles", not nested under
  it, since ghost duels explicitly need zero live networking) covering: why
  this isn't PvP host-mirroring, the snapshot-extraction helper, the
  host-only HUD entry point and why (`SessionStore.is_open()` is only ever
  true on the authority), the battle-entry mechanics, the explicit
  no-rating-change / coins-only reward decision, and a "Known gap" pointer
  to BID-032 (client-side entry point is a follow-up). Also updated the
  `test_session_state.gd` row in the Tests table with the new case count
  and ghost-duel coverage description.
