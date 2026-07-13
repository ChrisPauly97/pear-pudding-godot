# TID-434: Thread the Draft-Deck Override Through PvP Resume

**Goal:** GID-115
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Promotes **BID-035**. Draft duels (GID-104) hand each combatant a transient drafted
deck via the `local_deck_override` parameter of `SceneManager.enter_pvp_battle`. The
grace-window reconnect path (`SceneManager.resume_pvp_battle`, TID-372) does not carry
that override, so a resumed **host** rebuilds players[0] from its persistent collection
instead of the drafted deck — silently corrupting the sealed-deck format mid-duel.
Client-side resume is unaffected (clients never build decks; they render the host's
mirror).

## Research Notes

- `autoloads/SceneManager.gd:601` — `enter_pvp_battle(..., local_deck_override: Array = [])`;
  the override is captured at line 609 and applied to the battle overlay at line 621
  (`_battle_overlay.set("pvp_local_deck_override", captured_local_deck)`). Doc comment
  at lines 590–600 explains both the resume path and the override.
- `autoloads/SceneManager.gd:641` — `resume_pvp_battle(local_player_idx: int,
  opponent_deck: Array, ante_coins: int)` — no deck-override parameter. This is the gap.
- `autoloads/NetworkManager.gd:160` — `set_pvp_resume(local_idx: int, opponent_deck:
  Array, ante_coins: int)` — the state stashed for the grace-window reconnect; also
  lacks the override. BID-035's suggested fix: thread `local_deck_override` through
  `set_pvp_resume` storage and back out through `resume_pvp_battle` into
  `enter_pvp_battle`'s parameter.
- **Where the resume state is captured:** grep `set_pvp_resume` call sites — the
  caller that stashes resume state when a PvP battle starts/disconnects must now also
  pass the active override (the same value handed to `enter_pvp_battle`). Grep
  `resume_pvp_battle` call sites for the consumer (reconnect handshake in
  WorldScene/NetSync).
- **Draft deck origin:** `scenes/world/WorldScene.gd` draft flow — the drafted deck is
  submitted around lines 8563–8598 (`submit_draft_duel_deck`, `_pvp_ante_peer1`,
  `recv_pvp_active`) and passed into `enter_pvp_battle`. Confirm the exact variable
  holding the local drafted deck so the resume stash captures the same one.
- Ordinary (non-draft) duels pass an empty override — threading it through must keep
  `[]` semantics (empty = build from collection) so normal resume behavior is
  unchanged.
- Watch GDScript pitfalls: dictionary/array values are plain `Array` — if the override
  is stored in a resume-state Dictionary, re-typing on the way out needs `assign()` or
  an untyped `Array` parameter (see CLAUDE.md Variant-inference notes).
- Tests: GID-104/TID-385 added draft-duel tests (grep `tests/` for `draft`); TID-372
  added resume tests if any (grep for `resume_pvp` / `pvp_resume`). Add/extend a unit
  test asserting the override survives a `set_pvp_resume` → `resume_pvp_battle`
  round-trip.
- Update `docs/agent/multiplayer-coop.md` (PvP / draft duel sections mention the
  reconnect grace window) once fixed.
- After the fix, move
  `tasks/backlog/BID-035--draft-duel-resume-lacks-deck-override.md` to
  `tasks/archive/backlog/` and update `tasks/index.md`.

## Plan

1. Trace the full resume chain before touching anything:
   `BattleScene._setup_pvp_battle` → `NetworkManager.set_pvp_resume` (stash) →
   `MultiplayerLobbyScene._on_connection_succeeded` → `SceneManager.resume_pvp_battle`
   → `SceneManager.enter_pvp_battle` (consume) → `BattleScene._build_pvp_decks`
   (actually reads `pvp_local_deck_override`, host-only branch).
