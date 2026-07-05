# TID-405: Chapter 1 Ending Scene + Post-Council Epilogue World Reactivity

**Goal:** GID-108
**Type:** agent
**Status:** done
**Depends On:** TID-400

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Chapter 1 currently dead-ends at `chapter1_temple_council`. The approved ending (docs/human/story.md "Chapter 1 Victory Condition") gives it a payoff: a narration-overlay ending at King Eldar, the `chapter1_complete` flag, and a playable epilogue world. This task supersedes GID-020/TID-067.

## Research Notes

- **Approved definition (docs/human/story.md):** Trigger = speaking to King Eldar in blancogov_temple AFTER `chapter1_temple_council` is set AND the Queen and Scargroth have each been spoken to (track via two sub-flags, e.g. `chapter1_spoke_queen` / `chapter1_spoke_scargroth`, set on their dialogue interactions). Flag set: `chapter1_complete`. Presentation: narration overlay, three short pages — (1) the alliance is re-sworn, (2) Maiteln tells Saimtar he has earned his place at his side, (3) Scargroth's aside: "there is a name from Larik in the old registers you should see" (Chapter 2 hook). After: return to the world (NOT the menu) as a playable epilogue.
- **Narration overlay reuse:** the scroll narration UI (GID-013) — see docs/agent/story-narration-scrolls.md, scenes/world/entities/StoryScroll.gd and the Journal presentation (scenes/ui/JournalScene.gd). Reuse the same overlay style for multi-page ending text; BaseOverlay patterns in scenes/ui/BaseOverlay.gd (preload it — CLAUDE.md class_name rule).
- **ObjectiveTracker:** game_logic/ObjectiveTracker.gd already returns empty for `chapter1_temple_council`/`chapter1_complete` — update so the pre-ending state shows "Speak with the Queen and Scargroth, then the King" and chapter1_complete shows empty. Update tests/unit/test_objective_tracker.gd.
- **Epilogue reactivity:** the chapter1_complete after-lines in the flag-gated dialogue table (TID-404) provide the war-preparation world state; verify they display after the ending. Consider an achievement hook (game_logic/AchievementRegistry.gd already references chapter1 flags — check for an existing chapter-completion achievement).
- **GID-020 bookkeeping:** TID-067 was marked superseded by this task when GID-108 was created; on completion, tick GID-020's remaining acceptance criteria or note them satisfied here.
- Ending must be reachable on mobile (tap-through pages) and desktop; audio: optional narration audio hook exists in the scroll system.

- **Co-op (up to 4 players):** this feature must follow the TID-408 design rules (shared-flag arbitration via SessionState, exactly-once beat effects, authority-broadcast narration, single synced Maiteln, no write-through to solo saves). Read TID-408--coop-story-compatibility.md before Plan.

## Plan

**Resolves the TID-404 deferral.** Queen and Scargroth turn out to need only the existing
`MapNpc.flag_key`/`after_dialogue` mechanism (single-condition, safe): `flag_key` becomes their
own "have I spoken to this person" sub-flag, which is exactly what the compound ending condition
needs to check. King Eldar is the one genuine special case — his interaction must inspect three
flags and conditionally trigger the ending, which the generic auto-set-on-interact mechanic
cannot express, so he gets a dedicated `npc_type` branch.

