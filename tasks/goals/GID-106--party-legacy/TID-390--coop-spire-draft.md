# TID-390: Co-op Spire — Shared Run & Alternating Draft

**Goal:** GID-106
**Type:** agent
**Status:** in-progress
**Depends On:** —

## Lock

**Session:** claude/GID-106--party-legacy
**Acquired:** 2026-07-05T15:12:40Z
**Expires:** 2026-07-05T15:42:40Z

## Context

The Endless Spire (GID-038) is the game's most replayable single-player mode — players enter at floor 1, defeat progressively harder bosses, and pick from 3-card-1 drafts between each floor before the run ends on a loss. Today it is single-player only. To make it a co-op anchor feature, this task adapts the run for a party: the same seed-based floor composition, but the deck is **shared and built collaboratively** via alternating draft picks. This transforms the Spire from "I climb the tower" into "we climb the tower together," giving the co-op session a replayable, goal-oriented activity beyond just exploring madrian.

The authority orchestrates the draft flow using the **loot-roll prompt pattern** (TID-381: broadcast draft options to all, the active picker submits choice via RPC, authority applies + broadcasts result, auto-pick on timeout). Each member's turn cycles in party member order round-robin. The resulting run deck is **transient** — never written to any member's `owned_cards`; it lives in memory for the duration of the run and is discarded on completion. A co-op Spire run entry point (host-only button) and a "waiting for <name>" state for inactive pickers complete the flow.

## Research Notes

**Entry point — host-only HUD button (TID-380 pattern).** WorldScene spawns a "Co-op Spire" button (viewport-relative, sized per CLAUDE.md parity rules) visible only to the host (`NetworkManager.is_host()`) and only when not already in a battle/overlay. On press, route to `SceneManager.enter_spire_coop()` (new method), which enters the Spire with a `coop_mode = true` flag (new `SpireScene` field) and seeds the run with `_shared_seed` computed from `SessionStore.get_state().session_id` (deterministic, all peers derive the same seed). Single-player routes through the existing `enter_spire()` path, unaffected.

**Shared seed & identical floor composition.** The Spire's floor generation already keys off a seed (`game_logic/SpireFloorGen.gd`), so all peers independently compute the same floor bosses given the same seed. No new wire format needed — the seed is a single constant derived per run.

**Draft orchestration — reuse loot-roll pattern (TID-381).** The authority holds a `_coop_spire_draft_session: Dictionary` with `{active_picker_idx, round, pending_choices, auto_pick_timer}`. On floor completion:
1. Fetch 3-card draft options (standard `SpireFloorGen` logic).
2. Broadcast `NetSync.recv_spire_draft_start(options, active_picker_token, active_picker_name)` (reliable RPC).
3. Set a timeout (e.g. 30 s) for auto-pick if the active picker doesn't respond.
4. The active picker (any peer, identified by their `SessionState` token) receives the prompt and calls `NetSync.submit_spire_draft_choice(card_idx)` (reliable).
5. Authority applies the choice, advances the picker index (`(i + 1) % party_size`), and broadcasts `NetSync.recv_spire_draft_choice(card_uid, next_active_picker_token)` to all.
6. On all peers, the UI updates: "Drafting… [card name]" becomes "Waiting for <name>…" until the next choice arrives.
7. Loop until the deck reaches the target size (existing Spire draft logic).

**New pure wire helper in `game_logic/net/SpireDraftSync.gd`** (mirrors `AvatarSync.gd`, `BattleNetProtocol.gd`):
- `encode_draft_start(options, active_picker_token, active_picker_name) -> Array`
- `encode_draft_choice(card_uid, next_active_picker_token) -> Array`
- `decode_draft_start(payload) -> Dictionary` — fully defaulted, garbage-safe
- `decode_draft_choice(payload) -> Dictionary` — fully defaulted

**Draft UI — reuse SpireScene's existing draft overlay, add "waiting" state.** `SpireScene._show_draft_overlay()` already displays 3 selectable card buttons. When `_coop_draft_active` and this peer is not the picker, disable all buttons and show a banner "Waiting for <name> to pick…" (fetched from the broadcast payload or looked up in `WorldScene._remote_identities[peer_id]`). Readonly mode on non-authority peers — client draft UI is disabled until the authority applies the choice and broadcasts the next picker's turn. The banner updates on each `recv_spire_draft_choice` broadcast, so the waiting player sees "Waiting for Alice…" → apply → "Your turn!" → draft buttons re-enabled.

