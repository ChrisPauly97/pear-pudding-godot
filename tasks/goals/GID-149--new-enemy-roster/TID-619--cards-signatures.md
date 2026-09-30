# TID-619: Cards, Signatures & Capture Conditions

**Goal:** GID-149
**Type:** agent
**Status:** done

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

New minion cards wolf, treant, scarab (collectible, neutral); eight sig_* signature cards; CaptureTracker conditions no_ally_lost and hero_hp_at_least; CardRegistry preloads + uid sidecars; test_card_registry count.

## Plan

See Context.

## Changes Made

Cards wolf/treant/scarab + 8 sig_* signatures (.tres + .uid), CardRegistry preloads, count 128; CaptureTracker no_ally_lost / hero_hp_at_least, condition text moved to a CONDITION_TEXT table (gdlint max-returns).

## Documentation Updates

docs/agent/enemies-and-npcs.md (GID-149 section).
