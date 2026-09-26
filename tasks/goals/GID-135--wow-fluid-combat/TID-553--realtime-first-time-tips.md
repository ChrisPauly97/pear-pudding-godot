# TID-553: Real-Time First-Time Tips with Spotlight

**Goal:** GID-135
**Type:** agent
**Status:** done
**Depends On:** TID-552

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User approved (2026-09-26): contextual one-shot tips the first time each combat moment happens, pausing the
clock and pointing at the thing to press.

## Research Notes

- `GameBus.tutorial_popup_requested(id)` → `SceneManager._on_tutorial_popup_requested` shows a
  `TutorialPopup` once (story flag `seen_tutorial_<id>`); the popup joins the modal group, which pauses the
  real-time clock. Texts live in `game_logic/TutorialRegistry.gd`.

## Plan

`BattleOnboarding.tip(id, target)`: once per fight and once ever, emit the popup and spotlight `target` (pulsing
gold ring, 3.5 s after the popup closes). Triggers: fight start (intro / new skill / cards), HP ≤ 40 % (Mend),
first enemy cast (Kick), mana below the cheapest skill, first Ally on your board, an add joining.

## Changes Made

- `BattleOnboarding`: `tip`, `update` triggers, `on_add`, spotlight.
- `BattleSkillBar`: `button_for(id)`, `cheapest_cost()`.
- `TutorialRegistry`: nine `rt_*` entries.
- `test_scene_module_guardrail`: allow-list `_BattleOnboarding.new(_battle, self)`.

## Documentation Updates

`docs/agent/combat-model.md` — "New-player onboarding" section.
