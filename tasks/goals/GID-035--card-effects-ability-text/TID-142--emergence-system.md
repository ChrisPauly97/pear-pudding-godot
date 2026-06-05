# TID-142: Minion Emergence System + New Cards

**Goal:** GID-035
**Type:** agent
**Status:** done
**Depends On:** TID-140

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Minions have no on-play effects — only passive stats and keywords (Ward, Surge, Shroud). This task adds the "Emergence" mechanic: an effect that triggers the moment a minion is summoned to the board. Adds ~5 new minion cards with Emergence effects, one per magic branch.

## Research Notes

**Data model changes:**
- `data/CardData.gd`: add `@export var emergence_effect: String = ""` and `@export var emergence_power: int = 0`.
- `game_logic/battle/CardInstance.gd`: add `var emergence_effect: String = ""` and `var emergence_power: int = 0`; read from template in `_init()` and `from_dict()` / `to_dict()`.

**Emergence effects to support (reuse existing spell effect logic where possible):**
| Key | Behaviour |
|---|---|
| `emergence_deal_damage` | Deal emergence_power damage to the enemy hero |
| `emergence_heal_hero` | Restore emergence_power HP to your hero |
| `emergence_draw` | Draw emergence_power card(s) |
| `emergence_buff_friendly` | Give +emergence_power attack to a random friendly minion (excluding self) |
| `emergence_apply_poison` | Apply emergence_power poison stacks to a random enemy minion |

**Dispatch point:**
- `scenes/battle/BattleScene.gd` — `_on_drop()` already calls `GameState.play_card()` after validating the drop. After the card lands on board, call a new `_resolve_emergence(card, caster_pid)` function.
- AI path: `BasicAI` calls `GameState.play_card()` from `decide_turn()`. After each AI card play, `BattleScene` must also call `_resolve_emergence()`. The cleanest place is after the `"card_played"` signal fires in `BattleScene._on_card_played()` (if it exists) or inline in the AI action loop in `BattleScene._run_ai_turn()`.

**`_resolve_emergence()` function:**
```gdscript
func _resolve_emergence(card: CardInstance, caster_pid: int) -> void:
    if card.emergence_effect == "":
        return
    var snap := _snapshot_hp_positions()
    AudioManager.play_sfx("spell_resolve")  # reuse existing sfx
    var opponent: PlayerState = _state.players[1 - caster_pid]
    var caster: PlayerState = _state.players[caster_pid]
    match card.emergence_effect:
        "emergence_deal_damage":
            opponent.hero.take_damage(card.emergence_power)
        "emergence_heal_hero":
            caster.hero.health = mini(caster.hero.max_health, caster.hero.health + card.emergence_power)
        "emergence_draw":
            for _i in range(card.emergence_power):
                caster.draw_card()
        "emergence_buff_friendly":
            var friendlies := caster.board.get_cards().filter(func(c: CardInstance) -> bool: return c != card)
            if not friendlies.is_empty():
                friendlies[randi() % friendlies.size()].attack += card.emergence_power
        "emergence_apply_poison":
            var enemies := opponent.board.get_cards()
            if not enemies.is_empty():
                enemies[randi() % enemies.size()].apply_status("poison", card.emergence_power)
    _spawn_float_labels_from_snapshot(snap)
    _flash_from_snapshot(snap)
    GameBus.emit_signal("card_played")  # trigger refresh
```

**Ability text display (TID-140 hook):**
- `_EMERGENCE_LABELS: Dictionary` in `BattleScene.gd`:
  - `"emergence_deal_damage"` → "Emergence: Deal [power] damage to the enemy hero"
  - `"emergence_heal_hero"` → "Emergence: Restore [power] HP to your hero"
  - `"emergence_draw"` → "Emergence: Draw [power] card(s)"
  - `"emergence_buff_friendly"` → "Emergence: Give a friendly minion +[power] attack"
  - `"emergence_apply_poison"` → "Emergence: Poison a random enemy minion for [power]"
