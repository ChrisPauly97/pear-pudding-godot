# GID-120: Mobile World & Menu UX

## Objective

Fix the structural Android/mobile gaps outside battle: the back gesture must never
hard-quit the game, scrolling a card grid must never fire phantom taps, HUD controls
must respect display cutouts, the `text_scale` setting must work outside battle, and
the always-on button population shrinks (overload existing controls instead).

## Context

Research findings (2026-07-17, branch `claude/mobile-card-battle-ux-99rrw9`, follows
GID-119's in-battle pass):

- `application/config/quit_on_go_back` is unset (Godot default `true`) and nothing
  handles `NOTIFICATION_WM_GO_BACK_REQUEST` — the Android back gesture instantly
  quits the app from anywhere. Escape (keycode 4194305) is bound to both `pause`
  and `ui_cancel`, so WorldScene pause, BattleScene pause, BaseOverlay `_close()`,
  and MenuHub close are all reachable by synthesizing one Escape press.
- `BaseOverlay.attach_drag_scroll` scrolls on drag but child Buttons capture the
  pointer once a press lands on them: drags starting on a card tile don't scroll at
  all, and small drags fire the button on release — in InventoryScene a plain tap
  edits the working deck, in ShopScene it buys (`buy_btn.pressed.connect(_on_buy_*`).
- No `DisplayServer.get_display_safe_area()` usage anywhere — HUD zones
  (`WorldHUD._init_zones`), VirtualJoystick, Minimap, and the battle SidePanel anchor
  to raw screen edges, i.e. under punch-hole cameras / rounded corners in landscape.
- `text_scale` is consumed only by the battle UI (GID-119); `UiUtil` label helpers,
  WorldHUD text, and AchievementToast ignore it.
- Button population: battle has both a pause button and a redundant "Menu" button
  (pause menu already contains Return to Menu / Flee / Settings); co-op adds a
  Chat + Emote pair to ZONE_SOCIAL that can collapse behind one toggle.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-453 | Android Back Gesture Routing | agent | done | — |
| TID-454 | Scroll-Safe Taps in Card Grids | agent | done | — |
| TID-455 | Display Safe-Area Insets | agent | done | — |
| TID-456 | text_scale Outside Battle + Tiny-Font Sweep | agent | done | — |
| TID-457 | Fewer Buttons — Overload Existing Controls | agent | done | — |

## Acceptance Criteria

- [ ] Android back closes the top overlay / opens pause instead of quitting; at the
      main menu it quits only on a second press within 2 s ("press again to exit")
- [ ] Finishing a scroll gesture over a deck tile or shop Buy button fires nothing;
      a drag that starts on a tile still scrolls the list
- [ ] HUD zones, joystick, minimap, and battle side panel are inset by the display
      safe area (no-op on devices without cutouts)
- [ ] Title/body labels via UiUtil, WorldHUD text, and AchievementToast honor
      `text_scale`; no sub-2%-vh body fonts remain in those surfaces
- [ ] Battle shows one system button (pause), not pause + Menu; co-op social
      buttons sit behind a single toggle

## Verification Note

Same sandbox constraint as GID-119: no Godot binary obtainable (network policy), so
headless import and the GUT suite could not run locally. CI must be watched on push.
