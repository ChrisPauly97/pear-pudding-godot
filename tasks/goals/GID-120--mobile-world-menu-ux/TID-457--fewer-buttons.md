# TID-457: Fewer Buttons — Overload Existing Controls

**Goal:** GID-120
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none · **Acquired:** — · **Expires:** —

## Context

User request: fewer always-on buttons; overload existing controls. Current state:
battle shows a pause button AND a "Menu" button whose only job (confirm return to
menu) is already inside the pause menu (Return to Menu / Flee / Settings). Co-op
registers Chat + Emote into ZONE_SOCIAL as permanent buttons. Mount/Dismount and
minimap-tap→map are already overloaded; ZONE_CONTEXT already shows one contextual
action at a time.

## Plan

1. Battle: hide the tscn `MenuButton` (`_menu_btn.visible = false`, wiring kept) —
   pause is the single system control, matching the world HUD pattern.
2. WorldHUD ZONE_SOCIAL: a persistent "💬" toggle button; social-zone actions
   registered while collapsed start hidden; toggling flips their visibility.

## Changes Made

- `BattleScene._apply_ui_sizes()` hides `_menu_btn`.
- `WorldHUD`: `_social_expanded` state + `_ensure_social_toggle()`;
  `register_action` hides new ZONE_SOCIAL buttons while collapsed; toggle flips
  visibility of all zone children except itself.

## Documentation Updates

- `docs/agent/ui-and-scene-management.md`: GID-120 button-consolidation note.
- `docs/agent/battle-system.md`: battle Menu button removal noted in GID-119/120
  context.
