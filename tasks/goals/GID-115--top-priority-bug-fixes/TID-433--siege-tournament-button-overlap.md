# TID-433: Migrate Siege/Draft/Tournament Buttons to the HUD Registry, Fixing the Siege–Tournament Overlap

**Goal:** GID-115
**Type:** agent
**Status:** done
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

1. **Draft Duel** (proximity-gated, same shape as Challenge/Ranked) →
   `WorldHUD.ZONE_CONTEXT` via `_world_hud.register_action("draft_duel", ...)`,
   keeping its own `_update_draft_duel_proximity()` per-frame visibility logic
   unchanged (it sets `.visible`/`.hide()` directly on the returned `Button`,
   exactly like `_challenge_btn` already does).
2. **Siege** and **Tournament** (host-only, session-scoped, not proximity-gated)
   → `PartyPanel.gd`: add `show_siege`/`on_siege` and
   `show_tournament`/`on_tournament` pairs, rendered as grid action buttons
   (`_add_action_button(..., close_after=true)`), wired fresh on every open in
   `WorldScene._open_party_panel()` — mirrors the existing Team Duel/Dungeon
   Crawl/Spire/Guildhall pattern exactly.
3. Delete the standalone `_siege_btn`/`_tournament_btn` Button vars and their
   `_ensure_*_button()`/`_update_tournament_button_visibility()` functions
   entirely (not just hide them) — matches how the already-migrated
   Stash/Leaderboard/Team Duel/etc. buttons were fully removed in GID-107,
   confirmed by grepping for any leftover `_stash_btn`-style var (none found).
4. Remove every `_siege_btn`/`_tournament_btn` show/hide call site scattered
   across the siege-wave and tournament-match lifecycle functions (found by
   grep before editing, so none were missed): `_on_siege_started_received`,
   `_start_coop_pve_from_siege`-equivalent host/client engage handlers,
   `_on_coop_siege_battle_ended`, `_start_tournament`,
   `_start_current_tournament_match`. Their own internal guards
   (`NetworkManager.is_host()`, `_coop_siege_active`, `_tournament_active`,
   etc.) already make these buttons' visibility a pure function of state, so
   deleting the imperative show/hide calls changes nothing observable — the
   Party panel now recomputes the same `show_*` gate fresh every time it opens.
5. Remove the now-unmigrated `_process` call to
   `_update_tournament_button_visibility()` (draft duel's own
   `_update_draft_duel_proximity()` call stays, since that button still needs
   continuous per-frame proximity gating).
6. Update `tests/unit/test_hud_registry_guardrail.gd`'s
   `_ALLOWED_DIRECT_HUD_CHILDREN`: remove `_siege_btn`, `_draft_duel_btn`, and
   `_tournament_btn` — none are direct `_hud` children anymore.
7. Update `docs/agent/ui-and-scene-management.md`'s "HUD Action Registry &
   Party Panel" section: `ZONE_CONTEXT` contents table (add Draft Duel), the
   Party panel table (add Siege/Tournament rows, plus the previously-missing
   Co-op Spire/Guildhall rows), the `UiFx.attach()` allow-list callout, and the
   guardrail description — all previously referenced the unmigrated trio.
8. Archive `BID-043` and update `tasks/index.md`.

No new tests needed beyond the guardrail's existing coverage — this is a pure
placement refactor (`show_*` conditions copied verbatim from the deleted
buttons' visibility functions), not new logic; the guardrail test itself is
the regression check that the migration actually happened and stays put.

## Changes Made

- `scenes/world/WorldScene.gd`:
  - `_ensure_draft_duel_button()` now creates its button via
    `_world_hud.register_action("draft_duel", "Draft Duel", WorldHUD.ZONE_CONTEXT,
    _request_draft_duel, Callable(), Vector2(vp.y*0.20, vp.y*0.05))` instead of a
    bare `Button.new()` + `_hud.add_child()`; tooltip set after.
  - Deleted `_ensure_siege_button()`, `_ensure_tournament_button()`, and
    `_update_tournament_button_visibility()` in full, along with the
    `var _siege_btn: Button = null` / `var _tournament_btn: Button = null`
    declarations, the `_ensure_siege_button()`/`_ensure_tournament_button()`
    call sites in the coop-setup block, the `_update_tournament_button_visibility()`
    call in `_process`, and every remaining show/hide reference to either var
    (`_on_siege_started_received`, the host/client siege-boss-engage handlers,
    `_on_coop_siege_battle_ended`, `_start_tournament`,
    `_start_current_tournament_match`).
  - `_open_party_panel()`: added `panel.show_siege`/`on_siege` (mirrors the old
    `_ensure_siege_button()` gate: `_CoopSiege.supports_map(map_name) and
    NetworkManager.is_host() and not _coop_siege_active`) and
    `panel.show_tournament`/`on_tournament` (mirrors the old
    `_update_tournament_button_visibility()` gate verbatim).
- `scenes/ui/PartyPanel.gd`: added `show_siege`/`on_siege` and
  `show_tournament`/`on_tournament` exports plus their `_add_action_button`
  grid entries (both `close_after = true`, consistent with the other one-shot
  trigger actions); updated the file's header comment listing consolidated
  actions.
- `tests/unit/test_hud_registry_guardrail.gd`: removed `_siege_btn`,
  `_draft_duel_btn`, and `_tournament_btn` from `_ALLOWED_DIRECT_HUD_CHILDREN`
  (with a comment explaining why), so the guardrail now permanently enforces
  this migration.
- Archived `tasks/backlog/BID-043--siege-draft-tournament-buttons-not-migrated.md`
  to `tasks/archive/backlog/` and updated `tasks/index.md`.

**Verification note:** same sandbox constraint as the rest of this goal — no
Godot binary and the release-zip download is blocked by the proxy (403), so
`godot --headless --editor --quit` and `tests/runner.gd` (including the
guardrail test itself) could not be run here. Every deletion site was found by
grepping for the exact variable/function names before and after editing to
confirm nothing was missed and nothing else referenced them; the guardrail
test's own regex logic was traced by hand against the final source to confirm
it will pass (no `_hud.add_child(_siege_btn|_tournament_btn|_draft_duel_btn)`
call sites remain). Recommend a real headless run in CI before merge —
this is the change in the goal most worth actually seeing rendered, since
zone-stacking/panel-grid layout is the whole point of the fix.

## Documentation Updates

- `docs/agent/ui-and-scene-management.md` — "HUD Action Registry & Party
  Panel": updated the opening problem-statement note (Siege/Tournament overlap
  now resolved), the `ZONE_CONTEXT` contents row (added Draft Duel), the
  `UiFx.attach()` hand-built-buttons list (removed the three), the Party panel
  table (added Siege/Tournament rows, backfilled the previously-undocumented
  Co-op Spire/Guildhall rows), the Auction House out-of-scope note (now only
  mentions Auction, since Siege/Draft/Tournament are migrated), and the
  guardrail test description (allow-list no longer includes the trio).
