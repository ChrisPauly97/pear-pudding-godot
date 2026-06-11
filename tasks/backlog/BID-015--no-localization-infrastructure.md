# BID-015: No localization / translation infrastructure

**Category:** spec-gap
**Discovered During:** GID-070 research

## Description

The game has no i18n support: no translation files (.po/.csv), no `tr()` calls — every UI string is hardcoded in GDScript (menus, battle UI, dialogue, tutorials, settings). If the game ships beyond English, retrofitting localization across 50+ scenes and the story dialogue will be expensive; the cost grows with every new feature that adds strings.

## Evidence

- Grep across the codebase finds zero `tr(` usages and no `.po`/`.csv` translation resources.
- `project.godot` has no `[internationalization]` configuration.
- docs/human/specification.md does not mention localization in Goals or Out of Scope — it is an unstated decision.

## Suggested Resolution

Human decision needed: is English-only acceptable for v1? If yes, add "Localization" to the spec's Out of Scope list to make it explicit. If other languages are planned, schedule a goal early (before more text-heavy story content lands) to wrap user-facing strings in `tr()` and set up CSV translations — doing it later only gets more expensive.
