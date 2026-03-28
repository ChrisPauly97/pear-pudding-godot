# GID-005: Android Export Hardening

## Objective

Ensure every resource file has a companion `.uid` sidecar and that the GitHub Actions CI workflow successfully runs the headless editor scan and produces a valid APK.

## Context

CLAUDE.md explicitly calls out missing `.uid` sidecars as a known Android export failure mode: `load("res://path/file.gdshader")` can return `null` for untracked files. The project already has `.github/workflows/android-build.yml` but it has never been verified against the current set of resource files. Any `.gdshader`, `.tres`, or `.material` created by the agent (outside the Godot editor) may be missing its sidecar.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-012 | Audit all `.gdshader` / `.tres` / `.material` files for missing `.uid` sidecars | agent | pending | — |
| TID-013 | Validate and fix the CI workflow for headless export | agent | pending | TID-012 |

## Acceptance Criteria

- [ ] Every `.gdshader`, `.tres`, and `.material` file in the repo has a matching `.uid` sidecar
- [ ] Each `.uid` file contains a valid `uid://` string (12 lowercase alphanumeric chars)
- [ ] No two resource files share the same UID
- [ ] CI workflow runs `godot --headless --editor --quit` before export
- [ ] CI workflow produces an APK artifact without errors
- [ ] `BundledMaps` includes all story map names (verified as part of door audit)
