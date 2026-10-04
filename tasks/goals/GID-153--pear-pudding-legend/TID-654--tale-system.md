# TID-654: Tale System — Rumour Lines, Old Tales Journal Page, Legend Flags

**Goal:** GID-153
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The legend is learned from people, not quest givers. Certain NPCs need an extra line ("tale") that plays when its
condition fits, records a tale flag, and adds the riddle text to a new Journal page. No marks, no tracking.

## Research Notes

- NPC interaction: `scenes/world/modules/NpcInteractions.gd` `interact()` counts a `talk` event then
  `show_quest_panel(npc)`; services via "Other business". A tale should be offered as another option / line in the
  same panel (e.g. "Any tales?") only for NPC ids in the tale table — never via `QuestLog.npc_mark`.
- Stitched-town NPC ids: `RealmLayout.entities` prefixes generic ids (`madrian:npc_2`); named ids as authored.
  Place NPCs with `scripts/add_map_npc.py` (see `docs/agent/story-implementation.md` Side Quests).
- Data: new pure static table `game_logic/quests/Tales.gd` (code, not `.tres`, like SideQuests/StoryQuests):
  `{id, npc, npc_name, lines, riddle, req_flag, sets_flag}`. Gate with existing story flags
  (`SaveManager.set_story_flag` / `has_story_flag`).
- Persist via story flags (`legend_tale_<id>`, `legend_<step>`) — no new PERSISTED_FIELDS needed. If a field is
  needed, add one `SaveManager.PERSISTED_FIELDS` entry (see CLAUDE.md "Save Fields").
- Journal: `scenes/ui/JournalScene.gd` has tab buttons (`_tab_quests_btn`, `_tab_scrolls_btn`, …) built with
  `_UiUtil.make_button` + `_on_tab_selected.bind(...)`. Add an "Old Tales" tab, hidden until the first tale is heard.
- Must NOT add entries to `QuestLog`, `ObjectiveTracker` or `QuestTracker` (no beacon/compass/minimap).
- Signal: add `GameBus.legend_tale_heard(tale_id)` (literal `.emit()`, `test_gamebus_signal_coverage`).
- Tests: `tests/unit/test_tales.gd` — table integrity, gating, flag set once, journal entry list, no QuestLog entry.

## Plan

Static `Tales.gd` table + helpers (story-flag state only); `NpcInteractions.show_tale_panel` after the quest
panel; Journal "Old Tales" tab gated on a heard tale; `GameBus.legend_tale_heard`; keep legend flags out of co-op
sync; unit tests incl. a guard that quest systems never reference the legend.

## Changes Made

- `game_logic/quests/Tales.gd` (new): four tales (soldier, rhyme, bard, farmer) with lines, riddle, order, solve flag.
- `scenes/world/modules/NpcInteractions.gd`: `show_tale_panel()` wired into `interact()`.
- `scenes/ui/JournalScene.gd`: "Old Tales" tab (hidden until first tale).
- `autoloads/GameBus.gd`: `legend_tale_heard(tale_id)`.
- `scenes/world/coop/CoopSession.gd`: personal `legend_*` flags not synced to the party.
- `tests/unit/test_tales.gd` (new, 5 tests). Full suite, world/menu smokes, unsafe-hits, gdlint clean.
- Teller NPCs themselves are placed by TID-657.

## Documentation Updates

New `docs/agent/legends-pear-pudding.md`; row added to the CLAUDE.md docs table.
