# TID-134: Inline Ability Text on Card Panels

**Goal:** GID-035
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Card panels in hand and on-board show only flavor description text (e.g. "A wispy spirit.", "The smallest flame is still a flame."). Spell effect information only appears in the CardInspectOverlay (right-click modal). Players cannot tell what a card does during normal play. This task adds ability text directly on the card face.

## Research Notes

**Files to change:**
- `scenes/battle/BattleScene.gd` — `_build_card_vbox()` (line ~756) builds the VBox shown on every card panel. Currently adds: NameLabel, StatsLabel, DescLabel, KeywordRow, optional StatusRow.
- `scenes/battle/BattleScene.gd` — `_update_card_view()` (line ~722) refreshes existing vbox; updates DescLabel.text and KeywordRow.

**Ability text source:**
- `_SPELL_EFFECT_LABELS` dict in `CardInspectOverlay.gd` maps `spell_effect` → human-readable string with `[power]` placeholder. This same dict (or a shared version) should drive the inline text.
- For Emergence (added in TID-136): `emergence_effect` and `emergence_power` fields on CardData/CardInstance will have a parallel `_EMERGENCE_LABELS` dict.

**Display strategy:**
- **Spell cards**: replace the DescLabel text with the spell effect label (e.g. "Deal 3 damage to a target"). The flavor description is redundant with the effect label at this scale. Font ~1.1% vh, auto-wrap, green tint `Color(0.6, 1.0, 0.8)` to match CardInspectOverlay.
- **Minion cards with keywords**: keep existing keyword badges (KeywordRow) — no change needed.
- **Minion cards with Emergence** (TID-136 adds this): add a small "Emergence: <text>" label above or below KeywordRow. Font ~1.0% vh, amber tint `Color(1.0, 0.85, 0.4)`.
- **Plain minions**: keep showing description as-is (Ghost "A wispy spirit." etc.).

**Label constants:** Define `_SPELL_EFFECT_LABELS` and `_EMERGENCE_LABELS` as module-level constants in `BattleScene.gd` (not duplicated from CardInspectOverlay — CardInspectOverlay can reference BattleScene's version or keep its own; they're small enough to maintain in sync). Simplest path: define in BattleScene.gd and duplicate in CardInspectOverlay.gd — document in both files.

**Card size:** Card panels are `_vh * 0.09 × _vh * 0.15` (9% × 15% viewport height). At 1080p that's ~97 × 162 px. Ability text at 1.1% vh (~12 px) with autowrap fits 2-3 lines. Keep it short.

**`_update_card_view()` refresh:** This function already updates `DescLabel` — extend it to also update/create the ability text label if present.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
