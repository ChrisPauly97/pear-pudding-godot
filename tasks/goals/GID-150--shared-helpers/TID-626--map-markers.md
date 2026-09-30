# TID-626: MapMarkers shared map-marker drawing

**Goal:** GID-150
**Type:** agent
**Status:** done

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Minimap, MapViewOverlay and RealmMapOverlay each drew quest diamonds (with black backing) and the waypoint pin by hand; two had private diamond helpers.

## Plan

See Context.

## Changes Made

New `scenes/ui/MapMarkers.gd` (`diamond`, `draw_diamond`, `draw_outlined_diamond`, `draw_pin`); the three views use it and their private helpers are gone.

## Documentation Updates

CLAUDE.md (helper pointer).
