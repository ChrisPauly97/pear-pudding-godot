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

**Decision (June 2026):** English-only for v1. Localization is out of scope for now. No action required until a future goal explicitly targets internationalization. The spec's Out of Scope section should note this when TID-311 (GID-087) is completed by the human owner.
