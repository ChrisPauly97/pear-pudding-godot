# TID-433: Migrate Siege/Draft/Tournament Buttons to the HUD Registry, Fixing the Siege–Tournament Overlap

**Goal:** GID-115
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Promotes **BID-043**. Three HUD buttons shipped after GID-107's consolidation list was
written and were left as hand-positioned `Button.new()` call sites in
`scenes/world/WorldScene.gd`. Concrete visible bug: the Siege button
(`(vp.x - vp.y*0.22)*0.5, vp.y*0.63`) and the Tournament button
(`(vp.x - vp.y*0.28)*0.5, vp.y*0.63`) are both centered horizontally at the same
`y = vp.y*0.63`, with Tournament's wider box extending past Siege's edges — they
visually overlap in the (host, siege-supported map, no active siege, no active
tournament) state, which is reachable. This is exactly the class of silent pixel
collision the GID-107 registry exists to prevent (see CLAUDE.md "HUD Buttons: Always
Use the Action Registry").

## Research Notes

- **The three unmigrated buttons (all in `scenes/world/WorldScene.gd`):**
  - `_ensure_siege_button()` (line 2780) — host-only, shown on siege-supported maps
    when no siege is active (GID-103). Ensured at line 829.
  - `_ensure_draft_duel_button()` (line 8381) — proximity-gated (GID-104). Ensured at
    line 825.
  - `_ensure_tournament_button()` (grep near line 828) — host-only (GID-104).
- **Target placement (per BID-043 and `docs/agent/ui-and-scene-management.md` "HUD
  Action Registry & Party Panel"):**
  - Draft Duel (proximity-gated) → `WorldHUD.ZONE_CONTEXT` via
    `_world_hud.register_action("draft_duel", "Draft Duel", WorldHUD.ZONE_CONTEXT,
    _on_draft_duel_pressed)`, alongside Challenge/Trade/Spectate/Interact.
  - Siege and Tournament (host-only, session-scoped) → the Party panel
    (`scenes/ui/PartyPanel.gd`): add `show_*`/`on_*` pairs wired in
    `WorldScene._open_party_panel()`, per CLAUDE.md's guidance that always-on /
    session-scoped buttons belong there rather than in a new zone action.
- **Pattern references:** the GID-107 migrations (TID-395/396/397 in
  `tasks/goals/GID-107--hud-action-registry/`) migrated Leaderboard, Stash, Challenge,
  Ranked toggle, etc. For a toggle-style button parented into a zone container
  directly, see `_ensure_challenge_button()`'s Ranked toggle
  (`_world_hud.get_zone_container(WorldHUD.ZONE_CONTEXT)`).
- **Guardrail test:** `tests/unit/test_hud_registry_guardrail.gd` —
  `_ALLOWED_DIRECT_HUD_CHILDREN` allow-list documents these three buttons as known
  exceptions. Remove each from the list as it's migrated; the test then enforces the
  migration permanently.
- Preserve each button's visibility logic (host-only gates, siege-supported-map check,
  proximity gating, active-siege/tournament hiding) — the migration changes *where*
  the button lives, not *when* it shows. Grep for each `_siege_btn` / `_draft_duel_btn`
  / `_tournament_btn` usage to find every show/hide site before moving them.
- UI sizing: registry/panel handles sizing, but any residual custom sizing must stay
  viewport-relative per CLAUDE.md ("UI Sizing: Relative to Viewport").
- After the fix, move
  `tasks/backlog/BID-043--siege-draft-tournament-buttons-not-migrated.md` to
  `tasks/archive/backlog/`, update `tasks/index.md`, and update
  `docs/agent/ui-and-scene-management.md`'s registry section (it lists the unmigrated
  trio).
- Related: BID-042 (Auction House button, same shape of clutter) is deliberately NOT
  in scope here — it has no overlap bug. Leave it in the backlog.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
