# TID-756: Matchup loadouts: quick deck swap before a fight

**Goal:** GID-181
**Type:** agent
**Status:** pending
**Depends On:** TID-753

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Horizontal progression only pays off if switching to the right deck is quick. Players keep several decks and pick one for a matchup.

## Research Notes

- Loadouts exist: `autoloads/save_manager/SaveLoadouts.gd` (`save_manager.decks`), deck table UI from GID-180 (scenes/ui deck builder). Allow naming/tagging a loadout with a school.
- Hook point: the engage → battle gap. `SceneManager.accepts_engage()` / gambit picker (see CLAUDE.md bug learnings on pending UI steps needing a busy flag). Add a small 'Swap deck' row to the gambit/engage prompt showing the enemy's known weak schools (from TID-753) and the player's loadouts, with the best-matching one highlighted.
- Must work with gambits off (auto-skip) — then offer it on the world HUD via `register_action` (ZONE_CONTEXT) when an enemy is targeted/nearby, not a bare Button (HUD registry guardrail).
- Mobile parity: tap targets; desktop: number keys optional.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
