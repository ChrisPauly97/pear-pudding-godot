# TID-473: Auction Button Into PartyPanel

Goal: [GID-125](goal.md) · Backlog: BID-042 · Type: agent · Status: done

## Problem

The Auction House button shipped (GID-102 / TID-378) after GID-107's HUD
consolidation was scoped, so it stayed a standalone always-visible
`Button.new()` + `_hud.add_child()` — the exact pattern CLAUDE.md forbids, and
the same always-on co-op clutter Stash and Leaderboard were moved out of.

## Changes Made

- `scenes/ui/PartyPanel.gd` — added `show_auction` / `on_auction` and an
  `_add_action_button(grid, "Auction", on_auction, true)` call positioned right
  after Leaderboard, matching Stash/Leaderboard exactly.
- `scenes/world/WorldScene.gd` — wired `panel.show_auction` / `panel.on_auction`
  in `_open_party_panel()`; deleted the `_auction_btn` declaration and its whole
  `Button.new()` + `_hud.add_child()` block from `_ensure_social_buttons()`.
- `tests/unit/test_hud_registry_guardrail.gd` — dropped `_auction_btn` from
  `_ALLOWED_DIRECT_HUD_CHILDREN`; the guardrail now passes by construction
  because the offending call site no longer exists. Followed the existing
  `_siege_btn` / `_tournament_btn` precedent, including the explanatory note.

Verified no `_auction_btn` references remain outside that one comment.

## Documentation Updates

`docs/agent/ui-and-scene-management.md` (party-panel table, UiFx paragraph) and
`docs/agent/multiplayer-coop.md` (auction house section).