2. **Finding that changes the risk profile of this task**: `_build_pvp_decks` only
   reads `pvp_local_deck_override` inside the `_is_pvp_host()` branch (`multiplayer
   .is_server()` — the listen-server host, always duel-idx 0 per
   `local_idx = 0 if NetworkManager.is_host() else 1` used by every entry point:
   `_enter_pvp`, `_enter_pvp_wagered`, `_maybe_enter_draft_duel`). `set_pvp_resume`
   is called **only** from the `elif _local_player_idx >= 0` branch — the branch
   that runs precisely when `_is_pvp_host()` is false — and `_on_pvp_session_ended`
   guards resume eligibility with `_local_player_idx == 1` explicitly. The
   pre-existing doc comment on `set_pvp_resume` already says outright: "0 host-side
   convention is never used here — only client idx 1 calls this." So the literal
   "resumed host rebuilds from collection" scenario in BID-035's title is not
   reachable today: the deck-building host is never the reconnecting peer, and the
   reconnecting client never calls `_build_pvp_decks` at all (host-authoritative
   mirror — clients render, they don't build). This isn't a rejection of the task:
   threading the parameter through is still correct, cheap, and closes a real
   "signature drift" gap (`resume_pvp_battle` silently dropped a parameter
   `enter_pvp_battle` otherwise always threads through) that would matter the
   moment this codebase ever adds host-migration or symmetric resume. Implemented
   as originally scoped rather than filing a "not reproducible" backlog note,
   since the fix is a straight, low-risk, no-behavior-change plumbing job either way.
3. Thread `local_deck_override: Array = []` through, in order:
   `NetworkManager.set_pvp_resume` (store in the `_pvp_resume` dict) →
   `BattleScene._setup_pvp_battle`'s call site (pass `pvp_local_deck_override`) →
   `MultiplayerLobbyScene._on_connection_succeeded` (read
   `resume.get("local_deck_override", [])`) → `SceneManager.resume_pvp_battle`
   (accept + forward) → `SceneManager.enter_pvp_battle` (already accepts it,
   unchanged).
4. Add `tests/unit/test_pvp_resume.gd` exercising the `NetworkManager` autoload
   directly (mirrors `test_scene_manager_state.gd`'s save/restore-around-each-test
   style): override round-trips through `set_pvp_resume`/`get_pvp_resume`, defaults
   to `[]` when omitted, other fields (`local_idx`/`ante_coins`) still preserved,
   and `clear_pvp_resume` drops it.
5. Document the plumbing — and the current-inertness finding — in
   `docs/agent/multiplayer-coop.md`'s "Reconnecting into an in-progress duel"
   section.
6. Archive `BID-035` and update `tasks/index.md`.

## Changes Made

- `autoloads/NetworkManager.gd` — `set_pvp_resume` gained a fourth
  `local_deck_override: Array = []` parameter, stored in `_pvp_resume` as
  `"local_deck_override"`.
- `scenes/battle/BattleScene.gd` — `_setup_pvp_battle`'s resume-arming call now
  passes `pvp_local_deck_override` as the fourth argument.
- `autoloads/SceneManager.gd` — `resume_pvp_battle` gained the same fourth
  parameter and forwards it into `enter_pvp_battle`'s existing
  `local_deck_override` slot (passing explicit `""`/`false` for the
  `opponent_token`/`ranked` positional params in between, unchanged from before).
- `scenes/ui/MultiplayerLobbyScene.gd` — `_on_connection_succeeded` reads
  `resume.get("local_deck_override", [])` and passes it through to
  `resume_pvp_battle`.
- `tests/unit/test_pvp_resume.gd` — new unit test suite (auto-discovered by
  `tests/runner.gd`): no-resume-by-default, override round-trip, default-empty
  when omitted, other fields preserved, override cleared with the rest of the
  record.
- Archived `tasks/backlog/BID-035--draft-duel-resume-lacks-deck-override.md` to
  `tasks/archive/backlog/` and updated `tasks/index.md`.

**Important finding, documented inline at every touched site**: as coded today,
this path is unreachable — only client idx 1 (never the deck-building host)
ever calls `resume_pvp_battle`, so the override is presently inert in
production. This was already hinted at in `set_pvp_resume`'s pre-existing doc
comment ("0 host-side convention is never used here"). Flagging this
prominently rather than silently declaring the acceptance criterion
vacuously satisfied — the plumbing is still worth having (closes a real
signature-drift gap, zero behavior change, cheap), but a future reader should
not assume this fix was exercised against a live repro.

**Verification note:** same sandbox constraint as the rest of this goal — no
Godot binary, release-zip download blocked by the proxy (403). Every call site
was re-read post-edit to confirm the parameter threads through unchanged in
type and position; `tests/net_pvp_reconnect_smoke.gd` (existing GID-102/TID-372
on-demand ENet-loopback smoke test) would be the right place to add a draft-duel
variant if this path is ever made reachable, but that's out of scope here given
the inertness finding above.

## Documentation Updates

- `docs/agent/multiplayer-coop.md` — "Reconnecting into an in-progress duel"
  section: `set_pvp_resume`/`resume_pvp_battle`'s signatures updated to show the
  new parameter, with a note explaining both what it's for and why it's
  currently inert in production.
