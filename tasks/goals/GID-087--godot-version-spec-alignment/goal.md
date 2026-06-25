# GID-087: Godot Version & Spec Alignment

## Objective

Align CLAUDE.md's Godot install instructions with the actual CI engine version (4.6), and update the specification and narration audio scope to reflect current reality.

## Context

`project.godot` and `.github/workflows/android-build.yml` pin Godot **4.6**, but CLAUDE.md's "Running Tests" section installs **4.4.1** headless, and the spec states "Engine: Godot 4.4.1". Unit tests therefore run on a different engine than the shipped APK. (BID-013)

Separately, `docs/human/specification.md` lists "Voice acting or music" under Out of Scope but GID-013 added lore scroll narration audio — long-form spoken-word clips that play during exploration. The spec needs updating to clarify the distinction. (BID-002)

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-310 | Update CLAUDE.md Godot install snippet to 4.6 | agent | done | — |
| TID-311 | Human: update specification.md engine version and narration audio scope | human-action | pending | — |

## Acceptance Criteria

- [ ] CLAUDE.md "Running Tests" section installs Godot 4.6 headless
- [ ] `docs/human/specification.md` engine line updated to 4.6
- [ ] Spec Out of Scope section clarifies that voiced character dialogue remains out of scope; lore scroll narration audio is in scope
- [ ] Local headless test run uses same engine version as CI
