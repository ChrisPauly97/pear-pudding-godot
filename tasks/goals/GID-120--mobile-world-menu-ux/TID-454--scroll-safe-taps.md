# TID-454: Scroll-Safe Taps in Card Grids

**Goal:** GID-120
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none · **Acquired:** — · **Expires:** —

## Context

Buttons capture the pointer once pressed, so `attach_drag_scroll` (which listens on
the ScrollContainer) never sees drags that start on a card tile: the list doesn't
scroll, and if the finger stays within the tile the Button fires on release. In
InventoryScene a bare tap adds/removes a deck card (`_make_card_tile`); in ShopScene
it buys. Also, gap-started drags reuse a stale `drag_start` when the press was
consumed by a child, causing scroll jumps.

## Plan

1. `UiUtil.bind_scroll_safe_press(btn, callback, scroll, slop)`: `button_down`
   records the press position; motion while pressed beyond `slop` marks the gesture
   as a drag AND drives `scroll.scroll_vertical` (the button owns the pointer, so it
   must forward the pan); `pressed` runs `callback` only for clean taps.
2. `attach_drag_scroll`: re-init the gesture on first motion after >150 ms idle so
   presses consumed by children can't leave a stale origin.
3. Apply the helper to Inventory collection/deck tiles and Shop Buy buttons.

## Changes Made

- `UiUtil.bind_scroll_safe_press()` added (static, no autoload access).
- `BaseOverlay.attach_drag_scroll` gesture re-init via `Time.get_ticks_msec()`.
- `InventoryScene._make_card_tile` uses the helper (tap = deck toggle) wired to the
  owning scroll container; ShopScene Buy buttons (cards + equipment) likewise.

## Documentation Updates

- `docs/agent/ui-and-scene-management.md`: helper documented under GID-120.
