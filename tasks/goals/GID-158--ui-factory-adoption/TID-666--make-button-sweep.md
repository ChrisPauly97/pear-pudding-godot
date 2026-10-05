# TID-666: make_button Sweep

**Goal:** GID-158
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal. `UiUtil.make_button(text, size, font_size, on_pressed, parent)`.

## Research Notes

Sites that are a clean fit were converted. Left as is (bespoke, the factory would not shorten them): full-rect
flat tap catchers (`PackOpenScene`, `Minimap`, `CardTile`), swatch buttons with stylebox overrides
(`MultiplayerLobbyScene`, `InventoryScene`, `MailboxScene`), `WorldHUD` action registry, `UiUtil` itself, debug
tools (`AutomationBridge`, `MapEditorScene`), tiered `JournalScene` rows, `PartyPanel` friend icon,
`BattleNet` team panel, `SkillTreeScene` "X" header button.

## Plan

Convert each clean site; keep per-site extras (alignment, disabled, modulate) after the factory call.

## Changes Made

`make_button` now builds: `BattleTargeting` cancel button, `BlacksmithScene` upgrade + salvage, `ChapterEndingOverlay`
next, `CharacterScene` slot + companion buttons, `MapViewOverlay` rally buttons (lambda → `bind`), `MenuScene._add_btn`,
`SkillTreeScene` unlock button.

## Documentation Updates

None — CLAUDE.md already documents the factory.
