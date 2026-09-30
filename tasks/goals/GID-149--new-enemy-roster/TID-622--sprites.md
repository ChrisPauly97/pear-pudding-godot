# TID-622: Generated Sprites

**Goal:** GID-149
**Type:** agent
**Status:** done

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Templates in scripts/gen_creature_sprites.py for wolf, bog hag, scout, scarab queen + scarab, ember cultist, frost wendigo, barrow king; Riftborn Echo tints the PaperDoll hero; SpriteRegistry textures/heights; pack_member_texture for wolf and scarab; card illustrations for the three new minions.

## Plan

See Context.

## Changes Made

10 templates in scripts/gen_creature_sprites.py → enemy_*.png (+ .import); SpriteRegistry textures, heights (HEIGHT_BEAST, HEIGHT_WENDIGO), pack_member_texture wolf/scarab. Echo is a violet ASCII figure rather than a tinted PaperDoll.

## Documentation Updates

docs/agent/enemies-and-npcs.md (GID-149 section).
