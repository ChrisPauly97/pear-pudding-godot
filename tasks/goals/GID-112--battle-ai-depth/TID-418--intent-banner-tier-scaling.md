# TID-418: Scale Enemy Intent Banner Specificity by Difficulty Tier

**Goal:** GID-112
**Type:** agent
**Status:** pending
**Depends On:** TID-417

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The Enemy Intent banner (`BasicAI.describe_turn`, shown via
`BattleScene._run_ai_turn()`) currently states the AI's exact next card and
target every turn for every enemy — e.g. `"Enemy attacks Skeleton with Ghoul"`.
This was deliberately added (TID-059) for teaching value, and per this goal's
approval the user wants that exact wording **kept for tutorial-tier
(`difficulty_tier == 1`) enemies**. For tier ≥ 2, the banner should stop
revealing the exact plan so higher-tier fights regain some tension now that
personas (TID-416/417) make the AI's choices meaningful again.

## Research Notes

- Call site: `BattleScene._run_ai_turn()`, `scenes/battle/BattleScene.gd:1869-1875`:
  ```gdscript
  var actions := BasicAI.decide_turn(_state)
  _fx.show_intent_banner(BasicAI.describe_turn(_state))
  ```
  `_fx` is the battle FX helper (`BattleFx` or similar — confirm exact type via
  `grep "var _fx" scenes/battle/BattleScene.gd`) whose `show_intent_banner(text)`
  just renders whatever string it's given; no change needed there, only to what
  string is produced.
- `BasicAI.describe_turn` (post TID-415/416) will accept a persona (and, per
  TID-415's plumbing, should also receive `difficulty_tier` — thread it the same
  way as `ai_persona`, read from `enemy_data` in `BattleScene`).
- Tier-1 wording: unchanged from today — exact card name + exact target name
  (`"Enemy will play Ghost"` / `"Enemy attacks Skeleton with Ghoul"` / `"Enemy
  will attack your hero with Ghoul"`).
- Tier ≥ 2 wording: persona-flavored, no exact target/card name. Suggested
  copy (finalize during Plan, keep short — banner is a small centered panel):
  - `"aggro"`: `"The enemy is pressing the attack..."`
  - `"control"`: `"The enemy is calculating its next move..."`
  - Fallback/no-action-available: keep today's `"Enemy is thinking..."` for all
    tiers (already vague, no change needed).
- This only touches the *banner string*, never the actual `decide_turn` action
  list — the AI's real behavior must stay exactly what `describe_turn` (in
  either wording mode) describes, so the banner is never literally lying, just
  less specific for higher tiers.
- No interaction with PvP or Puzzle Mode — both skip `_run_ai_turn` entirely
  (confirmed in TID-415's research notes).
- Verify this doesn't regress `tests/unit/test_basic_ai.gd` string-matching
  tests, if any exist for `describe_turn` output — check before changing wording
  and update any such assertions to account for the new tier parameter.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
