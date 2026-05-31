# TID-119: Update SkillTreeScene — Home Tabs + Cross-Magic Tab

**Goal:** GID-031
**Type:** agent
**Status:** pending
**Depends On:** TID-116, TID-117, TID-118

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The existing `SkillTreeScene` shows a single flat grid of all skills. It needs to become a tabbed view: two tabs for the player's home branches (e.g. Ember + Dawn for light players), plus a third "Cross-Magic" tab showing only the opposing type's alt-cost skills. All three currency balances are visible in the header.

## Research Notes

**Current SkillTreeScene structure** (`scenes/ui/SkillTreeScene.gd`):
- `_build_ui()` builds a VBox with a header HBox + ScrollContainer/GridContainer
- `_refresh()` populates the grid from `SkillRegistry.get_all_ids()`
- Grid constants: `_ROWS = 3`, `_COLS = 5`
- No tab state currently

**New state fields:**
```gdscript
var _active_tab: int = 0  # 0 = first home branch, 1 = second home branch, 2 = cross-magic
var _tab_buttons: Array[Button] = []
```

**Tab bar (insert between header and scroll container):**
- HBoxContainer with 3 Buttons
- Light player labels: "Ember", "Dawn", "Cross-Magic"
- Dark player labels: "Dusk", "Ash", "Cross-Magic"
- Active tab button: modulate white; inactive: modulate grey (0.6, 0.6, 0.6)
- Each tab button calls `_set_tab(i)` → updates `_active_tab`, refreshes button modulates, calls `_refresh()`

**Branch colour hints (modulate the tab button slightly):**
| Branch | Tab colour tint |
|--------|----------------|
| ember  | Color(1.0, 0.7, 0.4) orange |
| dawn   | Color(1.0, 1.0, 0.55) yellow |
| dusk   | Color(0.7, 0.5, 1.0) purple |
| ash    | Color(0.65, 0.65, 0.65) grey |
| cross-magic | Color(0.9, 0.9, 0.9) neutral |

**Updated `_refresh()` logic:**
```gdscript
func _refresh() -> void:
    _points_label.text = "SP: %d  |  Corruption: %d  |  Redemption: %d" % [
        sm.skill_points, sm.corruption_points, sm.redemption_points]
    # clear grid ...
    var branch: String = _branch_for_tab(_active_tab)
    var ids: Array[String]
    if _active_tab == 2:
        # Cross-magic: only skills from opposing magic with alt_cost > 0
        ids = _cross_magic_ids()
    else:
        ids = SkillRegistry.get_by_branch(branch)
    # build skill_map by (row,col), render grid as before
```

**`_cross_magic_ids()` helper:**
```gdscript
func _cross_magic_ids() -> Array[String]:
    var opposing: String = _opposing_magic(SceneManager.save_manager.magic_type)
    var branches: Array = MAGIC_BRANCHES[opposing]
    var result: Array[String] = []
    for b in branches:
        for sid in SkillRegistry.get_by_branch(b):
            var sk: SkillData = SkillRegistry.get_skill(sid)
            if sk != null and sk.alt_cost > 0:
                result.append(sid)
    return result
```

**Cross-magic skill node differences (in `_make_skill_node`):**
- Show `alt_cost` instead of "1 SP" in the unlock button label: e.g. "Unlock (2 CP)" or "Unlock (2 RP)" depending on opposing magic type
- Unlock button checks the correct currency balance (`corruption_points` or `redemption_points`) and spends it via a new `SaveManager.unlock_cross_skill(id, cost, currency)` method:
  ```gdscript
  func unlock_cross_skill(id: String, cost: int, currency: String) -> void:
      if currency == "corruption" and corruption_points >= cost:
          corruption_points -= cost
      elif currency == "redemption" and redemption_points >= cost:
          redemption_points -= cost
      else:
          return
      unlock_skill(id)  # reuse existing — appends to unlocked_skills, no SP deducted
  ```
  Note: `unlock_skill` currently decrements `skill_points` — add a guard so it only does so when called for home-branch skills. Simplest fix: add `func unlock_cross_skill()` that appends to `unlocked_skills` directly without touching `skill_points`.

**Currency label for cross-magic tab:**
- Light players buying dark skills spend **Redemption Points** (they redeemed themselves by choosing light-aligned dialogue)
- Dark players buying light skills spend **Corruption Points** (they were corrupted by choosing dark-aligned dialogue)
- Wait — re-read: dark dialogue choices → corruption points; light dialogue choices → redemption points.
  - Dark players earn corruption from dark choices. Light branch cross-magic skills cost corruption points for dark players? That's backwards.
  
  **Clarification:** The intent is:
  - Making choices that go **against your nature** earns the opposing currency.
  - Light player chooses dark dialogue → earns corruption points → spends them on dark (dusk/ash) skills.
  - Dark player chooses light dialogue → earns redemption points → spends them on light (ember/dawn) skills.
  
  So:
  - Cross-magic currency for a **light player** (buying dark skills) = **corruption_points**
  - Cross-magic currency for a **dark player** (buying light skills) = **redemption_points**

**`_cross_currency()` helper:**
```gdscript
func _cross_currency() -> String:
    return "corruption" if SceneManager.save_manager.magic_type == "light" else "redemption"
```

**Files to modify:**
- `scenes/ui/SkillTreeScene.gd` — full rewrite of tab/refresh logic
- `autoloads/SaveManager.gd` — add `unlock_cross_skill(id, cost, currency)`

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
