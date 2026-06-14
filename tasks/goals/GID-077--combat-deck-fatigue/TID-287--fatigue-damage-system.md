# TID-287: Fatigue Damage System

**Goal:** GID-077
**Type:** agent
**Status:** pending
**Depends On:** TID-286

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

With reshuffle removed (TID-286), `draw_card()` returns `null` whenever the draw deck is empty. This task turns that empty-draw into escalating fatigue damage: the first failed draw deals 1 damage to the drawing player's hero, the second deals 2, the third 3, and so on. This mirrors Hearthstone's fatigue system and gives both sides a reason to play aggressively once decks thin out.

## Research Notes

### Where fatigue lives

- **`game_logic/battle/PlayerState.gd`** — add `var fatigue_counter: int = 0`. The counter is per-player so each side accumulates independently.
- **`draw_card()` (currently after TID-286)**:
  ```gdscript
  func draw_card() -> CardInstance:
      if draw_deck.is_empty():
          return null  # ← replace this block
      ...
  ```
  Replace with:
  ```gdscript
  func draw_card() -> CardInstance:
      if draw_deck.is_empty():
          fatigue_counter += 1
          hero.take_damage(fatigue_counter)
          _emit_fatigue(fatigue_counter)
          return null
      ...
  ```
  `hero.take_damage()` is already defined on `HeroState` and respects the armor status effect.

### Signal emission pattern

`PlayerState` is a `RefCounted` (no Node, no direct GameBus access). Use the same SceneTree-crawl pattern as `GameState.end_turn()`:
```gdscript
func _emit_fatigue(dmg: int) -> void:
    var ml: MainLoop = Engine.get_main_loop()
    if ml is SceneTree:
        var gb: Node = (ml as SceneTree).root.get_node_or_null("GameBus")
        if gb != null:
            gb.emit_signal("fatigue_damage", player_id, dmg)
```

### GameBus signal

Add to `autoloads/GameBus.gd`:
```gdscript
signal fatigue_damage(player_id: int, damage: int)
```
`BattleScene` should connect to this signal and show a brief "Fatigue!" toast (reuse the existing `_show_text_banner` / weather banner pattern, or a simple short-lived Label in the hero panel area).

### Serialization

Update `PlayerState.to_dict()`:
```gdscript
return {
    ...
    "fatigue_counter": fatigue_counter,
}
```
Update `PlayerState.from_dict()`:
```gdscript
ps.fatigue_counter = int(d.get("fatigue_counter", 0))
```
This is part of `GameState.to_dict()` via the players array, so mid-battle save/restore captures it automatically. No top-level `SaveManager` migration needed.

### BattleScene integration

- **Floating labels:** `BattleScene._snapshot_hp_positions()` / `_spawn_float_labels_from_snapshot()` already capture all hero HP changes and show red floating labels. Fatigue damage flows through `hero.take_damage()` so labels appear automatically — no extra plumbing.
- **Game-over check:** `BattleScene._check_game_over()` is called after `start_turn()` which calls `draw_card()`. Fatigue damage that kills a hero will be caught here. Confirm the call order in `_on_turn_ended()`.
- **Toast banner:** After connecting `GameBus.fatigue_damage`, add a short "Fatigue! −N" label near the affected hero panel. Keep it simple — a Label that auto-frees after 1.5s is enough. Size font at `_vh * 0.025`, color orange `Color(1, 0.55, 0)`.

### AI path

`BasicAI` calls `player.draw_card()` indirectly via `PlayerState.start_turn()`. No changes needed — the AI takes fatigue damage the same as the player.

### Puzzle mode

Puzzle battles have no draw deck. `draw_card()` is never called during a puzzle, so fatigue can never fire. No special-casing needed.

### Tests

- In `tests/unit/`, add or extend a test that: builds a deck with 1 card, draws it, then draws again (empty deck) and asserts `hero.health == 29` (fatigue = 1 damage), then draws once more and asserts `hero.health == 27` (fatigue = 2 damage cumulative).
- Confirm existing tests still pass (they use 12-card decks so fatigue never fires).

## Plan

1. `autoloads/GameBus.gd` — add `signal fatigue_damage(player_id: int, damage: int)`.
2. `game_logic/battle/PlayerState.gd`:
   - Add `var fatigue_counter: int = 0`.
   - Replace `return null` in the empty-draw branch of `draw_card()` with the fatigue block.
   - Add `_emit_fatigue(dmg: int)` helper using the SceneTree-crawl pattern.
   - Update `to_dict()` / `from_dict()` to persist `fatigue_counter`.
3. `scenes/battle/BattleScene.gd`:
   - Connect `GameBus.fatigue_damage` in `_ready()`.
   - Add `_on_fatigue_damage(player_id, dmg)` handler: show a short-lived "Fatigue! −N" label near the affected hero panel, then call `_check_game_over()`.
4. Add a unit test in `tests/unit/test_battle_fatigue.gd` covering the scenarios above.
5. Update `docs/agent/battle-system.md` — add a "Deck Fatigue (GID-077)" section under "How It Works".

## Changes Made

_(fill in after implementation)_

## Documentation Updates

- `docs/agent/battle-system.md` — add Deck Fatigue section: counter per player, escalating damage formula, serialization note, no reshuffle.
