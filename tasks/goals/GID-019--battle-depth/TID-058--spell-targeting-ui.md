# TID-058: Spell Targeting UI

**Goal:** GID-019
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Currently all spell cards resolve immediately on drop with auto-targeting. Single-target spells (deal_damage_single, heal_single, shield_minion, buff_attack, lifesteal_hit, curse_minion) should require the player to pick a target. This task adds a target-selection overlay that activates after a targeted spell is dragged to the play zone.

## Research Notes

- `scenes/battle/BattleScene.gd` handles card drag-and-drop; look for `_on_card_dropped` or similar
- `CardData.spell_effect` determines if targeting is needed; add a `targets: String` field to CardData (values: `"none"`, `"friendly_minion"`, `"enemy_minion"`, `"any_minion"`) or derive from spell_effect type
- When a targeted spell is played: pause resolution, highlight valid targets on the board, wait for player tap/click, then resolve with the chosen target
- On mobile: valid targets need a clearly tappable hitbox — use a semi-transparent highlight overlay Panel on each valid slot
- Cancel flow: player should be able to drag the card back to cancel targeting (return card to hand)
- Spells with `targets: "none"` (deal_damage_all, heal_all, mana_drain, draw_card) continue to auto-resolve immediately
- Follow CLAUDE.md UI sizing rules: all overlay controls sized relative to viewport

## Plan

- Derive targeting from `spell_effect`: add `_TARGETED_EFFECTS` const (`["deal_damage_single"]`)
- On drag-drop to board: if targeted spell and can_play, intercept before `play_card()`, enter targeting mode
- Targeting mode: show cyan border on valid targets (enemy minions + hero), show "Cancel Spell" button
- Target chosen: call `play_card()` then `_resolve_spell_effect()` with explicit target dict
- Cancel: clear state, refresh; card stays in hand

## Changes Made

- `scenes/battle/BattleScene.gd`: added `_TARGETED_EFFECTS`, `_targeting_spell`, `_targeting_active` vars; added `_enter_targeting_mode()`, `_cancel_targeting()`, `_on_target_chosen_card()`, `_on_target_chosen_hero()`; modified `_finish_hand_drag()` to intercept targeted spells; modified `_on_enemy_card_input()` and `_on_enemy_hero_input()` to route to target handlers; added cyan border highlight in `_apply_card_style()` and `_refresh_hero()` for targeting mode; updated `_show_cancel_btn()` to accept callback param; modified `_resolve_spell_effect()` to accept `explicit_target: Dictionary = {}`

## Documentation Updates

- Updated `docs/agent/battle-system.md` with spell targeting UI details
