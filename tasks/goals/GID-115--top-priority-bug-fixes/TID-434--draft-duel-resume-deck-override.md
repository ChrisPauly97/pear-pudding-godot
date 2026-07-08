# TID-434: Thread the Draft-Deck Override Through PvP Resume

**Goal:** GID-115
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
