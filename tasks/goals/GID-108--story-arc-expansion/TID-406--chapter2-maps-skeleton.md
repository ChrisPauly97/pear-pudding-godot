# TID-406: Chapter 2 Named Maps Skeleton — larik, marsax_hold, War-Camp Dungeon Entry

**Goal:** GID-108
**Type:** agent
**Status:** pending
**Depends On:** TID-400

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Chapter 2 ("The Road to Larik", docs/human/story.md) needs two new small named maps — larik (Saimtar's home village) and marsax_hold (Lord Marsax's besieged hold) — plus a door/entry for the Martarquas war-camp dungeon (a procedural dungeon reskin). This task builds the map skeletons with SPAWN/NPC/DOOR/SCROLL entities so TID-407 can wire beats onto them.

## Research Notes

- **Story specs:** docs/human/story.md Chapter 2 section — beat 2 (Return to Larik: cold frightened villagers, Saimtar's empty house, hidden letter scroll), beat 4 (Marsax hold under siege), beat 6 (war-camp dungeon with boss). Keep maps small (Larik is "a collection of houses with aspirations of township" per the intro).
- **Map creation workflow (CLAUDE.md "Map Storage"):** maps are .tres resources in assets/maps/. Steps: (1) create assets/maps/larik.tres and assets/maps/marsax_hold.tres (+ .uid sidecars, 12-char lowercase uid://); (2) add `const _LARIK := preload("res://assets/maps/larik.tres")` etc. to autoloads/MapRegistry.gd; (3) add entries to the `_BUNDLED` dictionary. Study an existing small map .tres (e.g. farsyth_mansion.tres) for the exact resource format — tile grid string + entity lines.
- **Map format:** docs/agent/named-maps-and-dungeons.md — tile chars 0=grass, 1=wall, 2=hill; entities SPAWN x z / NPC x z text / ENEMY x z [type] / CHEST x z cards / DOOR x z target_map [door_id] / SCROLL directives (see ScrollRegistry usage in existing maps).
- **Connectivity:** Chapter 2 route is west from Blancogov: larik reachable from the open world (same DOOR-from-overworld mechanism as madrian/maykalene — check how existing towns are entered: SceneManager.enter_map / waystone placement in docs/agent/waystone-fast-travel.md), marsax_hold beyond it; war-camp dungeon door placed in the open world or off marsax_hold (decide in Plan; procedural dungeons enter via DOOR with dungeon target — see docs/agent/named-maps-and-dungeons.md DungeonGen section).
- **NPC dialogue:** placeholder static lines from story.md Chapter 2 NPC table (villagers afraid, hold garrison); flag-gated variants belong to TID-407.
- **Scrolls:** larik hidden-letter scroll + marsax traitor's-seal scroll — register in autoloads/ScrollRegistry.gd (preload consts) with narration text from story.md; needs .uid sidecars.
- Headless import validation after MapRegistry edits (CLAUDE.md); tests: extend the map-loading test (tests/ has named-map tests — verify larik/marsax_hold parse and expose SPAWN).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
