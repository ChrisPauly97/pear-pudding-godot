# TID-570: Region Awareness Replaces Map-Name Checks

**Goal:** GID-138
**Type:** agent
**Status:** pending
**Depends On:** TID-569

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Code keyed on `map_name == "maykalene"` etc. must use the town the player is in.

## Research Notes

Files with stitched-town literals: ObjectiveTracker, PlaceNames, MapRegistry,
NamedMapProps, SiegeDefs, SceneManager, WorldScene, SessionState, TownSiege, StoryCast,
CoopActivities, MultiplayerLobbyScene, NetBattles, BattleVictory, NetworkManager.

## Plan

## Changes Made

## Documentation Updates