**Transient shared deck.** SpireScene gains a `_coop_shared_deck: Array[String]` (not persisted, not written to SaveManager or SessionState). It accumulates during draft picks and is passed to `_setup_floor_battle(coop_shared_deck)` when entering a floor. Non-co-op runs use the existing single-player `_player_deck` flow unchanged.

**Project invariants.** All co-op Spire code guarded by `NetworkManager.is_active()` (single-player entirely unchanged). New wire format is pure, unit-testable helper in `game_logic/net/`. Headless import must pass after any `.gd` edit. HUD button sized viewport-relative (parity for mobile). No `.uid` sidecar issues since no new `.tres` resources created.

## Plan

**Scope boundary vs. TID-391 (verified against actual code, not just the Research Notes):**
Single-player Spire battles are entirely `SaveManager.spire_run`-driven (`BattleScene.gd:297-306`
builds the fighter's deck from `draft_deck`, falling back to a fixed 8-card starter when empty)
and the draft only happens **once per floor clear**, triggered from
`SceneManager._on_battle_won`'s `is_spire_active()` branch — there is no "loop until the deck
reaches a target size" in the actual codebase (the Research Notes overstate this; verified by
reading `SpireDraftScene._on_pick` which `queue_free()`s after exactly one pick). Reaching a real
floor-clear in co-op requires the **joint PvE battle engine** (`SceneManager.enter_coop_pve_battle`,
GID-099) and a shared `cleared_flag` write — both explicitly TID-391's job ("joint floor battles").
This task therefore delivers: the entry point, shared-seed run start, and a **complete,
independently testable draft-orchestration engine** with one clearly-named hook
(`WorldScene._start_coop_spire_draft(floor)`) that TID-391 calls once it has a real win condition.
This mirrors the precedent already in this codebase (e.g. TID-355 built `recv_map_transition`
with nothing yet calling it for Spire; TID-380 was the first real caller for dungeons).

**Deviation from Research Notes' seed derivation:** rather than deriving `_shared_seed` from
`SessionStore.get_state().session_id` (fragile — every peer would have to independently
recompute the identical hash), reuse the **exact `_start_dungeon_crawl` pattern already proven
in `WorldScene.gd:2221-2235`**: host rolls `randi()` (or a `SessionStore`-derived value for
same-day reproducibility, mirroring the dungeon-crawl/siege precedent), builds
`target_map = "spire_floor_1_%d" % seed`, and reuses the **existing, untouched**
`recv_map_transition` RPC (TID-355) to fan it out — the seed needs no new wire field since it's
embedded in the map name string, and `WorldScene._ready`'s existing `spire_floor_` parsing
(`WorldScene.gd:476-483`) already regenerates the identical floor on every peer. Zero new RPCs
needed for run start/floor loading.

