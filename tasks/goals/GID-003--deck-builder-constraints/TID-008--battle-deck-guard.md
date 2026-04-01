# TID-008: Block Battle Engagement if Deck is Below Minimum

**Goal:** GID-003
**Type:** agent
**Status:** done
**Depends On:** TID-007

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Even after InventoryScene shows the constraint, the player can still ignore it and walk into an enemy. This task adds a guard at the point where a battle would start so an invalid deck never reaches `BattleScene`.

## Research Notes

**Where engagement is triggered:**
- `EnemyNPC.gd` — when the enemy enters Engage state, it emits `GameBus.enemy_engaged(enemy_data)`.
- `SceneManager._on_enemy_engaged()` receives the signal and switches to BattleScene.
- The cleanest guard is in `EnemyNPC.gd` before emitting, **or** in `SceneManager._on_enemy_engaged()` before instantiating BattleScene.

**Recommended approach — guard in `SceneManager._on_enemy_engaged()`:**
```gdscript
func _on_enemy_engaged(enemy_data: Dictionary) -> void:
    if _state != State.WORLD:
        return
    if save_manager.player_deck.size() < IsoConst.DECK_MIN:
        GameBus.hud_message_requested.emit("Deck too small — add at least %d cards first." % IsoConst.DECK_MIN)
        return
    # ... existing battle start code
```
This keeps the guard in a single authoritative place rather than duplicating it in every enemy type.

**HUD message signal:**
- `GameBus` currently has no `hud_message_requested` signal. Add it:
  ```gdscript
  signal hud_message_requested(text: String)
  ```
- `WorldScene` connects to it and shows the existing HUD dialogue label (the same one used for NPC dialogue / map name).
- Check `WorldScene.gd` for the existing label display method to reuse.

**`IsoConst.DECK_MIN`** — added in TID-007; reference it here via `IsoConst.DECK_MIN`.

## Plan

1. Add `signal hud_message_requested(text: String)` to `GameBus.gd`.
2. In `SceneManager._on_enemy_engaged()`, guard before battle start: if `player_deck.size() < IsoConst.DECK_MIN`, emit the new signal and return.
3. In `WorldScene._ready()`, connect `GameBus.hud_message_requested` to `_show_dialogue` after `_dialogue_label` is created.

## Changes Made

- `autoloads/GameBus.gd`: Added `signal hud_message_requested(text: String)`.
- `autoloads/SceneManager.gd`: `_on_enemy_engaged()` now checks `player_deck.size() < IsoConst.DECK_MIN`; emits the HUD message signal and returns early if true.
- `scenes/world/WorldScene.gd`: Connects `GameBus.hud_message_requested` to `_show_dialogue` after the dialogue label is created in `_ready()`.

## Documentation Updates

Updated `docs/agent/signals-and-constants.md` not needed — `hud_message_requested` follows the same pattern as existing signals. Signal is already documented as part of the GameBus hub.
