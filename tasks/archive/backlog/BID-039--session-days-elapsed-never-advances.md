# BID-039: SessionState.days_elapsed is never advanced by any co-op tick

**Type:** gap (feature dependency)
**Discovered during:** GID-102 / TID-378 (Async card auction house)
**Severity:** low

## Context

`SessionState.days_elapsed` exists and round-trips correctly through persistence, and
is read in a few places (e.g. the dungeon-crawl seed at `WorldScene.gd:1829`,
`"_dungeon_" + str(st.days_elapsed)`), but nothing in the co-op runtime ever
**increments** it. Unlike single-player `SaveManager.days_elapsed` (advanced by
`advance_day()`, tied to sleeping/resting), the session's copy is authority-created
at `0` and stays there for the life of the session file.

This was surfaced while building the auction house (TID-378): listing expiry
(`AuctionTransfer.settle_expired`) is driven entirely by
`expires_day <= current_day`, hooked into the closest existing periodic host tick
(`_tick_session_persist`, called from `_sweep_expired_auctions`). The sweep is fully
implemented and unit-tested, but in a live session it never fires in practice —
`days_elapsed` never reaches a fresh listing's `expires_day` (default `days_elapsed
+ 3` at list time, and `days_elapsed` never moves).

This mirrors the BID-024 pattern: a correctly-built, unit-tested system that is
**dormant in practice** pending another goal, not a code bug to fix here.

## Who fills this gap

**GID-103 "Shared World Life — Synced Clock, Weather, Night Hunts & Town Siege"**
(pending) exists specifically to wire a synced day/night clock across co-op. Once
that lands and `SessionState.days_elapsed` advances on a real cadence, the auction
sweep activates automatically — no auction-house code change needed.

## Notes

- No code change required here; this is a sequencing/reachability note for whoever
  picks up GID-103, so they know `days_elapsed` already has at least one live
  consumer (`AuctionTransfer.settle_expired`) waiting on it, in addition to the
  dungeon-crawl seed seam.
- Not urgent: an auction listing that never expires just sits `active` until
  manually bought out or cancelled — no data corruption, no crash, no coin leak.
