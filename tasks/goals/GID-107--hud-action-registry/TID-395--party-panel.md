# TID-395: Party panel — consolidate always-on co-op buttons into one entry point

**Goal:** GID-107
**Type:** agent
**Status:** pending
**Depends On:** TID-394

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

When co-op is active, `WorldScene.gd` currently shows up to 7+ always-visible (or near-always-visible) buttons scattered across the HUD, several of which physically overlap other elements (see GID-107 goal.md Context): Stash, Leaderboard, Ghost Duels, Team Duel, Dungeon Crawl, Loot-mode toggle, plus the in-world session roster panel. None of these are proximity-gated — they're either always shown while co-op is active or shown once a session file is open — so they are the best candidates to collapse into a single discoverable "Party" entry point rather than a contextual bar (that's TID-396's job, for proximity-gated actions).

## Research Notes

Exact current locations in `scenes/world/WorldScene.gd` (line numbers approximate as of GID-102/106 merge, re-check before editing):
- `_stash_btn` / `_toggle_stash_overlay` — `_ensure_social_buttons()` ~4634, opens `scenes/ui/PartyStashOverlay.gd`. Always visible while co-op active (not proximity-gated) per its own inline comment.
- `_leaderboard_btn` / `_toggle_leaderboard_overlay` — `_ensure_social_buttons()` ~4623, opens `scenes/ui/LeaderboardOverlay.gd`. Always visible while co-op active (global, not proximity-gated) per its own inline comment.
- `_ghost_duel_btn` / `_toggle_ghost_duel_overlay` — `_ensure_ghost_duel_button()` ~4650. **Host-only**: gated on `SessionStore.is_open()` (a client never opens SessionStore locally). Opens `scenes/ui/GhostDuelOverlay.gd`. Preserve this exact gating — do not show to clients.
- `_team_duel_btn` — `_ensure_team_duel_button()` ~1845, text "Team Duel (2v2)".
- `_dungeon_btn` — `_ensure_dungeon_button()` ~1719, text "Dungeon Crawl", calls `_start_dungeon_crawl()`.
- `_loot_mode_toggle_btn` — `_ensure_loot_mode_toggle_button()` ~1019, toggles "Loot: Need/Greed" vs "Loot: First-Opener" text, calls `_on_loot_mode_toggle_pressed()`.
- `_coop_roster` — `_refresh_coop_roster()` ~980, a `VBoxContainer` panel (not a button) listing party members, currently always shown at `panel.position = Vector2(vp.x*0.012, vp.y*0.30)` while co-op is active. Decide during Plan whether this moves fully inside the Party panel or stays as a lightweight always-visible strip — either is acceptable, but document the choice.

Overlap only happens when co-op is active — in single-player none of these buttons exist, so there is no correctness risk to single-player, only a UI change.

## Plan

_Written during Plan phase._ Suggested shape (confirm/adjust during Plan):
- Use `WorldHUD.register_action("party", "Party", <zone>, _open_party_panel, visible_when=<co-op active>)` (from TID-394) to add one button.
- Build a `PartyPanel` overlay following the `BaseOverlay` + `UiUtil` pattern (GID-073) used by `MenuHubScene` — sections or sub-tabs for Roster, Stash, Leaderboard, Ghost Duels, Team Duel, Dungeon Crawl, Loot Rules. Each section keeps its existing gating logic verbatim (especially Ghost Duels' host-only `SessionStore.is_open()` check).
- Remove the individually-positioned buttons/panel from the HUD; their existing handler functions (`_toggle_stash_overlay`, `_toggle_leaderboard_overlay`, etc.) can be called from the new panel's section buttons largely unchanged.
- Preserve all existing signals/behavior — this is a placement/discoverability change, not a feature change.

## Changes Made

_Filled after Build phase._

## Documentation Updates

_Leave the full `docs/agent/ui-and-scene-management.md` rewrite to TID-398. Note the Party panel's section list and gating rules in this section for TID-398's reference._
