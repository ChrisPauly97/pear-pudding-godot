# TID-452: Battle Tutorial Updates for Tap-First Flow

**Goal:** GID-119
**Type:** agent
**Status:** done
**Depends On:** TID-450

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The first-battle overlay (`BattleScene._show_battle_tutorial`) says "Drag a card from
your hand to the board to play it." — after TID-450, tap is the primary mobile flow
and the copy should teach it (drag still works). `TutorialRegistry` popups
(`GameBus.tutorial_popup_requested`) are one-shot global guides; battle entry fires
`tap_and_hold`.

## Research Notes

- `TutorialRegistry._DATA` is a static dict; `SceneManager._on_tutorial_popup_requested`
  gates each id on a "seen once" story flag, so adding an id + one emit is the whole
  integration.
- The overlay and the popup must not stack confusingly: the overlay already only shows
  when `tutorial_battle_tip` is unset (very first battle); the popup queue handles the
  rest.

## Plan

1. Reword `_show_battle_tutorial` copy: tap-first (tap card → tap green slot; tap
   minion → tap target), mention hold-to-inspect.
2. Add `tap_to_cast` entry to `TutorialRegistry._DATA` (tap a spell to aim or cast it,
   ✕ Cancel to back out) and emit it on battle entry alongside `tap_and_hold`.

## Changes Made

- `BattleScene._show_battle_tutorial`: copy reworded to teach the tap flow.
- `TutorialRegistry`: new `tap_to_cast` entry; `BattleScene._ready` emits it after
  `tap_and_hold`.

## Documentation Updates

- `docs/agent/battle-system.md`: GID-119 section notes the tutorial copy.
