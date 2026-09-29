# BID-067: Main menu has no key art

**Category:** design-inconsistency
**Discovered During:** GID-141 / TID-593

## Description

The main menu is buttons on a flat dark background — the first screen a player sees has none of the world's look.

## Evidence

TID-593 capture `01_menu`; `scenes/ui/MenuScene.gd`.

## Suggested Resolution

Render a slowly panning live world (or the battle backdrop) behind the menu, or add a key-art image.
