# TID-008: Block Battle Engagement if Deck is Below Minimum

**Goal:** GID-003
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
