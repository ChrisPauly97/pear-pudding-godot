# BID-042: Auction House button wasn't folded into the Party panel

**Category:** design-gap
**Discovered during:** GID-107 / TID-395

## Summary

GID-107's goal.md enumerated the always-on co-op HUD buttons to consolidate into
the new Party panel (Roster, Stash, Leaderboard, Ghost Duels, Team Duel, Dungeon
Crawl, Loot-mode toggle) — that list was written before GID-102/TID-378 shipped
the "Auction" button (`_auction_btn` in `_ensure_social_buttons()`,
`scenes/world/WorldScene.gd`). It is exactly the same shape of always-visible,
non-proximity-gated co-op button as Stash/Leaderboard, so it should logically
live in the Party panel too, but TID-395 stuck to the goal's explicit list to
avoid unreviewed scope creep.

## Suggested fix

Add an "Auction" action to `PartyPanel` (`scenes/ui/PartyPanel.gd`) the same way
Stash/Leaderboard were added, and remove the standalone `_auction_btn` creation
in `_ensure_social_buttons()`. Low risk, mechanical — same pattern as the
existing Party-panel sections.
