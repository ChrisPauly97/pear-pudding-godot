# TID-520: Soft Hill Edges

**Goal:** GID-134
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Hill sides show a hard brown dirt ring.

## Research Notes

`terrain.gdshader` zone blend `t_side` / `t_top` from `v_blend`.

## Plan

Dirt only on steep upper slopes with a noisy edge; darken the hill foot.

## Changes Made

terrain.gdshader t_side gated by slope + noise; hill-foot darkening. Also TownspersonNPC unnamed extras get a hashed role instead of 'NPC'.

## Documentation Updates

visual-polish.md (at goal end).
