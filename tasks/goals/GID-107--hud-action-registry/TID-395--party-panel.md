# TID-395: Party panel — consolidate always-on co-op buttons into one entry point

**Goal:** GID-107
**Type:** agent
**Status:** done
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

- `scenes/ui/PartyPanel.gd`: a new script-only overlay (`extends BaseOverlay` by path
  string, `.new()`-instantiated), matching `GhostDuelOverlay`/`PartyStashOverlay`/
  `LeaderboardOverlay` — built entirely from plain data + Callables the caller
  supplies (`roster_rows`, `on_add_friend`, `show_*`/`on_*` per action), so it stays
  decoupled from `WorldScene` internals the same way those overlays already are.
  Sections, in order: Roster (list + per-peer add-friend button), then an Actions
  grid: Loot Mode toggle, Stash, Leaderboard, Ghost Duels, Team Duel, Dungeon Crawl —
  each only shown if its `show_*` flag is true.
- **Roster decision:** moved fully inside the Party panel (not a lightweight
  always-visible strip). This directly serves GID-107's decluttering goal and
  matches the goal.md acceptance criteria, which explicitly lists "Roster" among
  the buttons to fold into the single entry point.
- `WorldScene.gd`: `_open_party_panel()` builds a `PartyPanel`, computing each
  `show_*` flag from the exact same condition its old standalone button used
  (documented inline at each assignment) — this is a placement change, not a
  behavior change. `_refresh_coop_roster()` now computes `_party_roster_rows`
  (Array[Dictionary]) instead of building Control nodes directly, and pushes to
  the panel via `refresh_roster()` if it's currently open. The "Party" button
  itself is registered once via `_world_hud.register_action("party", "Party",
  WorldHUD.ZONE_NAV, _open_party_panel)` in `_setup_coop()`.
- Removed the six standalone button-creation functions (`_ensure_dungeon_button`,
  `_ensure_team_duel_button` + `_update_team_duel_button_visibility`,
  `_ensure_ghost_duel_button`, `_ensure_loot_mode_toggle_button` +
  `_refresh_loot_mode_toggle_button`, `_build_coop_roster`, and the Stash/
  Leaderboard blocks inside `_ensure_social_buttons()`) along with their `Button`
  member vars and every dead `.hide()` guard that referenced them.

## Changes Made

- Added `scenes/ui/PartyPanel.gd` (new file, no `.uid` needed — plain `.gd` script).
- `scenes/world/WorldScene.gd`:
  - Added `const _PartyPanel = preload(...)`, `_party_panel`/`_party_roster_rows` vars.
  - `_refresh_coop_roster()` rewritten to build row data + push to the open panel
    (same fields/order as the old `_add_roster_row` calls: text, color, token,
    clean_name, is_friend).
  - Added `_loot_mode_label_text()` (replaces `_refresh_loot_mode_toggle_button`'s
    text computation) and `_open_party_panel()`.
  - Removed: `_ensure_dungeon_button`, `_ensure_team_duel_button`,
    `_update_team_duel_button_visibility` (and its `_process()` call site),
    `_ensure_ghost_duel_button`, `_ensure_loot_mode_toggle_button`,
    `_refresh_loot_mode_toggle_button`, `_build_coop_roster`, `_add_roster_row`,
    and the Stash/Leaderboard button blocks in `_ensure_social_buttons()`.
  - Removed vars: `_team_duel_btn`, `_dungeon_btn`, `_ghost_duel_btn`, `_stash_btn`,
    `_leaderboard_btn`, `_loot_mode_toggle_btn`, `_coop_roster`. Removed every
    `.hide()` guard on these across `_enter_pvp`, `_enter_pvp_wagered`,
    `_start_team_duel`, `_on_notify_team_duel_start`, and the tournament match-start
    handler.
  - `_ensure_challenge_button`/`_ranked_toggle_btn`/`_tournament_btn`/`_auction_btn`
    left untouched (out of scope — TID-396 handles Challenge/Ranked; Auction wasn't
    in the goal's original list, logged as BID-042).
- **Bug fix (found while editing):** `_on_coop_session_ended()` had a teardown block
  (`if _loot_mode_toggle_btn != null: ... queue_free()`) that referenced the just-removed
  var — would have been a compile error. Replaced with the equivalent `_party_panel`
  cleanup (also better behavior: the panel now actually closes on session end instead
  of silently holding stale data).
- Fixed 6 stale references to the removed function names in
  `docs/agent/multiplayer-coop.md` (Session roster, Roster rating badge, Team
  formation, Ghost Duels entry point, Need/greed roll mode, Dungeon Crawl trigger).
- Logged `BID-042` (Auction button not folded into Party panel — post-dates the
  goal's original button list).

**Not run:** `godot --headless --editor --quit` — same network-policy block on the
Godot download as TID-394. Manually traced every removed symbol with `grep` across
`scenes/`, `game_logic/`, `autoloads/`, `tests/` to confirm no dangling references
(including the compile-error catch above), and did a parenthesis/bracket/brace
balance check against the pre-edit file to confirm no imbalance was introduced.

## Documentation Updates

For TID-398's `docs/agent/ui-and-scene-management.md` pass — Party panel section
list and gating, in order: Roster (always shown, includes per-peer add-friend),
Loot Mode toggle (host + `SessionStore.is_open()`), Stash (always, co-op active),
Leaderboard (always, co-op active), Ghost Duels (host + `SessionStore.is_open()`),
Team Duel (host, not dedicated server, `State.WORLD`, ≥3 connected clients, no
pending challenge), Dungeon Crawl (host only). Opened via the "Party" button in
`WorldHUD.ZONE_NAV`. `docs/agent/multiplayer-coop.md` was already updated directly
in this task (see Changes Made) since it referenced the exact function names removed.
