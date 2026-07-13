# TID-441: Surface Signature Hooks in First Session (Soulbind/Cantrip Teasers)

**Goal:** GID-117
**Type:** agent
**Status:** done (headless import + test run unverified in-sandbox — no Godot binary, download blocked by session proxy)
**Depends On:** TID-440

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Implements the top-ranked fixes from TID-440's audit so a new player encounters at least one
"only this game does that" moment in their first session. The exact scope is set by the
audit's recommendation list — this file pre-scopes the two most likely candidates so work
can start immediately once TID-440 confirms them.

## Research Notes

**Likely candidate A — Soulbinding teaser on first victory:**
After the first battle victory, if no soulbind occurred, add a one-time teaser line/panel to
`scenes/battle/BattleResultUI.gd` (e.g., "Some foes can be soulbound into cards — check the
Bestiary") gated by a SaveManager one-shot flag. Follow the existing one-shot-popup pattern
in `game_logic/TutorialRegistry.gd` (GID-031) rather than inventing a new mechanism — add a
registry entry if that fits better than a result-screen line. Persist the seen-flag via
`SaveManager` with field migration (see `docs/agent/save-system.md`).

**Likely candidate B — Cantrip discovery moment:**
When the deck first qualifies for a cantrip (or on first world entry), surface a popup guide
pointing at the cantrip HUD button. Cantrip availability:
`available_cantrips(template_ids)` (see `docs/agent/card-cantrips.md`); HUD buttons are
registered through the GID-107 action registry (`WorldHUD.register_action`, ZONE_CONTEXT) —
never bare `Button.new()` + `add_child` (guardrail test enforces this in WorldScene).

**Hard constraints (CLAUDE.md):**
- Mobile/desktop parity — any new prompt must be touch-operable; viewport-relative sizing
  (`vh`-based) with re-apply on `NOTIFICATION_RESIZED`.
- Preload, never load; `class_name` via `const X = preload(...)`.
- Run headless import after every `.gd` edit; run `godot --headless --path . -s
  tests/runner.gd` before commit.
- New SaveManager fields need migration defaults so old saves load.
- Don't regress scripted tutorial battles (GID-108) — teasers must not fire mid-scripted
  sequence if the audit shows those flows share the victory UI.

**Out of scope:** rebalancing when soulbind conditions/cantrips actually unlock; new art;
changes to human-owned docs.

## Plan

Implement TID-440's two ranked recommendations via the existing GID-031 popup pipeline
(`GameBus.tutorial_popup_requested` → `SceneManager._on_tutorial_popup_requested`, which
dedupes once-per-save via the `seen_tutorial_<id>` story flag and shows the shared
`TutorialPopup` — mobile/desktop parity is inherited from that scene):

1. `game_logic/TutorialRegistry.gd` — add `"soulbinding"` and `"cantrips"` entries.
2. `scenes/battle/BattleScene.gd` — in the victory path, after the
   `show_soulbind`/`show_victory` chain (~line 2145-2151), emit
   `tutorial_popup_requested("soulbinding")` whenever the enemy has an uncaptured
   signature (i.e., whenever the hunt line or soulbind overlay renders).
3. `scenes/world/WorldHUD.gd` — emit `tutorial_popup_requested("cantrips")` when a cantrip
   button is visible: once from `_create_cantrip_buttons` (fires on first world entry —
   starter deck already qualifies for Skeleton Dig) and once from
   `refresh_action_cluster()` (covers a cantrip unlocking after a deck edit).
4. Validate headless (import check + test runner if a Godot binary is available in-sandbox).

## Changes Made

- `game_logic/TutorialRegistry.gd` — added `"soulbinding"` and `"cantrips"` entries.
- `scenes/battle/BattleScene.gd` — after the victory overlay chain in `_check_game_over`,
  emits `tutorial_popup_requested("soulbinding")` when the enemy has an uncaptured
  signature. Verified scripted battles / puzzles / ghost duels / friendly duels all
  `return` earlier in the function (lines ~2054-2089), so the teaser cannot fire during
  the scripted tutorial battles or any duel mode.
- `scenes/world/WorldHUD.gd` — new `_maybe_teach_cantrips()` emits
  `tutorial_popup_requested("cantrips")` when either cantrip button is visible; called
  from `_create_cantrip_buttons` (initial state) and `refresh_action_cluster` (deck
  edits). Dedupe + display handled by the existing GID-031 pipeline
  (`SceneManager._on_tutorial_popup_requested`, `seen_tutorial_<id>` story flags), which
  already provides mobile/desktop parity via the shared TutorialPopup control.
- `tests/unit/test_hook_teasers.gd` — new suite (auto-discovered by runner):
  registry entries exist with title/body; starter deck unlocks Skeleton Dig but not
  Ghost Phase (teaser reachable on first world entry); `undead_basic` carries a
  signature + capture condition (teaser reachable on first victory).
- **Verification caveat:** no Godot binary in this sandbox and the session proxy blocks
  the GitHub release download, so the headless import check and test run could not be
  executed. Edits were validated by inspection (diff review, quote/indent lint, control
  flow trace). Run `godot --headless --editor --quit` + `tests/runner.gd` on next
  Godot-capable session.

## Documentation Updates

- `docs/agent/soulbinding.md` — Integrations: soulbinding teaser emit + flag.
- `docs/agent/card-cantrips.md` — Integrations: cantrips teaser emit + starter-deck note.
