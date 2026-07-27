# BID-013: CI builds on Godot 4.6 but test instructions install 4.4.1

**Category:** doc-gap
**Discovered During:** GID-064 audit

## Description

`project.godot:20` (features) and `.github/workflows/android-build.yml:32-43` pin Godot
**4.6**, while CLAUDE.md's "Running Tests" section installs **4.4.1** headless, and the
spec (docs/human/specification.md) states "Engine: Godot 4.4.1". Unit tests therefore
run on a different engine version than the shipped APK.

## Evidence

- project.godot:20
- .github/workflows/android-build.yml:32-43
- CLAUDE.md "Running Tests: Installing Godot"
- docs/human/specification.md "Architecture & Technical Constraints"

## Suggested Resolution

Update CLAUDE.md's install snippet to 4.6 (agent-editable). The spec's engine line is
human-owned — prompt the user to update it (or confirm 4.6 is the intended pin and the
spec is stale).
