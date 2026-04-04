# TID-037: BattleScene weapon effect hook

**Goal:** GID-014
**Type:** agent
**Status:** done
**Depends On:** TID-034, TID-035, TID-036

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Wires everything together: at battle start, reads the equipped weapon from SaveManager, resolves it via WeaponRegistry, and applies its effect to the player state before the opening hand is drawn. This is the task that makes weapons actually work in battle.

## Research Notes

**File:** `scenes/battle/BattleScene.gd`

**Battle start sequence (lines ~40–73 of BattleScene.gd):**
```
_ready():
  1. _state = GameState.new()
  2. build player deck from SaveManager.player_deck
  3. _state.players[0].build_deck(player_deck)  ← weapon injection goes HERE (after build_deck, before draw_opening_hand)
  4. _state.players[0].draw_opening_hand(4)
  5. build enemy deck...
  6. _state.players[1].build_deck(enemy_deck)
  7. _state.players[1].draw_opening_hand(4)
  8. _state.players[0].start_turn(1)
  9. _refresh_all()
```

**Injection point:** between steps 3 and 4. After `build_deck()` has populated `draw_deck`, inject weapon cards before the opening hand is drawn so they can appear in the opening hand naturally.

**Effect type implementations:**

```gdscript
func _apply_weapon_effect(player: PlayerState) -> void:
    if SaveManager.equipped_weapon == "":
        return
    var weapon: WeaponData = WeaponRegistry.get_weapon(SaveManager.equipped_weapon)
    if weapon == null:
        return
    match weapon.battle_effect_type:
        "deck_inject":
            for i in weapon.injected_card_count:
                var card: CardInstance = CardInstance.from_template(
                    CardRegistry.get_template(weapon.injected_card_id).to_template_dict())
                player.draw_deck.append(card)
            player.draw_deck.shuffle()
        "starting_mana":
            # One-time turn-1 bonus — add directly to hero.mana (not max_mana)
            player.hero.mana = min(player.hero.mana + weapon.battle_effect_value, player.hero.max_mana + weapon.battle_effect_value)
            player.hero.max_mana += weapon.battle_effect_value  # only for turn 1 calculation
            # NOTE: gain_mana_for_turn() on turn 2+ resets max_mana = min(10, turn) — so this is naturally one-time
        "starting_hp":
            player.hero.health += weapon.battle_effect_value
            player.hero.max_health += weapon.battle_effect_value
        "passive_atk":
            player.hero.attack += weapon.battle_effect_value
```

**Important mana note:** `HeroState.gain_mana_for_turn(turn)` sets `max_mana = min(10, turn)` unconditionally each turn. So even if we add to max_mana on turn 1, by turn 2 it resets to 2. Starting mana bonus is naturally one-time — no special cleanup needed. This preserves the mana cap invariant.

**Strict-mode notes:**
- `player.draw_deck` is `Array[CardInstance]` — appending `CardInstance` is fine
- `player.draw_deck.shuffle()` is a method on typed Array — fine
- Match on String is valid GDScript
- `CardRegistry.get_template()` returns `CardData`; verify `to_template_dict()` exists (it does per research)

**No UI changes needed** — weapons have no visible widget in battle for this task. The effect is silent/mechanical.

## Plan

1. Add `WeaponRegistry` and `WeaponData` preloads to BattleScene.gd.
2. Add `_apply_weapon_effect(player)` method implementing all four effect types.
3. Call it in `_ready()` after `build_deck()` and before `draw_opening_hand()`.

## Changes Made

- `scenes/battle/BattleScene.gd`: Added `WeaponRegistry` and `WeaponData` preloads; added `_apply_weapon_effect()` function; wired call between `build_deck` and `draw_opening_hand`.

## Documentation Updates

TID-038 will update `docs/agent/inventory-and-deck.md`.