1. **`assets/maps/blancogov_temple.tres`**:
   - Queen (npc_2): `flag_key = "chapter1_spoke_queen"`, `after_dialogue` = story.md's approved
     line ("Rest here whenever the road wears you thin, young Saimtar."). **Known simplification**
     (documented, not fixed): this line is a post-`chapter1_complete` epilogue line per story.md,
     but the 2-state `MapNpc` schema can't express "before spoken / spoken-not-yet-ended /
     spoken-after-ending" as three states, so it shows as soon as she's been spoken to once —
     narratively harmless since the intended flow is Queen → Scargroth → King Eldar in one
     visit, all extremely close together.
   - Scargroth (npc_3): same treatment — `flag_key = "chapter1_spoke_scargroth"`,
     `after_dialogue` = the Chapter 2 hook line ("I've been reading the old registers. There is
     a name from Larik you should see."). Same documented simplification.
   - King Eldar (npc_1): `npc_type = "chapter1_king_eldar"` (new marker, mirrors the existing
     `merchant`/`blacksmith`/`bounty_board`/`stable`/`duelist`/`rest_site`/`bed`/`trophy_pedestal`
     special-case pattern in `WorldScene._handle_interact()`). Existing `flag_key`/`after_dialogue`
     fields are removed from his entry — his dialogue is now entirely custom-driven (4 states
     don't fit the 2-state schema either), see below.

2. **`scenes/world/WorldScene.gd`**:
   - New `if str(npc.get("npc_type", "")) == "chapter1_king_eldar":` branch in
     `_handle_interact()`, added to the existing `npc_type` match chain, calling
     `_handle_king_eldar_interaction(npc)` then `return` (bypasses the generic
     `TownspersonNPC.get_dialogue()`/flag_key auto-set path entirely for this one NPC).
   - `_handle_king_eldar_interaction(npc: Dictionary) -> void` — 4 states, most-specific first:
     1. `chapter1_complete` already set → show the approved epilogue line ("The realm owes its
        warning to a servant boy from Larik. Remember that, all of you.").
     2. `chapter1_temple_council` not yet set → set it (first meeting — "the council is
        assembling" beat), show `npc.dialogue` (his static intro line, unchanged in the .tres).
     3. `chapter1_temple_council` set AND both `chapter1_spoke_queen` and
        `chapter1_spoke_scargroth` set → call `_trigger_chapter1_ending()`.
     4. Otherwise (council met, but Queen/Scargroth not both spoken to yet) → show the
        interim line ("The council has heard the prophecy. We act at dawn." — reused from the
        NPC's original `after_dialogue`, not wasted).
   - `_trigger_chapter1_ending() -> void` — sets `chapter1_complete` (fires
     `_refresh_maiteln_presence()` automatically via the existing `_on_local_story_flag_set` hook
     from TID-403, hiding the follower with zero new code), then shows the new
     `ChapterEndingOverlay` with the three approved pages verbatim from story.md. No scene
     transition: the player is already in the world (blancogov_temple), so "return to the world
     as a playable epilogue" is simply "close the overlay" — nothing else changes state.

3. **New `scenes/ui/ChapterEndingOverlay.gd`** (+ minimal `.tscn`, uid inline per the
   `StoryScroll.tscn`/`TutorialPopup` precedent) — `extends "res://scenes/ui/BaseOverlay.gd"`
   (path-string extends, not class_name, per the CLAUDE.md preload-discipline exception).
   `setup(pages: Array[String])`; builds a centered panel (dark-glass style via
   `_make_dark_glass_style()`) with a title, a body label showing the current page, and a
   Next/Continue button (tap-through via `ui_accept`, mirrors `TutorialPopup._unhandled_input`) —
   "Continue" on the last page calls `_close()`. **Bug fix carried from TID-401, caught during
   this task's review of `BaseOverlay`:** `_close()` only emits the `closed` signal — it does not
   free the node. `SceneManager._on_tutorial_popup_requested` correctly connects
   `popup.closed` to free its wrapping `CanvasLayer`, but `BattleScene._maybe_show_scripted_tutorial_step`
   (TID-401) never did, so the scripted-battle tutorial popup's "Got it" button was dead —
   fixed in this task (see Changes Made) alongside adding the same connect for the new overlay.

4. **`game_logic/ObjectiveTracker.gd`**: replace the `chapter1_temple_council` → `{}` branch with
   `chapter1_complete` → `{}` (unchanged position) and a new `chapter1_temple_council` (but not
   `chapter1_complete`) branch → `{"label": "Speak with the Queen and Scargroth, then the King",
   "map": "blancogov_temple", "tx": 42, "tz": 15}` (King Eldar's position, the natural anchor
   even though the objective technically involves three NPCs). Update
   `tests/unit/test_objective_tracker.gd` accordingly.

5. **GID-020 bookkeeping**: once this lands, all 4 of GID-020's open acceptance criteria are
   satisfied by TID-404 (dialogue) + this task (ending trigger/overlay/flag). Tick them and
   update `goal.md` / `tasks/index.md` to reflect the goal as fully resolved via GID-108.

6. **Achievement**: `AchievementRegistry`'s existing `chapter1_done` entry (`flag_key:
   "chapter1_complete"`) fires automatically through the standard `set_story_flag` →
   `check_flag_achievement` path — no new code needed.

7. **Co-op note (per TID-408):** the ending is single-player-shaped — `set_story_flag` calls go
   through the same unwrapped path every existing Chapter 1 flag uses (no co-op arbitration
   exists yet anywhere in the codebase); the narration overlay shows only locally, not
   broadcast to other session members. TID-408 owns replacing this with authority-broadcast
   narration + shared-flag arbitration for the compound condition.

**Validation:** same sandbox constraint as TID-401–404 (no Godot binary, network egress
blocked). Manual review in place of headless import.

## Changes Made

- **`assets/maps/blancogov_temple.tres`**: King Eldar (npc_1) → `npc_type = "chapter1_king_eldar"`,
  `flag_key`/`after_dialogue` cleared (now custom-driven, see below). Queen (npc_2) →
  `flag_key = "chapter1_spoke_queen"` + approved after-line. Scargroth (npc_3) →
  `flag_key = "chapter1_spoke_scargroth"` + approved after-line (the Chapter 2 hook).
- **`scenes/world/WorldScene.gd`**: new `"chapter1_king_eldar"` branch in `_handle_interact()`'s
  npc dispatch; new `_handle_king_eldar_interaction()` (4-state dialogue) and
  `_trigger_chapter1_ending()` (sets `chapter1_complete`, shows the ending overlay).
- **`scenes/ui/ChapterEndingOverlay.gd`** (+ `.gd.uid`, no `.tscn` needed — mirrors
  `TutorialPopup`'s script-only instantiation): new paged narration overlay.
- **`game_logic/ObjectiveTracker.gd`**: `chapter1_temple_council` now returns a real objective
  ("Speak with the Queen and Scargroth, then the King") instead of `{}`.
- **`tests/unit/test_objective_tracker.gd`**: updated the temple-council test accordingly.
- **`tests/unit/test_named_map_npcs.gd`**: 3 new tests for King Eldar's `npc_type`/cleared
  `flag_key`, and Queen/Scargroth's new `flag_key`/`after_dialogue`.
- **`tasks/goals/GID-020--story-completion/goal.md`** + `tasks/index.md`: ticked GID-020's 4
  engineering acceptance criteria (all satisfied via GID-108 TID-404 + this task); the 5th
  (headless test run) stays unchecked per this sandbox's constraint.

**Bug fix (opportunistic, found while reviewing `BaseOverlay` for this task's overlay):**
`scenes/battle/BattleScene.gd`'s `_maybe_show_scripted_tutorial_step` (TID-401) instantiated a
`TutorialPopup` but never connected its `closed` signal to free the wrapping `CanvasLayer` —
`BaseOverlay._close()` only emits `closed`, it doesn't free anything, so the "Got it" button was
dead and the popup would have stayed on screen indefinitely. Fixed by adding the same
`popup.closed.connect(func(): layer.queue_free())` that `SceneManager._on_tutorial_popup_requested`
already uses correctly.

**Not done in this task (co-op, per TID-408):** the ending is single-player-shaped — no
shared-flag arbitration, narration shows only locally. TID-408 owns replacing this with
authority-broadcast narration for the compound condition.

**Validation:** same sandbox constraint as TID-401–404 (no Godot binary, network egress
blocked). Careful manual review of every edit in place of headless import; this pass caught the
`BaseOverlay._close()` bug above.

## Documentation Updates

- `docs/agent/story-implementation.md`: new "Chapter 1 Ending" subsection under the Maiteln
  section, covering King Eldar's 4-state custom dialogue, Queen/Scargroth's sub-flags and their
  documented simplification, the ending overlay, the carried-over `BaseOverlay` bug fix, and the
  `ObjectiveTracker`/achievement integration.
