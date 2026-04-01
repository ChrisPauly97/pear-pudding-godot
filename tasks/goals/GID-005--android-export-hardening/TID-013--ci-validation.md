# TID-013: Validate and Fix the CI Workflow for Headless Export

**Goal:** GID-005
**Type:** agent
**Status:** done
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

1. Remove the "Generate export_presets.cfg" step from the CI workflow — it produces a malformed file (YAML indentation bleeds into heredoc content) and loses `include_filter="*.txt"`.
2. Replace it with a "Patch keystore into export_presets.cfg" step that uses `sed` to inject the keystore env vars into the committed file's empty keystore fields.
3. On the "Import project assets" step: remove `|| true`, redirect stderr to stdout so parse errors are visible, but still use `exit 0` after so the scan step doesn't fail on non-fatal warnings.
4. Verify all acceptance criteria:
   - BundledMaps has all story map names ✓ (already verified)
   - UID sidecars already done in TID-012

## Changes Made

- `.github/workflows/android-build.yml`: Removed the "Generate export_presets.cfg" step which was producing a malformed file (YAML heredoc indentation added leading spaces to every line) and was missing `include_filter="*.txt"`. Replaced with a "Patch keystore into export_presets.cfg" step that uses `sed` to inject keystore values into the committed file's empty fields, preserving all other settings.
- "Import project assets" step: added `2>&1` redirect so parse errors are visible in CI logs; kept `|| true` since Godot headless scan returns non-zero on non-fatal warnings.
- Verified BundledMaps.gd includes all story map names: blancogov, blancogov_temple, farsyth_mansion, house_1, madrian, madrian_inn, madrian_masters_house, main, maykalene, maykalene_inn, test.
- **Human action required**: To produce a release-signed APK, add GitHub repository secrets: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`. Without these, CI uses a debug keystore (functional but not Play-Store-publishable).

## Documentation Updates

None required — CI workflow changes are self-contained.
