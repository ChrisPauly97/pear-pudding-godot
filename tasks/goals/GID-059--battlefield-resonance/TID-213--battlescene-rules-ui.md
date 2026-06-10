# TID-213: BattleScene UI: battlefield banner, rule text, affected-slot highlights

**Goal:** GID-059
**Type:** agent
**Status:** pending
**Depends On:** TID-212

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

TID-212 makes biome and time-of-day mechanically affect battles, but invisible rules feel like bugs. This task surfaces Battlefield Resonance in `scenes/battle/BattleScene.gd`: a battlefield banner at battle start (biome name + rule text + day/night indicator), persistent highlights on rule-affected board slots (Forest edges 0/4, Mountains center 2), and discounted-cost display on hand cards so Grasslands/Dawn/Dusk discounts are legible before playing.

## Research Notes

**BattleScene structure (verified, `scenes/battle/BattleScene.gd`, ~1700 lines):**
- `var enemy_data: Dictionary = {}` (line 19), `var _state: GameState` (line 20). `_ready()` at line 103: restores `GameState.from_dict()` from `SaveManager.pending_battle_state` if present, else builds decks from `enemy_data` / SaveManager, then `_refresh_all()`, music, tutorial. Battlefield context arrives per TID-212 (in `enemy_data` and/or on `GameState`) — the UI must read it from wherever TID-212 puts it, including on the resume path.
- Scene file: `scenes/battle/BattleScene.tscn`; side panel nodes `$SidePanel/EndTurnButton`, `$SidePanel/MenuButton` (lines 100–101). Board slots are 5 slot panels per player rendered with status icons (see docs/agent/battle-system.md "BattleScene UI").

**Existing banner patterns to copy (verified in docs/agent/battle-system.md + BattleScene):**
- **Enemy intent banner (TID-059):** `_show_intent_banner(text)` / `_hide_intent_banner()` — centered panel shown before AI actions (called at lines 1202, 1208). Closest pattern for a transient battlefield banner.
- **Boss banner:** `_show_boss_banner()` called from `_ready()` line 149 when `enemy_data["is_boss"]` — example of a battle-start announcement driven by `enemy_data`.
- Float layer: `_float_layer = CanvasLayer.new(); _float_layer.layer = 128` (lines 104–106) for transient labels; pause overlay uses layer 200. A battlefield banner CanvasLayer should sit below 200.

**Card cost display:**
- Card faces are built by `_build_card_vbox()` and refreshed by `_update_card_view()`; keyword badges via `_update_keyword_badges(hbox, card)` (docs/agent/battle-system.md "Keyword UI (TID-095)"). To show a discounted cost, the cost label needs to render `PlayerState.effective_cost(card)` (TID-212 helper) instead of `card.cost`, ideally tinted (e.g. green) when discounted. Grasslands discount disappears after the first card is played each turn — refresh hooks already exist: `_refresh_all()` is called after every state change and on `GameBus.turn_ended` (`_on_turn_ended`, line 1175).
- `CardInspectOverlay.gd` (`scenes/battle/CardInspectOverlay.gd`) shows full card detail — optionally add a "costs 1 less (Dusk, night)" line; keep its `_SPELL_EFFECT_LABELS` mirror untouched.

**Slot highlights (Forest 0/4, Mountains 2):**
- Slot panels are restyled every refresh via `_apply_card_style()` (which already darkens non-Ward-targetable enemy minions by 0.45 — see battle-system.md "Ward visual feedback"). Persistent rule highlights must be applied in the same refresh path so they survive `_refresh_all()` restyles, or drawn as separate border/underlay controls added once at `_ready()`. Use a distinct tint from the cyan spell-targeting highlight (`_targeting_friendly` flow, TID-058/TID-141) and the red attack-target styling to avoid ambiguity.
- Highlights apply to BOTH boards (rules are symmetric), and only for the active biome (Forest or Mountains); other biomes show no slot highlight.

**Day/night indicator + rule text:**
- Keep a small persistent label (e.g. top of SidePanel near the pause button added by `_add_pause_button()`, line 156) showing biome name + sun/moon glyph; full rule sentence lives in the start-of-battle banner. Rule text strings should come from the TID-212 rules table (e.g. `BattlefieldRules.rule_text(biome)`) so UI and logic never drift — same pattern as `_SPELL_EFFECT_LABELS` (line ~145 area, TID-140).
- Biome display names: derive from `game_logic/world/BiomeDef.gd` ids (GRASSLANDS=0 … MOUNTAINS=4); BiomeDef has no name strings — add them to the rules table.
- Neutral/dungeon battles (biome −1 per TID-212): banner says e.g. "Dungeon — no battlefield rule" or is skipped entirely (match TID-212 Plan decision); no slot highlights.

**UI sizing constraints (CLAUDE.md):**
- All sizes relative to viewport: `_vh = get_viewport().get_visible_rect().size.y` is already computed in `_ready()` (line 107) and `_apply_ui_sizes()` exists (line 108). Banner font ~2–2.5% vh; badges 1.8% vh precedent from keyword badges.
- Mobile parity: banner must dismiss on its own (timer) — no keyboard-only dismissal. Desert scorch feedback already comes free from the snapshot/float-label wrapping in `_on_turn_ended` (lines 1176–1181, TID-212).

**Feedback timing:**
- Banner at battle start must not fight the boss banner (`_show_boss_banner()`) or the tutorial overlay (`_show_battle_tutorial()`, line 165) — sequence or stack them deliberately.
- `AudioManager.play_sfx()` no-ops on missing files — an optional banner whoosh is safe to add without an asset.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
