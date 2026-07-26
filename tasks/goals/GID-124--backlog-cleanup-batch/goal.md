# GID-124: Backlog Cleanup Batch — Music, AI Signals, Rally & Auction

## Objective

Close four independent open backlog items that each had a confirmed, bounded
fix, rather than leaving them to accrete further.

## Context

Opened during the continuous-improvement pass on
`claude/continuous-improvement-abvtao`, immediately after GID-123 established a
trustworthy green baseline (2209/0). Each item was already researched and filed;
none needed new design work.

Work was executed by two parallel sub-sessions on disjoint file sets, then
validated centrally with a single headless import + suite run.

## Tasks

| Task | Title | Backlog | Status |
|------|-------|---------|--------|
| [TID-467](TID-467--data-driven-named-map-music.md) | Data-driven named-map music | BID-048 | done |
| [TID-468](TID-468--ai-gamebus-emissions.md) | AI opponent GameBus emissions | BID-006 | done |
| [TID-469](TID-469--rally-inside-dungeon.md) | Rally from inside a shared dungeon | BID-040 | done |
| [TID-470](TID-470--auction-into-party-panel.md) | Auction button into PartyPanel | BID-042 | done |

## Acceptance Criteria

- [x] Peaceful named maps no longer play dungeon music; real dungeons still do.
- [x] The single-player AI opponent emits the same battle signals the player does.
- [x] Rally works from inside a shared dungeon; waystone travel stays blocked.
- [x] Auction is a PartyPanel action with no duplicate HUD button.
- [x] Headless import clean; suite 2209 passed / 0 failed.
