# TID-441: Surface Signature Hooks in First Session (Soulbind/Cantrip Teasers)

**Goal:** GID-117
**Type:** agent
**Status:** pending
**Depends On:** TID-440

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Implements the top-ranked fixes from TID-440's audit so a new player encounters at least one
"only this game does that" moment in their first session. The exact scope is set by the
audit's recommendation list — this file pre-scopes the two most likely candidates so work
can start immediately once TID-440 confirms them.

## Research Notes

**Likely candidate A — Soulbinding teaser on first victory:**
After the first battle victory, if no soulbind occurred, add a one-time teaser line/panel to
`scenes/battle/BattleResultUI.gd` (e.g., "Some foes can be soulbound into cards — check the
Bestiary") gated by a SaveManager one-shot flag. Follow the existing one-shot-popup pattern
in `game_logic/TutorialRegistry.gd` (GID-031) rather than inventing a new mechanism — add a
registry entry if that fits better than a result-screen line. Persist the seen-flag via
`SaveManager` with field migration (see `docs/agent/save-system.md`).

**Likely candidate B — Cantrip discovery moment:**
When the deck first qualifies for a cantrip (or on first world entry), surface a popup guide
pointing at the cantrip HUD button. Cantrip availability:
`available_cantrips(template_ids)` (see `docs/agent/card-cantrips.md`); HUD buttons are
registered through the GID-107 action registry (`WorldHUD.register_action`, ZONE_CONTEXT) —
never bare `Button.new()` + `add_child` (guardrail test enforces this in WorldScene).

**Hard constraints (CLAUDE.md):**
- Mobile/desktop parity — any new prompt must be touch-operable; viewport-relative sizing
  (`vh`-based) with re-apply on `NOTIFICATION_RESIZED`.
- Preload, never load; `class_name` via `const X = preload(...)`.
- Run headless import after every `.gd` edit; run `godot --headless --path . -s
  tests/runner.gd` before commit.
- New SaveManager fields need migration defaults so old saves load.
- Don't regress scripted tutorial battles (GID-108) — teasers must not fire mid-scripted
  sequence if the audit shows those flows share the victory UI.

**Out of scope:** rebalancing when soulbind conditions/cantrips actually unlock; new art;
changes to human-owned docs.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