**State ownership across floor transitions (a map transition destroys/recreates WorldScene,
so per-floor WorldScene fields — the pattern the docs call out as *not* surviving, e.g. Co-op
Siege — cannot hold run state).** New transient dict on the `SceneManager` autoload (survives
scene changes, mirrors `SaveManager.spire_run`'s shape but is **never persisted** to
save.json or the session file — matches the task's explicit "transient, discarded on
completion" requirement):

```gdscript
# autoloads/SceneManager.gd
var _coop_spire_run: Dictionary = {"active": false}
# shape when active: {active, seed, floor, shared_deck: Array[String], hero_hp,
#                      picker_order: Array[String], picker_idx: int}  (picker_order/idx
#                      only meaningful on the host — clients never read them)
```

New `SceneManager` methods (mirror the existing single-player `enter_spire`/`start_spire_run`/
`advance_spire_floor`/`add_drafted_card`/`end_spire_run` shape, so behavior is easy to diff
against the single-player original):
- `is_coop_spire_active() -> bool`, `get_coop_spire_run() -> Dictionary` (read-only accessors,
  every peer keeps a locally-mirrored copy updated via RPC broadcasts — same "authoritative on
  host, mirrored elsewhere" model as `_leaderboard_rows`/`_remote_identities`).
- `enter_spire_coop() -> void` — host-only (caller enforces `NetworkManager.is_host()`, same
  defensive comment as `_start_dungeon_crawl`); resumes if `is_coop_spire_active()`, else starts
  fresh: builds `picker_order` from `[MpProfile.get_token()] + _remote_identities` tokens
  (captured once, at run start — offline/late-joining members simply aren't in the rotation,
  documented as a v1 scope decision mirroring the loot-roll "present = connected" simplification),
  seeds `shared_deck = []`, `hero_hp = 30`, `floor = 1`.
- `add_coop_drafted_card(card_id: String) -> void` — appends to `shared_deck` (no-op if run
  inactive), mirrors `SaveManager.add_drafted_card`.
- `advance_coop_spire_floor() -> void` — bumps `floor` (mirrors `SaveManager.advance_spire_floor`).
- `end_coop_spire_run() -> Dictionary` — clears state, returns final stats shape (mirrors
  `SaveManager.end_spire_run`'s return shape, minus the coin/story-flag side effects, which are
  single-player-save concepts that don't apply to a session).
- `set_coop_spire_run_mirror(run: Dictionary) -> void` — lets a non-host peer overwrite its local
  cache wholesale from a broadcast (clients never mutate the dict directly).

These are built and unit-testable now (pure dictionary mutation); TID-391 calls
`advance_coop_spire_floor()`/`end_coop_spire_run()` from its battle-end hook without needing to
touch `SceneManager`'s state shape at all.

**Pure wire helper — `game_logic/net/SpireDraftSync.gd`** (new, mirrors `LootRoll.gd`'s exact
style: `RefCounted`, static functions, JSON-primitive Dictionary/Array payloads, fully-defaulted
garbage-tolerant decoders):
- `encode_draft_start(floor: int, options: Array, active_picker_token: String, active_picker_name: String) -> Dictionary`
  / `decode_draft_start(payload: Variant) -> Dictionary`.
- `encode_draft_choice(card_id: String, next_active_picker_token: String, next_active_picker_name: String) -> Array`
  / `decode_draft_choice(payload: Variant) -> Dictionary`.
- No wire helper needed for the client→authority pick itself — mirrors
  `submit_loot_roll_choice(roll_id, choice)`'s plain-RPC-params precedent: `submit_spire_draft_choice(card_idx: int)`.

**RPCs — `scenes/world/NetSync.gd`** (reliable, `any_peer`/`call_remote`, exact style of the
existing `recv_loot_roll_start`/`submit_loot_roll_choice`/`recv_loot_roll_result` trio at
`NetSync.gd:510-547`):
- `recv_spire_draft_start(payload: Dictionary)` → forwards to `world_scene._on_spire_draft_start_received(payload)`.
- `submit_spire_draft_choice(card_idx: int)` → forwards sender + idx to `world_scene._on_spire_draft_choice_submitted(sender, card_idx)`.
- `recv_spire_draft_choice(payload: Array)` → forwards to `world_scene._on_spire_draft_choice_received(payload)`.

**`WorldScene.gd` orchestration** (guarded by `_coop_active` throughout; new consts
`_SpireDraftSync`, `_SpireDraft`, `_SpireFloorGen` preloads):
- `_start_coop_spire_draft(floor: int) -> void` (authority-only entry point, the TID-391 hook):
  seeds an RNG from `SceneManager.get_coop_spire_run().seed + floor` (byte-identical seeding to
  single-player's `SpireDraftScene.setup`), calls `SpireDraft.new().generate_picks(...)` for the
  3 options, resolves the current picker from `picker_order[picker_idx]`, broadcasts
  `recv_spire_draft_start` (self-applies locally + `_net_sync.rpc(...)` to others, matching the
  existing "call local handler directly for self, rpc to others" idiom), and starts a 30s
  auto-pick timeout (ticked from the existing `_process`, alongside `_tick_loot_rolls`).
- `_on_spire_draft_start_received(payload: Dictionary) -> void` (every peer): decodes, shows the
  draft overlay (interactive if `active_picker_token == MpProfile.get_token()`, else a disabled
  "Waiting for `<name>`…" banner variant — reuses `SpireDraftScene`, not a new scene).
- `_submit_spire_draft_choice(card_idx: int)` (picker's local button press) → local RPC to
  authority, or direct call if this peer *is* the authority (same self-vs-remote branching as
  `_start_loot_roll`).
- `_on_spire_draft_choice_submitted(sender, card_idx)` (authority only): validates sender matches
  the expected active picker (silently ignored otherwise — mirrors the loot-roll "unexpected
  sender" tolerance), resolves the picked card, calls `SceneManager.add_coop_drafted_card`,
  advances `picker_idx = (picker_idx + 1) % picker_order.size()`, broadcasts
  `recv_spire_draft_choice`.
- `_tick_coop_spire_draft(delta)` (authority only, called from `_process`): on timeout,
  auto-picks options[0] (documented, mirrors the loot-roll auto-pass-on-timeout precedent, just
  auto-*pick* since a Spire draft has no "decline" option).
- `_on_spire_draft_choice_received(payload)` (every peer): applies to the local
  `SceneManager` mirror via `set_coop_spire_run_mirror`, closes the draft overlay if open, shows
  a `GameBus.hud_message_requested` toast naming the card + next picker.
- `_on_coop_session_ended`: clears any in-flight coop-spire-draft overlay/timer state (same
  cleanup list as the other session-scoped systems in that function).

**Entry point — Party panel action, not a HUD button** (matches the GID-107 HUD Action Registry
rule in CLAUDE.md and the exact `show_dungeon_crawl`/`on_dungeon_crawl` precedent in
`PartyPanel.gd:39-40` + `WorldScene._open_party_panel`):
- `PartyPanel.gd`: add `show_spire: bool` / `on_spire: Callable`, one more
  `_add_action_button(grid, "Co-op Spire", on_spire, true)` call.
- `WorldScene._open_party_panel()`: `panel.show_spire = NetworkManager.is_host()`,
  `panel.on_spire = _start_coop_spire`.
- `WorldScene._start_coop_spire() -> void` (host-only, mirrors `_start_dungeon_crawl`'s defensive
  shape): calls `SceneManager.enter_spire_coop()` (which internally does the
  `_net_sync.rpc("recv_map_transition", target_map, "") ` + local `enter_map` dance) — no new RPC.

**SpireDraftScene reuse** (`scenes/ui/SpireDraftScene.gd`): add `setup_coop(floor, options:
Array[String], is_my_turn: bool, picker_name: String) -> void` alongside the existing
`setup(floor)` — skips `SpireDraft`/RNG generation (uses the passed-in `options` verbatim so
every peer renders identical cards from the authority's broadcast, never regenerating locally),
and in `_on_pick` branches: co-op + is_my_turn → call back to WorldScene's submit function
instead of touching `save_manager`/`GameBus.spire_card_drafted` directly (that emission stays
single-player-only, since the co-op grant path is `SceneManager.add_coop_drafted_card`, not
`SaveManager.add_drafted_card`); co-op + not is_my_turn → all 3 "Pick" buttons disabled, extra
banner Label "Waiting for `<picker_name>`…". Single-player `setup(floor)` path is completely
unchanged.

**Tests — `tests/unit/test_spire_draft_sync.gd`** (new): encode/decode round-trip for both
helpers, garbage/null/non-container tolerance (empty options array, non-Dictionary payload,
short/garbage choice array), mirrors `test_loot_roll.gd`'s structure. Also add
`tests/unit/test_scene_manager_coop_spire.gd` or extend an existing SceneManager test file (need
to check what already exists) for `add_coop_drafted_card`/`advance_coop_spire_floor`/
`end_coop_spire_run` state transitions (pure dict mutations, no scene needed) — will confirm
exact existing test file layout before writing.

**Docs** — new "Co-op Endless Spire" section in `docs/agent/multiplayer-coop.md` (mirrors the
"Shared dungeon crawl" section's structure/tone): entry point, seed/state ownership
(`SceneManager._coop_spire_run`, transient, why it can't live on WorldScene or SessionState),
the draft engine (RPCs, pure helper, UI reuse, auto-pick timeout), and an explicit "Floor battles
and leaderboard submission are TID-391" pointer so the doc doesn't imply a feature that isn't
wired yet. Add a row to the docsplan.md table only if a dedicated file is warranted — likely
not, this stays a section within the existing file per "Avoiding Documentation Sprawl."

**Validation:** `godot --headless --editor --quit` (filtered for Parse/Compile/Failed-to-load) +
full `godot --headless --path . -s tests/runner.gd` run before committing.

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
