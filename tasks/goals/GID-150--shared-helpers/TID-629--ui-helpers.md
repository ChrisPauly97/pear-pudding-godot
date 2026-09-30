# TID-629: UI grids, panels and small dups

**Goal:** GID-150
**Type:** agent
**Status:** done

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

GridContainer + columns + two separations + add_child written out 11 times; RunSummaryScene built the same stat grid 3×; CoopSocial built the emote and quick-chat HUD panels identically; both pause menus hand-centred a panel; PackOpenScene copied UiUtil.rarity_color; CoopPvP sent the challenge decline RPC in two places.

## Plan

See Context.

## Changes Made

`UiUtil.make_grid` (CharacterScene, MailboxScene, PartyPanel, RunSummaryScene, SkillBarScene, SkillTreeScene, CoopSocial). `RunSummaryScene._build_stat_grid`. `CoopSocial._build_hud_button_grid`. Pause menus use `make_centered_panel`. PackOpenScene uses `UiUtil.rarity_color`. `CoopPvP._send_pvp_decline`.

## Documentation Updates

CLAUDE.md (helper pointers).
