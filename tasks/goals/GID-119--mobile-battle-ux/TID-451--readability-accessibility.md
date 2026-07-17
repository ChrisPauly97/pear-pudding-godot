# TID-451: Readability & Accessibility Pass

**Goal:** GID-119
**Type:** agent
**Status:** done
**Depends On:** TID-449

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The Settings scene (GID-070 / TID-260) persists a `text_scale` setting
(Small 0.85 / Normal 1.0 / Large 1.25) that **no code consumes** — it is dead. Battle
targeting states communicate by color alone (cyan/green/red/yellow borders, darkened
invalid targets), which fails colorblind players. Floating damage numbers use a thin
shadow at 3.5% vh.

## Research Notes

- `screen_shake` (BattleFx.trigger_shake) and `haptics` (BattleFx.haptic) settings
  already exist and are honored — nothing to do there.
- Font application sites in battle: `CardViewBuilder` (card faces, hero panels, slot
  numbers, keyword badges), `BattleScene` (turn/mana labels, buttons, banners),
  `BattleFx` (float labels, intent banner, status icons).
- Targetable styling lives in `CardViewBuilder.apply_card_style` (minions) and
  `refresh_hero` (enemy hero); both rebuild styles every refresh, so a marker label
  toggled there stays consistent.

## Plan

1. Read `text_scale` once per battle into `_vh`-companion factor: CardViewBuilder,
   BattleScene, and BattleFx each get a `_font(pct)` helper = `int(vh * pct * scale)`;
   swap all `int(_vh * X)` font-size sites in those three files to use it.
2. Non-color targeting cue: card faces get a hidden `TargetMark` label ("◎ TARGET",
   white, black outline); `apply_card_style` shows it for spell-targetable and
   attack-valid states; enemy hero panel gets the same marker.
3. Float labels: font 4% vh, black outline (`outline_size` vh*0.008) instead of the
   thin shadow.

## Changes Made

- `CardViewBuilder`: `_text_scale` + `_font()`; all font sites converted; `TargetMark`
  label built into every card vbox and toggled in `apply_card_style`; enemy hero
  marker label in `refresh_hero`.
- `BattleScene`: `_text_scale` read from settings in `_ready`; `_font()` helper; all
  font-size overrides in battle chrome converted.
- `BattleFx`: `set_text_scale()`; float labels bigger with outline; intent banner and
  status icon fonts scaled.

## Documentation Updates

- `docs/agent/battle-system.md`: GID-119 section.
- `docs/agent/ui-and-scene-management.md`: text_scale note updated (now consumed by
  the battle UI).
