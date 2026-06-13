# TID-279: New Spell Effect Engine — 20 New Effect Keys

**Goal:** GID-076
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The existing `BattleScene._resolve_spell_effect` covers 14 effects. This task adds 20 more to support the new spell cards. It also updates targeting arrays and `_SPELL_EFFECT_LABELS` in both BattleScene and CardInspectOverlay.

## Research Notes

### File to edit
`scenes/battle/BattleScene.gd`

### Existing targeting arrays (lines ~56–57)
```gdscript
const _ENEMY_TARGETED_EFFECTS: Array[String] = ["deal_damage_single", "curse_minion", "lifesteal_hit"]
const _FRIENDLY_TARGETED_EFFECTS: Array[String] = ["heal_single", "shield_minion", "buff_attack"]
```

Add to `_ENEMY_TARGETED_EFFECTS`: `"apply_poison_single"`, `"freeze_single"`, `"bind_minion"`, `"stun_single"`
Add to `_FRIENDLY_TARGETED_EFFECTS`: `"grant_surge"`, `"grant_ward"`, `"grant_shroud"`, `"double_attack"`

### Existing `_SPELL_EFFECT_LABELS` dict (lines ~63–77)
Add 20 new entries. Mirror the same additions to `CardInspectOverlay._SPELL_EFFECT_LABELS`.

### `_resolve_spell_effect` function (~line 1295)
Add new `match` cases. All new effects listed below with implementation notes.

### Status effects system
`CardInstance` and `HeroState` both support `apply_status(id, val)`, `has_status(id)`, `take_damage(dmg)`.
Status effects: `"poison"`, `"armor"`, `"freeze"`, `"stun"`. The `"freeze"` and `"stun"` effects already decrement at turn start and block `can_attack()`.

### Keywords
`const Keywords = preload("res://game_logic/battle/Keywords.gd")` — use `Keywords.WARD`, `Keywords.SURGE`, `Keywords.SHROUD`. Do NOT use bare string literals.
`CardInstance` has `keywords: PackedStringArray` — mutable at runtime.
For keyword grant effects, push the keyword string to `card.keywords` on the `CardInstance`.
For `bind_minion`: set `card.keywords = PackedStringArray()` to strip all keywords.

### Summon tokens (`summon_token`)
`PlayerState.board` is a `ZoneState`. `ZoneState.get_empty_slots() -> Array[int]` returns empty slot indices. `ZoneState.add_card(card: CardInstance)` adds a card.
To create a token: `CardRegistry.get_card("skeleton")` returns the base template; wrap in `CardInstance.new(template)`.
Token has `summoning_sick = true` (no Surge).

### Enemy discard (`enemy_discard`)
`PlayerState.hand: Array[CardInstance]` — shuffle then remove `min(spell_power, hand.size())` cards.

### Double attack (`double_attack`)
On the targeted friendly minion, set `attack_count = 0` and `summoning_sick = false`. This allows one more attack this turn via `can_attack()`.

### Hero-direct effects
`PlayerState.hero: HeroState` — call `hero.take_damage(n)` or `hero.heal(n)`.
`drain_hero`: deals `spell_power` to enemy hero AND heals caster hero by same amount.
`deal_damage_hero`: deals `spell_power` to enemy hero only.
`heal_hero`: restores `spell_power` HP to caster hero (cap at max_health).
`armor_hero`: `caster.hero.apply_status("armor", spell_power)`.

### `deal_damage_all_full` (Ash capstone)
Deal `spell_power` damage to every enemy minion AND enemy hero.

### All 20 new effects

| Effect key | Type | Target | Implementation |
|---|---|---|---|
| `deal_damage_hero` | auto | enemy hero | `enemy.hero.take_damage(power)` |
| `apply_poison_single` | enemy targeted | 1 enemy minion | `target.apply_status("poison", power)` |
| `apply_poison_all` | auto | all enemy minions | loop `enemy.board.get_cards()`, apply_status poison |
| `grant_surge` | friendly targeted | 1 friendly minion | push `Keywords.SURGE` to `target.keywords`; `target.summoning_sick = false` |
| `double_attack` | friendly targeted | 1 friendly minion | `target.attack_count = 0; target.summoning_sick = false` |
| `buff_attack_all` | auto | all friendly minions | loop `caster.board.get_cards()`, `card.attack += power` |
| `heal_hero` | auto | caster hero | `caster.hero.heal(power)` |
| `armor_hero` | auto | caster hero | `caster.hero.apply_status("armor", power)` |
| `grant_ward` | friendly targeted | 1 friendly minion | push `Keywords.WARD` to `target.keywords` |
| `grant_shroud` | friendly targeted | 1 friendly minion | push `Keywords.SHROUD` to `target.keywords`; `target.shroud_active = true` |
| `grant_ward_all` | auto | all friendly minions | loop, push `Keywords.WARD` |
| `bind_minion` | enemy targeted | 1 enemy minion | `target.keywords = PackedStringArray(); target.shroud_active = false` |
| `buff_health_all` | auto | all friendly minions | loop, `card.health += power; card.max_health += power` |
| `enemy_discard` | auto | enemy hand | shuffle enemy hand, remove min(power, size) cards → discard |
| `freeze_single` | enemy targeted | 1 enemy minion | `target.apply_status("freeze", 1)` |
| `freeze_all` | auto | all enemy minions | loop `enemy.board.get_cards()`, apply_status freeze 1 |
| `drain_hero` | auto | both heroes | `enemy.hero.take_damage(power); caster.hero.heal(power)` |
| `stun_single` | enemy targeted | 1 enemy minion | `target.apply_status("stun", power); target.out_of_play = true` |
| `summon_token` | auto | caster board | create `power` Skeleton CardInstances in empty slots |
| `deal_damage_all_full` | auto | all enemy entities | deal to each minion + hero |

### HeroState.heal
Check if `heal(n)` method exists on HeroState. If not, implement as:
```gdscript
health = min(health + n, max_health)
```
(Same pattern as shield_minion's existing code that caps at max_health.)

### Labels (add to both `_SPELL_EFFECT_LABELS` dicts)
```gdscript
"deal_damage_hero":    "Deal [power] damage to the enemy hero",
"apply_poison_single": "Poison a minion for [power] damage per turn",
"apply_poison_all":    "Poison all enemy minions for [power] damage per turn",
"grant_surge":         "Give a friendly minion Surge",
"double_attack":       "A friendly minion attacks twice this turn",
"buff_attack_all":     "Give all your minions +[power] attack",
"heal_hero":           "Restore [power] HP to your hero",
"armor_hero":          "Give your hero [power] armor",
"grant_ward":          "Give a friendly minion Ward",
"grant_shroud":        "Give a friendly minion Shroud",
"grant_ward_all":      "Give all your minions Ward",
"bind_minion":         "Strip all keywords from an enemy minion",
"buff_health_all":     "Give all your minions +[power] health",
"enemy_discard":       "Enemy discards [power] random card(s)",
"freeze_single":       "Freeze an enemy minion for 1 turn",
"freeze_all":          "Freeze all enemy minions for 1 turn",
"drain_hero":          "Deal [power] to the enemy hero; restore that much HP to yours",
"stun_single":         "Stun an enemy minion for [power] turn(s)",
"summon_token":        "Summon [power] 1/1 Skeleton token(s)",
"deal_damage_all_full":"Deal [power] damage to all enemy minions and their hero",
```

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
