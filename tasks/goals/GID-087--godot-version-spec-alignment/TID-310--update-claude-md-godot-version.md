# TID-310: Update CLAUDE.md Godot install snippet to 4.6

**Goal:** GID-087
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

CLAUDE.md "Running Tests: Installing Godot" section installs `Godot_v4.4.1-stable_linux.x86_64` but `.github/workflows/android-build.yml` and `project.godot` use Godot 4.6. Tests therefore run on a different engine than the shipped APK.

The CI workflow URL and version string need to be checked against the actual CI YAML to get the correct 4.6 release tag.

## Plan

## Changes Made

## Documentation Updates
