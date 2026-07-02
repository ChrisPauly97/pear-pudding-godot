# TID-398: Discoverability pass, docs/CLAUDE.md rule, and anti-clutter regression test

**Goal:** GID-107
**Type:** agent
**Status:** pending
**Depends On:** TID-394, TID-395, TID-396, TID-397

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

GID-107's whole point is that HUD clutter should not silently return with the next feature. TID-394–397 build the mechanism and migrate existing buttons; this task closes the loop: makes the new layout discoverable to players who are used to the old scattered buttons, documents the system so future agents use it, and adds a guardrail so a future task can't bypass the registry the way every task since GID-081 bypassed the HUD declutter.

## Research Notes

- **Tutorial popups:** `scenes/ui/TutorialPopup.gd` + `game_logic/TutorialRegistry.gd`. Adding a new popup is a single entry in `TutorialRegistry.gd`'s `_DATA` dict — no UI code changes needed (see `docs/agent/ui-and-scene-management.md`'s TutorialPopup section). Trigger it via `GameBus.tutorial_popup_requested.emit("party_panel")` (or similar id) the first time co-op becomes active post-migration, following the existing pattern used for `"skill_tree"` in `SceneManager._on_skill_tree_requested` handling.
- **Docs:** `docs/agent/ui-and-scene-management.md` already has a "Menu Hub (GID-081)" section (~line 64) as the direct style precedent — add an equivalent "HUD Action Registry & Party Panel (GID-107)" section documenting: the zone list and their screen positions, the `register_action`/`unregister_action`/`refresh_visibility` API, the Party panel's sections and gating rules (esp. Ghost Duels' host-only gate), the contextual action bar's priority order, and the social strip layout. Pull the final specifics from TID-394–397's "Changes Made" and "Documentation Updates" sections once those land.
- **CLAUDE.md:** the project root `CLAUDE.md` is regularly amended by agents with durable rules and a "Bug Fix Learnings" section (see existing entries like "Mobile / Desktop Feature Parity" and the various GDScript pitfalls) — this is the right place for a new short rule, e.g. under a new "HUD Buttons: Always Use the Action Registry" heading: never call `Button.new()` directly on WorldScene's `_hud` CanvasLayer; always go through `WorldHUD.register_action(...)`. Keep it as terse as the other CLAUDE.md rules (problem / fix / one code example).
- **Regression test:** `tests/runner.gd` is the GUT-based headless test entry point (`godot --headless --path . -s tests/runner.gd`, see CLAUDE.md's "Running Tests" section). Look at the existing `tests/` directory for the project's test-writing conventions before adding a new one. The check should assert that `scenes/world/WorldScene.gd` (and `WorldHUD.gd` outside its own registry implementation) contains no direct `Button.new()` calls that bypass `register_action` — a static source-text scan test (grep-style, similar in spirit to `test_card_registry`'s count assertions) is simpler and more reliable in GDScript/GUT than trying to introspect the live scene tree, but choose whichever approach fits the existing test suite's patterns once you've looked at it.
- **Manual verification:** per the GID-107 acceptance criteria, manually check for overlaps across: single-player, co-op idle, co-op with a nearby player in challenge range, co-op during an active PvP duel (as spectator), co-op during dungeon crawl, and Android touch layout (via the existing mobile-parity checklist in CLAUDE.md).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_This task performs the consolidated `docs/agent/ui-and-scene-management.md` update and the `CLAUDE.md` rule addition for the whole goal — fill in specifics here once written._
