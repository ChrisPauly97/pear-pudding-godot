# TID-310: Update CLAUDE.md Godot install snippet to 4.6

**Goal:** GID-087
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

CLAUDE.md "Running Tests: Installing Godot" section installs `Godot_v4.4.1-stable_linux.x86_64` but `.github/workflows/android-build.yml` and `project.godot` use Godot 4.6. Tests therefore run on a different engine than the shipped APK.

The CI workflow URL and version string need to be checked against the actual CI YAML to get the correct 4.6 release tag.

## Plan

Replace the two `4.4.1-stable` version strings in CLAUDE.md's "Installing Godot headless" bash snippet with `4.6-stable` to match the CI workflow and `project.godot`.

## Changes Made

- `CLAUDE.md`: Updated wget URL and cp path in "Running Tests: Installing Godot" from `Godot_v4.4.1-stable_linux.x86_64` to `Godot_v4.6-stable_linux.x86_64`.

## Documentation Updates

None — CLAUDE.md is the doc.
