# BID-026: Co-op PvE host/ally attacks resolved against the wrong opponent index (fixed)

**Category:** code-smell (fixed opportunistically during GID-102 / TID-371)
**Discovered During:** GID-102 / TID-371 (2v2 team duels)

## Summary

While generalizing `BattleScene._opp_idx()`/attack resolution for team PvP, found two
pre-existing bugs in co-op PvE (GID-099) that assumed 2-player indexing wherever the
"opponent" was the boss (index N, N can be > 1 for any co-op battle with ≥2 allies):

1. **`_execute_attack`** (the host's own *local* attack resolution — only a CLIENT's
   attacks are relayed through `_apply_remote_intent`; the host plays its own actions
   directly) hardcoded `_state.players[1]` for the defender and `_state.players[0]` for
   the attacker. In co-op PvE the boss is always at the *last* index (≥ 2), never index
   1, so the host's own attacks on the boss damaged/removed against **ally-1's board**
   (a teammate) instead of the boss's.
2. **`_apply_remote_intent`** (shared by 2-player PvP and co-op-PvE ally-client relayed
   intents) computed `opp_idx = 1 - player_idx` unconditionally. For an ally CLIENT
   (idx ≥ 1) relaying an ATTACK intent, this resolves to an arbitrary/wrong index — and
   for idx ≥ 2, GDScript's negative-index array wraparound (`players[-2]` etc.) makes it
   silently resolve to a *different* ally's board rather than erroring.

Both bugs are **always reachable** in any co-op-PvE battle (any host attack, any ally
client attack), not an edge case — they were caught only by code reading while building
team PvP, not by a failing test, because `_execute_attack`/`_apply_remote_intent`'s
host-local attack paths have no scene-level test coverage (only pure `GameState`-adjacent
logic is unit-tested; see `docs/agent/multiplayer-coop.md` Tests table — there is no
co-op-PvE attack-resolution smoke test, unlike PvP's `net_pvp_smoke.gd`).

## Fix (already applied in GID-102 / TID-371)

- `_execute_attack`: replaced `_state.players[1]`/`_state.players[0]` with
  `_state.players[_opp_idx()]`/`_state.players[_my_idx()]` — behavior-preserving for
  solo/2-player PvP (where those already equal 1/0), genuine fix for co-op PvE.
- `_apply_remote_intent`: `opp_idx` is now computed by a new
  `_resolve_intent_opp_idx(intent, player_idx)` helper that returns the boss index
  unconditionally for `_coop_pve`, the 2-player `1 - player_idx` otherwise, and a
  team-PvP-aware resolution for `_team_pvp`. `_resolve_remote_attack` takes the
  resolved defender index as a parameter instead of recomputing `1 - attacker_pid`.

## Residual gap

`_execute_attack`/`_apply_remote_intent`/`_resolve_remote_attack` are deeply embedded
`Node`/internal methods with no isolated scene-level test harness today (unlike the pure
`GameState`/`SpellEffectResolver` logic, which IS unit-tested). Consider adding a
co-op-PvE attack-resolution smoke test (mirroring `net_pvp_smoke.gd`/
`net_coop_npeer_smoke.gd`) that exercises a host attacking the boss with ≥2 allies
present, to catch index-resolution regressions like this one automatically.

## Files

- `scenes/battle/BattleScene.gd` — `_execute_attack`, `_apply_remote_intent`,
  `_resolve_intent_opp_idx` (new), `_resolve_remote_attack`
