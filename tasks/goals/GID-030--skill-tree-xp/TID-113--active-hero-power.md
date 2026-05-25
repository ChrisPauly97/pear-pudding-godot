# TID-113: Active Hero Power in BattleScene

**Goal:** GID-030
**Type:** agent
**Status:** done
**Depends On:** TID-111

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Active skills give the player a once-per-battle hero power button in BattleScene. Only the first active skill in `unlocked_skills` is used (or the highest-tier one — design decision made during Plan). This is analogous to a Hearthstone hero power: a reliable, free action available every battle that becomes stronger as the player levels up.

## Research Notes

**Design decision:** if multiple active skills are unlocked, use the last one in `unlocked_skills` (most recently unlocked = highest tier). This keeps the UI simple — one button.

**BattleScene UI additions:**
- Add a `Button` named `_hero_power_btn` to the player hero area (below/beside the existing player hero view).
- Visible only when at least one active skill is unlocked.
- Disabled after use for the battle (track `_hero_power_used: bool`).
- Button label: active skill's `display_name`.
- On press: call `_use_hero_power()`.

**`_use_hero_power()` logic:**
```gdscript
const SkillData = preload("res://data/SkillData.gd")
var _hero_power_used: bool = false

func _use_hero_power() -> void:
    if _hero_power_used:
        return
    var active_skill: SkillData = _get_active_skill()
    if active_skill == null:
        return
    _hero_power_used = true
    _hero_power_btn.disabled = true
    match active_skill.effect_type:
        "active_damage_all":
            for zone in _state.players[1].board:  # enemy board zones
                if zone.minion != null:
                    zone.minion.health -= active_skill.effect_value
                    if zone.minion.health <= 0:
                        _state.players[1].remove_minion(zone)
            _refresh_board_views()
        "active_heal":
            _state.players[0].hero.health = mini(
                _state.players[0].hero.health + active_skill.effect_value,
                _state.players[0].hero.max_health)
            _refresh_hero_views()
        "active_draw":
            for i in active_skill.effect_value:
                _draw_card(_state.players[0])
        "active_mana":
            _state.players[0].hero.mana = mini(
                _state.players[0].hero.mana + active_skill.effect_value,
                _state.players[0].hero.max_mana)
            _refresh_hero_views()

func _get_active_skill() -> SkillData:
    var result: SkillData = null
    for skill_id in SceneManager.save_manager.unlocked_skills:
        var sk: SkillData = SkillRegistry.get_skill(skill_id)
        if sk != null and sk.skill_type == "active":
            result = sk
    return result  # last active skill wins
```

**UI sizing (CLAUDE.md pattern):**
```gdscript
_hero_power_btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.05)
_hero_power_btn.add_theme_font_size_override("font_size", int(_vh * 0.02))
```

**Files to modify:**
- `scenes/battle/BattleScene.gd` — add `_hero_power_btn`, `_hero_power_used`, `_use_hero_power()`, `_get_active_skill()`
- `scenes/battle/BattleScene.tscn` — if UI is built in the scene file, add the button node; if BattleScene builds UI in code, handle entirely in `.gd`

**Note:** Check whether BattleScene builds its layout in code or via `.tscn`. If `.tscn`, add the button node there. If code-only, add it in `_build_ui()` or equivalent.

**Board/zone data access:** Verify the exact field names on `PlayerState` for board zones — check `game_logic/battle/PlayerState.gd` and `ZoneState.gd` before implementing `active_damage_all`.

## Plan

1. Add `_hero_power_btn: Button` and `_hero_power_used: bool` vars to BattleScene.
2. Add `_add_hero_power_button()` call in `_ready()` after `_add_pause_button()`.
3. Implement `_add_hero_power_button()` — creates Button in SidePanel if an active skill is unlocked.
4. Implement `_get_active_skill()` — iterates `unlocked_skills`, returns last active skill.
5. Implement `_use_hero_power()` — guards double-use, dispatches on `effect_type`, calls `_refresh_all()`.

## Changes Made

- `scenes/battle/BattleScene.gd`: added `_hero_power_btn` and `_hero_power_used` vars; added `_add_hero_power_button()` call in `_ready()`; added `_add_hero_power_button()` (creates button in SidePanel with display_name label, hidden when no active skill), `_get_active_skill()` (returns last active in unlocked_skills), `_use_hero_power()` (guards re-use, dispatches active_damage_all/active_heal/active_draw/active_mana, calls `_refresh_all()`)

## Documentation Updates

No separate doc update; battle-system.md will be updated in TID-114 when the Skill Tree Scene is added.
