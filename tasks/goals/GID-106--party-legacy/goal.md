# GID-106: Party Legacy — Co-op Endless Spire & Guildhall

## Objective

Give a persistent co-op session long-run identity through a shared roguelike mode and a physical home that displays the party's history.

## Context

Co-op sessions today are transient shared-world experiences (up to 4 players in madrian, GID-094). `SessionState` persists members' characters and leaderboards across reconnects, but the session lacks a **destination** — a place where the party can revisit collective wins and make forward progress together in a replayable mode. The Endless Spire (GID-038) is already the game's most replayable single-player mode, offering escalating boss floors and an interactive draft flow. Adapting it for co-op with authority-orchestrated alternating draft picks (reusing the loot-roll pattern from TID-381) makes it a centerpiece activity. Pairing that with a shared guildhall interior (modeled after Player Home GID-046) — populated with trophies from joint clears, a shared garden driven by session days, and a physical stash chest — transforms a session from "we played together" into "we have a home with our history in it." This is the final vertical slice that makes co-op feel persistent and lived-in.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-390 | Co-op Spire — shared run & alternating draft | agent | done (headless import + test run unverified in-sandbox — see note below) | — |
| TID-391 | Co-op Spire — joint floor battles & leaderboard | agent | done (headless import + test run unverified in-sandbox — see note below) | TID-390 |
| TID-392 | Party guildhall interior & entry | agent | done (headless import + test run unverified in-sandbox — see note below) | — |
| TID-393 | Guildhall trophies, garden & stash chest | agent | pending | TID-392 |

## Acceptance Criteria

- [ ] A party can launch a shared-seed Endless Spire run together with authority-orchestrated alternating draft picks (one card per round, rotating among members), reusing the loot-roll prompt-session pattern
- [ ] Floor battles execute via the joint PvE engine (GID-099) and feed `SessionState.record_pve_score` with a richer value signal than party size (e.g. highest floor reached, party composition, maybe elapsed session day)
- [ ] Run summary is shown to all peers (reusing `RunSummaryScene` with cosmetic co-op variant); handling disconnect mid-run is documented (run continues for remaining members)
- [ ] The party can enter a shared session-owned guildhall interior map together (separate from single-player home)
- [ ] Guildhall renders trophies auto-populated from session's joint boss clears (`coop_clears` leaderboard), shared garden plots advancing on session `days_elapsed`, and a physical stash chest entity that opens `PartyStashOverlay`
- [ ] Single-player unchanged byte-for-byte; all co-op code guarded by `NetworkManager.is_active()`
- [ ] Unit suite passes; headless import check clean (`godot --headless --editor --quit`)

## Notes

**TID-390:** the sandbox this task ran in has no Godot binary, and the documented install
recipe (downloading the Godot 4.6 release zip) is blocked by the environment's egress
policy (HTTP 403 from the agent proxy — an organization policy denial, not a transient
failure, so per the proxy's own guidance it was not retried or routed around). The
headless import check and `tests/runner.gd` run could not be executed. A thorough manual
review was done instead (balance/indentation/duplicate-symbol checks, every `:=`
inference site verified against a concretely-typed RHS, every RPC/handler name
cross-checked end-to-end) and caught one real bug before it shipped (see TID-390's
Changes Made). **Run `godot --headless --editor --quit` and `godot --headless --path . -s
tests/runner.gd` before merging** — same caveat pattern as GID-102/103/105/110.

**TID-391:** same sandbox constraint (HTTP 403 reconfirmed this session, no Godot binary
available). Manual review caught a genuine design gap in TID-390's shipped code —
`SceneManager.is_coop_spire_active()` never becomes true on a non-host peer (no call site
for `set_coop_spire_run_mirror` existed) — routed around via a map-name-based check
(`WorldScene._in_coop_spire_floor()`) rather than deep-fixing the mirror, and corrected the
inaccurate doc claim this left behind. Also traced the exact tree-detachment timing of
`GameBus.coop_pve_battle_ended` and deferred all `get_tree()`-touching work in the new
handlers to `_enter_tree()` (a pending-flag pattern mirroring the existing
`_pvp_ended_pending_broadcast`) rather than assuming it would work mid-detachment. Filed
BID-044 for a suspected analogous (pre-existing, unfixed) race in the co-op siege-boss
engage path. **Run `godot --headless --editor --quit` and
`godot --headless --path . -s tests/runner.gd` before merging.**

**TID-392:** same sandbox constraint (HTTP 403 reconfirmed again this session). Generated
`assets/maps/guildhall.tres` with a throwaway script reusing `scripts/convert_maps.py`'s
`write_tres()` directly (hand-built data dict, no `.txt` source needed) since the in-game
map editor isn't available either; verified the resulting tile/height arrays parse to
exactly 10000 entries each with a Python parity check. **Run `godot --headless --editor
--quit` and `godot --headless --path . -s tests/runner.gd` before merging** (also to confirm
the new `.tres` actually loads/imports cleanly, which cannot be verified without Godot).
