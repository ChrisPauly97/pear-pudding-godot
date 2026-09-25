# TID-515: Puddles in Low Areas

**Goal:** GID-133
**Type:** agent
**Status:** pending
**Depends On:** TID-514

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Puddles are uniform noise patches, not in dips; no reflection or rain ripples; grass pokes through.

## Research Notes

`terrain.gdshader` wet block (`terrain_wetness` global, fbm puddle mask); flat-ground vertex jitter `VERTEX.y += hash2(xz*0.08)*0.12` gives natural dips; grass shaders can share a puddle-mask include.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
