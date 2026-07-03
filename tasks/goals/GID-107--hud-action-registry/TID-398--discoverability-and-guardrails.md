# TID-398: Discoverability pass, docs/CLAUDE.md rule, and anti-clutter regression test

**Goal:** GID-107
**Type:** agent
**Status:** done
**Depends On:** TID-394, TID-395, TID-396, TID-397

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

GID-107's whole point is that HUD clutter should not silently return with the next feature. TID-394–397 build the mechanism and migrate existing buttons; this task closes the loop: makes the new layout discoverable to players who are used to the old scattered buttons, documents the system so future agents use it, and adds a guardrail so a future task can't bypass the registry the way every task since GID-081 bypassed the HUD declutter.

## Research Notes

- **Tutorial popups:** `scenes/ui/TutorialPopup.gd` + `game_logic/TutorialRegistry.gd`. Adding a new popup is a single entry in `TutorialRegistry.gd`'s `_DATA` dict — no UI code changes needed (see `docs/agent/ui-and-scene-management.md`'s TutorialPopup section). Trigger it via `GameBus.tutorial_popup_requested.emit("party_panel")` (or similar id) the first time co-op becomes active post-migration, following the existing pattern used for `"skill_tree"` in `SceneManager._on_skill_tree_requested` handling.
- **Docs:** `docs/agent/ui-and-scene-management.md` already has a "Menu Hub (GID-081)" section (~line 64) as the direct style precedent — add an equivalent "HUD Action Registry & Party Panel (GID-107)" section documenting: the zone list and their screen positions, the `register_action`/`unregister_action`/`refresh_visibility` API, the Party panel's sections and gating rules (esp. Ghost Duels' host-only gate), the contextual action bar's priority order, and the social strip layout. Pull the final specifics from TID-394–397's "Changes Made" and "Documentation Updates" sections once those land.
- **CLAUDE.md:** the project root `CLAUDE.md` is regularly amended by agents with durable rules and a "Bug Fix Learnings" section (see existing entries like "Mobile / Desktop Feature Parity" and the various GDScript pitfalls) — this is the right place for a new short rule, e.g. under a new "HUD Buttons: Always Use the Action Registry" heading: never call `Button.new()` directly on WorldScene's `_hud` CanvasLayer; always go through `WorldHUD.register_action(...)`. Keep it as terse as the other CLAUDE.md rules (problem / fix / one code example).
- **Regression test:** `tests/runner.gd` is the GUT-based headless test entry point (`godot --headless --path . -s tests/runner.gd`, see CLAUDE.md's "Running Tests" section). Look at the existing `tests/` directory for the project's test-writing conventions before adding a new one. The check should assert that `scenes/world/WorldScene.gd` (and `WorldHUD.gd` outside its own registry implementation) contains no direct `Button.new()` calls that bypass `register_action` — a static source-text scan test (grep-style, similar in spirit to `test_card_registry`'s count assertions) is simpler and more reliable in GDScript/GUT than trying to introspect the live scene tree, but choose whichever approach fits the existing test suite's patterns once you've looked at it.
- **Manual verification:** per the GID-107 acceptance criteria, manually check for overlaps across: single-player, co-op idle, co-op with a nearby player in challenge range, co-op during an active PvP duel (as spectator), co-op during dungeon crawl, and Android touch layout (via the existing mobile-parity checklist in CLAUDE.md).

## Plan

1. **Tutorial popup:** add a `"party_panel"` entry to `TutorialRegistry._DATA`; emit
   `GameBus.tutorial_popup_requested.emit("party_panel")` from `WorldScene._setup_coop()`
   right where the "party" HUD action is registered — mirrors the `"night_hunts"`
   precedent (emitter just emits every time; `SceneManager._on_tutorial_popup_requested`
   owns the `seen_tutorial_party_panel` dedup flag, so this is safe to call unconditionally).
2. **Docs:** add the "HUD Action Registry & Party Panel (GID-107)" section to
   `docs/agent/ui-and-scene-management.md` (between "Menu Hub" and "How It Works"),
   pulling zone positions/API/gating specifics from TID-394–397's Changes Made notes.
3. **CLAUDE.md:** add "HUD Buttons: Always Use the Action Registry" (problem / fix /
   code example, same terse shape as the other rules) after "UI Sizing."
4. **Regression test:** `tests/unit/test_hud_registry_guardrail.gd` — static
   source-text scan (FileAccess + RegEx, no live scene instantiation, matching
   `test_card_registry.gd`'s precedent). Cross-references two extracted sets from
   `WorldScene.gd`'s text: (a) every `var _foo: Button` declaration, (b) every
   `_hud.add_child(_foo)` call — flags any Button-typed identifier added directly to
   `_hud` that isn't in a reviewed allow-list. Manually verified in Python
   (`re` mirrors Godot's `RegEx` closely enough for this pattern) that it currently
   finds **zero** offenders against the post-TID-397 codebase.
5. **Found while writing the test:** Siege and Tournament buttons (both pre-dating
   GID-107's scope, like Auction/BID-042) are centered at the *same* y-coordinate
   (`vp.y*0.63`) and visually overlap in a reachable state (host, siege-supported
   map, no active siege/tournament). Logged as BID-043 alongside Draft Duel (same
   "not yet migrated" category); all three added to the guardrail test's allow-list
   as reviewed, pre-existing exceptions.
6. **Manual verification:** could not run the Godot editor in this environment (see
   Changes Made) — substituted careful code tracing instead of the visual checklist
   from Research Notes; flagged as an open item for the user/CI to confirm.

## Changes Made

- `game_logic/TutorialRegistry.gd`: added `"party_panel"` entry.
- `scenes/world/WorldScene.gd`: `_setup_coop()` now emits
  `GameBus.tutorial_popup_requested.emit("party_panel")` alongside registering the
  "party" HUD action.
- `docs/agent/ui-and-scene-management.md`: added "HUD Action Registry & Party Panel
  (GID-107)" section (zones table, API, Party panel section/gating table, contextual
  bar priority rule, social strip layout, regression-test description).
- `CLAUDE.md`: added "HUD Buttons: Always Use the Action Registry" rule after "UI
  Sizing: Relative to Viewport, Never Fixed Pixels."
- Added `tests/unit/test_hud_registry_guardrail.gd` (auto-discovered by
  `tests/runner.gd`'s `test_*.gd` glob — no registration needed).
- Logged `BID-043` (Siege/Draft Duel/Tournament buttons not migrated; Siege visually
  overlaps Tournament — a real, previously-undetected collision found while building
  the guardrail's allow-list).

**Acceptance criteria status** (from `goal.md`):
- [x] `WorldHUD.gd` exposes the zone/action-registry API; no *migrated* feature
      computes its own raw `Vector2` HUD button position outside it. (Siege/Draft
      Duel/Tournament/Auction remain unmigrated — logged as BID-042/BID-043, matches
      the goal's own acknowledgment that some post-authoring buttons might be out of
      scope; the guardrail test prevents the *unreviewed* case from growing further.)
- [x] Roster/Stash/Leaderboard/Ghost Duels/Team Duel/Dungeon Crawl/Loot-mode reachable
      from the single Party entry point (TID-395).
- [x] Challenge/Ranked, Trade, Spectate, USE/Interact share one contextual bar with an
      explicit priority order and no structural overlap (TID-396).
- [x] Chat/Emote/Ping reachable from one compact social cluster (TID-397).
- [ ] "No two HUD elements overlap in any reachable combination" — **not manually
      verified** across single-player/co-op/dungeon-crawl/PvP-pending/Android states;
      Godot could not be run in this environment (network policy blocks the release
      download — see TID-394's Changes Made). Verified by code-tracing instead: every
      *migrated* button lives in an auto-stacking zone Container (overlap-proof by
      construction), and the one still-open gap (Siege vs. Tournament) is
      characterized and logged as BID-043 rather than silently left unverified.
- [x] Mobile tap parity retained — no handler logic changed, only placement; Android's
      USE button and every migrated trigger button remain real `Button` nodes.
- [x] `docs/agent/ui-and-scene-management.md` documents the system (this task).
- [x] Regression test added (this task) — not run against a live Godot build; verified
      its regex logic in Python against the actual file content instead.
- [ ] "All tests pass headless" — **could not run** `godot --headless --path . -s
      tests/runner.gd` in this environment. This is the standing verification gap for
      the whole goal; flagged prominently for the user / next CI run.

## Documentation Updates

Both `docs/agent/ui-and-scene-management.md` and `CLAUDE.md` were updated directly by
this task (see Changes Made above) — this is the consolidated documentation pass for
the whole GID-107 goal.
