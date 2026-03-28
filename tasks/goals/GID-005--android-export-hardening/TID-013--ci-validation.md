# TID-013: Validate and Fix the CI Workflow for Headless Export

**Goal:** GID-005
**Type:** agent
**Status:** pending
**Depends On:** TID-012

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The CI workflow `.github/workflows/android-build.yml` exists but has never been verified end-to-end with the current codebase. This task reads it, identifies any gaps (missing steps, wrong Godot version, unsigned APK handling), and fixes them.

## Research Notes

**CI file:** `.github/workflows/android-build.yml`
- Read the full file during the task — do not assume its contents from the CLAUDE.md reference.
- CLAUDE.md mentions "line 163" contains `godot --headless --editor --quit`. Verify this step exists and comes **before** the export step.

**Key things to verify / fix:**
1. **Godot version** — workflow should use `4.4.1-stable` (matching the project's engine version from spec). If it uses a different version, update it.
2. **Headless editor scan** — `godot --headless --editor --quit` must run before export to fill in any missing UIDs and complete the import cache.
3. **Export preset** — `export_presets.cfg` must exist and have an Android preset. Check if it exists; if not, note it as a human-action (the preset must be set up in the editor with keystore config).
4. **Keystore / signing** — Android release builds require a keystore. CI typically uses a GitHub secret for the keystore. Check if secrets are referenced; if not, note that debug signing should be used for CI APKs.
5. **APK artifact upload** — the workflow should upload the APK as a GitHub Actions artifact so it can be downloaded and tested.
6. **GDScript parse errors** — the headless scan will surface any parse errors in the codebase. Fix any that appear.

**`export_presets.cfg`:** Check if it exists at the repo root. If missing, create a minimal one for debug Android export (no keystore required). Read an example format from Godot docs if needed.

**Note:** If the full CI run requires human setup (e.g. Android SDK, keystore secrets in GitHub repo settings), document what the human needs to do as a `human-action` sub-note in Changes Made rather than blocking the task.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
