# TID-186: Pack Opening Ceremony UI

**Goal:** GID-050
**Type:** agent
**Status:** done
**Depends On:** TID-185

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The reveal ceremony: 3 face-down card backs, tap-to-flip animations with rarity-based flourish, card instance creation, and a smooth exit flow.

## Research Notes

- **Scene setup:** New **`scenes/ui/PackOpenScene.tscn`** and **`scenes/ui/PackOpenScene.gd`**. Extends `Control` (overlay), receives rolled card data in `_ready()` or via a property setter. SceneManager instantiation pattern (cite `_on_shop_requested()`, **`autoloads/SceneManager.gd`** lines 342–347): `_pack_open_overlay = _pack_open_scene_packed.instantiate()`, `get_tree().current_scene.add_child(_pack_open_overlay)`, `_pack_open_overlay.closed.connect(_on_pack_closed)`. Emit `closed` signal on Done/Skip.

- **Layout:** Full-screen dark backdrop (alpha 0.7–0.8, similar to ShopScene line 30), centered HBoxContainer with 3 card back visuals and spacing. **Viewport-relative sizing per CLAUDE.md:** card back size `vh * 0.25` (width/height), font sizes `vh * 0.03` for labels, button sizes `vh * 0.065` tall. Buttons: "Reveal All" and "Done" at bottom-center in a HBoxContainer.

- **Card back visual:** A `PanelContainer` or `ColorRect` with border (use a `StyleBox` with a border color that changes per rarity on flip). Before flip: grey/neutral (`Color(0.4, 0.4, 0.4)`). On flip, recolor border to match rarity (cite **`scenes/ui/InventoryScene.gd`** line 300–306, `_rarity_color(rarity)`: common=`Color(0.80, 0.80, 0.80)`, rare=`Color(0.20, 0.50, 1.00)`, epic=`Color(0.70, 0.20, 1.00)`, legendary=`Color(1.00, 0.75, 0.00)`). Reuse the same color function (move to a shared util or copy).

- **Tap-to-flip animation:** Tween scale-x from 1.0 → 0.0 → 1.0 (flip effect). On x=0, swap the visual (back → card face). Cite **`scenes/ui/AchievementToast.gd`** line 101–104 for Tween usage pattern: `_tween = create_tween()`, `tween_property(node, "scale:x", 0.0, 0.2)` (fast flip), duration ~0.2s. Rarity flair: legendary gets a 0.5s screen shake via a child `ColorRect` with tween of scale from 1.02 → 1.0 (subtle zoom pulse) or emit a GameBus signal for particle effects (defer to TID-186 scope, keep it simple for v1: just color + zoom).

- **Card face display:** After flip, show the card. Use existing card widget if one exists (check if `scenes/battle/CardWidget.gd` or similar exists, cite it). Fallback: render card name, cost, attack/health as text labels in a `VBoxContainer`. Colors and layout: name label (vh*0.025 font), cost badge (small colored circle, vh*0.015 diameter), ATK/HP row (two labels). **Exact card instance visuals don't need to match battle UI perfectly** — just readable and tied to rarity. Option: preload any `.tres` card resource or use CardWidget from battle (cite if exists, else keep it text-only for v1).

- **Flip sequencing:** One card at a time on tap. Maintain a queue of pending flips (indices 0, 1, 2). On tap a card back, if not already flipped, add to pending-flip queue and animate immediately. Allow rapid taps; queue them. After all 3 flipped, "Reveal All" button becomes "Done". "Reveal All" button skips remaining flips and shows all cards instantly (set all scale:x to 1.0, show all faces).

- **Card instance creation:** On each flip completion, call **`SaveManager.add_card_instance(template_id, rarity, attack, health, cost)`** (line 513–530 of SaveManager.gd). This returns a UID. Store returned UIDs; on Done, log or emit an achievement signal if all are legendary.

- **Android safety:** No `load()` calls. All `.tres` and `.tscn` files preloaded or created in code. If using a CardWidget, ensure it's preloaded. Generate `.uid` sidecars for `PackOpenScene.tscn` (12-char hex string, format `uid://a1b2c3d4e5f6`).

- **Headless testability:** Extract card-flip reveal logic into a stateless function if possible, or at least make the card instance creation callable without animation context for unit tests.

## Plan

1. Create `scenes/ui/PackOpenScene.gd` built entirely in code (no .tscn needed — built programmatically to avoid .uid issues).
2. Scene structure: dark backdrop + title + 3 card slots (back/face layered) + Reveal All / Done buttons.
3. Card slot: tap button triggers scale-x tween 1→0→(swap face)→1.
4. On flip complete: call `SaveManager.add_card_instance()` to persist the card.
5. "Reveal All" instantly flips all remaining cards.
6. After all revealed, show Done button; on press, emit `closed` signal.

## Changes Made

- **`scenes/ui/PackOpenScene.gd`** (new): Full-screen overlay built in code. `_rolled_cards: Array[Dictionary]` set before `add_child()`. Displays 3 card slots with grey back ColorRect (150×220 vh-relative). Tap any unflipped card to animate: `scale:x` 1→0 (0.15s) → populate face content → `scale:x` 0→1 (0.15s). Face shows rarity-tinted background, card name, cost, ATK/HP. On flip complete: calls `SceneManager.save_manager.add_card_instance()` to create the owned card instance, and resets pity if legendary. "Reveal All" button instantly reveals remaining cards. "Done" button emits `closed` signal once all cards are revealed.

## Documentation Updates

- Covered in `docs/agent/card-packs.md` (see TID-185 docs update).
