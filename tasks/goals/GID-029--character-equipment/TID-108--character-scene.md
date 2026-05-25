# TID-108: CharacterScene UI

**Goal:** GID-029
**Type:** agent
**Status:** done
**Depends On:** TID-106

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Players need a single place to view and manage all 4 equipment slots. This CharacterScene is a full-screen overlay (similar to InventoryScene) showing the player avatar flanked by slot buttons. Tapping a slot opens an inline picker listing owned equipment of that type. The weapons tab inside `InventoryScene` is removed and replaced by CharacterScene to avoid duplication.

## Research Notes

**Opening mechanism:**
- `GameBus` new signal: `character_requested` (no args)
- `WorldScene` emits it on `InputMap` action `"character"` (key C)
- HUD: new flat Button layered above the HUD, label "C" or a character icon; `pressed` emits `GameBus.character_requested`
- `SceneManager` instantiates `CharacterScene` as an overlay (same pattern as `_on_inventory_requested`)

**SceneManager additions:**
```gdscript
var _character_scene_packed := preload("res://scenes/ui/CharacterScene.tscn")
var _character_overlay: Node = null

func _on_character_requested() -> void:
    if _character_overlay != null:
        return
    _character_overlay = _character_scene_packed.instantiate()
    get_tree().current_scene.add_child(_character_overlay)
    _character_overlay.closed.connect(_on_character_closed)

func _on_character_closed() -> void:
    if _character_overlay != null:
        _character_overlay.queue_free()
        _character_overlay = null
```

**CharacterScene layout (code-only, no .tscn needed beyond a minimal wrapper):**
```
VBoxContainer (full screen)
  HBoxContainer (top bar)
    Label "Character"
    Button "Close"
  HSplitContainer
    Left panel — avatar + slot grid
      TextureRect (player sprite placeholder — assets/textures/player.png or solid colour rect)
      GridContainer (2×2)
        Button "Weapon: <name or Empty>"
        Button "Armor:  <name or Empty>"
        Button "Ring:   <name or Empty>"
        Button "Trinket: <name or Empty>"
    Right panel — item picker (hidden until slot tapped)
      Label "<Slot> items"
      ScrollContainer
        VBoxContainer (_picker_list)
      Button "Unequip"
```

**Slot button tap** populates `_picker_list` with one row per owned item of that slot (from `SaveManager.owned_weapons` filtered by WeaponRegistry slot field + the new owned_armor/rings/trinkets arrays). Each row: item name, effect summary, "Equip" button.

**Removing weapons tab from InventoryScene:**
- `InventoryScene.gd` has a `_tab_weapons_btn`, `_weapons_panel`, `_weapon_list`, `_equipped_col`, `_equip_btn`, `_selected_weapon_id` — remove all of these and the `_on_tab_weapons()` handler and `_refresh_weapons()`.
- Keep tabs: Cards only (or Cards + stats summary if desired).

**UI sizing rules (CLAUDE.md):**
```gdscript
var _vh: float = get_viewport().get_visible_rect().size.y
slot_btn.custom_minimum_size = Vector2(_vh * 0.22, _vh * 0.06)
```

**Mobile:** HUD button must be a visible tap target (not keyboard-only). Add it beside the existing inventory/map buttons in the HUD.

**Effect summary helper** — reuse or copy `_weapon_effect_summary()` logic from ShopScene.

**Input action:** add `"character"` action mapped to `KEY_C` in `project.godot` under `[input]`. Check existing input map to avoid conflicts.

## Plan

1. Add `character_requested` signal to GameBus.
2. Add `CHARACTER` state, preload, overlay var, signal connect, and handler pair to SceneManager.
3. Add `character` input action (KEY_C) to project.godot.
4. Add Character HUD button and `_unhandled_input` handler to WorldScene.
5. Create CharacterScene.gd: full-screen overlay with avatar placeholder, 4 slot buttons, inline item picker (right panel), equip/unequip logic.
6. Create CharacterScene.tscn + .tscn.uid + .gd.uid sidecars.
7. Remove weapons tab from InventoryScene: strip WeaponRegistry/WeaponData imports, var declarations, build section, refresh/column/summary/row methods, tab handler, weapon event handlers.

## Changes Made

- `autoloads/GameBus.gd`: added `signal character_requested`
- `autoloads/SceneManager.gd`: added `CHARACTER` to State enum; `_character_scene_packed` preload; `_character_overlay` var; signal connection in `_ready()`; `_on_character_requested()` / `_on_character_closed()` handlers; `_character_overlay` cleanup in `_exit_world_cleanup()`
- `project.godot`: added `character` input action mapped to KEY_C (physical_keycode 67)
- `scenes/world/WorldScene.gd`: added Character HUD button (position: 3rd button below minimap); added `event.is_action_pressed("character")` branch to `_unhandled_input`
- `scenes/ui/CharacterScene.gd`: new full-screen overlay — dark backdrop, panel with header + close button, left column (avatar placeholder + 4 slot buttons with live labels), right column (picker title + scrollable item list + Unequip button). Slot tap populates picker with owned items for that slot, each showing effect summary and Equip button. Input action `character` / `ui_cancel` closes.
- `scenes/ui/CharacterScene.tscn` + `.tscn.uid` + `CharacterScene.gd.uid`: new scene files
- `scenes/ui/InventoryScene.gd`: removed Weapons tab entirely — `WeaponRegistry`/`WeaponData` imports, all weapon UI var declarations, WEAPONS PANEL build section, `_refresh_weapons()`, `_refresh_comparison()`, `_fill_weapon_column()`, `_weapon_effect_summary()`, `_make_weapon_row()`, `_on_tab_weapons()`, `_on_weapon_selected()`, `_on_equip_weapon()`; tab visibility handlers simplified to Cards/Craft only

## Documentation Updates

Updated `docs/agent/inventory-and-deck.md` and `docs/agent/ui-and-scene-management.md` to reflect CharacterScene addition and InventoryScene weapons tab removal.