- TID-140 reads this dict from `_build_card_vbox()` and adds the label when `emergence_effect != ""`.

**New minion cards (5 cards, one per branch):**

| ID | Name | Branch | Cost | ATK | HP | Emergence | Power | Drop source |
|---|---|---|---|---|---|---|---|---|
| ember_imp | Ember Imp | Ember | 2 | 2 | 1 | emergence_deal_damage | 1 | undead_basic |
| dawn_healer | Dawn Healer | Dawn | 3 | 1 | 3 | emergence_heal_hero | 2 | ghoul_pack |
| dusk_seer | Dusk Seer | Dusk | 3 | 1 | 2 | emergence_draw | 1 | undead_horde |
| ash_warden | Ash Warden | Ash | 4 | 2 | 4 | emergence_buff_friendly | 2 | undead_elite |
| void_creeper | Void Creeper | Dusk | 2 | 1 | 3 | emergence_apply_poison | 2 | undead_horde |

Each needs a `.tres` file and a `.uid` sidecar. Colors should match branch: Ember = orange, Dawn = gold, Dusk = purple, Ash = grey.

**CardInspectOverlay update:**
- After the keyword section, add an Emergence section: separator + amber label showing the full Emergence text.
- Reuse `_EMERGENCE_LABELS` or duplicate the dict — document in both files.

**`.uid` generation:**
Run `python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"` for each new `.tres` file.

## Plan

1. Add `emergence_effect: String` and `emergence_power: int` to `CardData.gd` and `CardInstance.gd` (fields, `_init`, `to_dict`, `from_dict`).
2. Add `_EMERGENCE_LABELS` constant and `_get_card_ability_color()` helper to `BattleScene.gd`; update `_get_card_ability_text()` to return emergence text.
3. Add `_resolve_emergence()` function; hook into player play path and AI action loop.
4. Update `CardInspectOverlay.gd` with `_EMERGENCE_LABELS` and amber section.
5. Create 5 `.tres` + `.uid` card files; register in `CardRegistry.gd`; add to enemy drop pools.

## Changes Made

- `data/CardData.gd`: added `emergence_effect` and `emergence_power` exports; added to `to_template_dict()`.
- `game_logic/battle/CardInstance.gd`: added fields; read in `_init()`, serialized in `to_dict()` / `from_dict()`.
- `scenes/battle/BattleScene.gd`:
  - Added `_EMERGENCE_LABELS` constant (5 entries).
  - Added `_get_card_ability_color()` — amber for emergence, green for spells.
  - Updated `_get_card_ability_text()` to return emergence text for minions with `emergence_effect`.
  - Updated `_build_card_vbox()` and `_update_card_view()` to use `_get_card_ability_color()`.
  - Added `_resolve_emergence(card, caster_pid)` — handles 5 emergence effects using existing status/board APIs.
  - `_finish_hand_drag()`: calls `_resolve_emergence()` after player minion placement when `emergence_effect != ""`.
  - `_execute_ai_actions()`: snapshots AI board before action, finds new minions after, calls `_resolve_emergence()`.
- `scenes/battle/CardInspectOverlay.gd`: added `_EMERGENCE_LABELS` constant; added amber emergence section in `_build_ui()`.
- `autoloads/CardRegistry.gd`: added 5 new `const` preloads and registered in `_ensure_loaded()` all-array.
- New card files (`.tres` + `.uid`): `ember_imp`, `dawn_healer`, `dusk_seer`, `ash_warden`, `void_creeper`.
- Enemy drop pools updated: `undead_basic` (+ember_imp), `ghoul_pack` (+dawn_healer), `undead_horde` (+dusk_seer, +void_creeper), `undead_elite` (+ash_warden).

## Documentation Updates

Updated `docs/agent/battle-system.md` — added Emergence mechanic section under Card Data and BattleScene UI.
