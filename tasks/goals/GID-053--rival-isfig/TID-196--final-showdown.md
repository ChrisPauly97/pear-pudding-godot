# TID-196: Final Showdown — Unique Card Reward + Journal Entry

**Goal:** GID-053
**Type:** agent
**Status:** pending
**Depends On:** TID-195

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The climactic rival encounter and its unique trophy. Isfig yields a non-craftable legendary card on victory, recorded in the journal as a story milestone.

## Research Notes

- **Unlock condition** — Encounter 3 (final showdown) is available when all of:
  - SaveManager.rival_encounters_won >= 2 (won the first two encounters)
  - SaveManager.story_flags.get("chapter1_temple_council", false) == true (late story flag, set when speaking to King Eldar in blancogov_temple; cite **docs/agent/story-implementation.md** line 44)
  - Recommend: also gate by `not SaveManager.rival_defeated` (ensure only happens once). Conditionally show the enemy entity in blancogov_temple only if these conditions are met.

- **Location & presentation** — Encounter 3 is in `blancogov_temple` map (the final story location). Place Isfig as an ENEMY entity or an NPC that becomes hostile.
  - Pre-battle dialogue (shown before engagement): "Maiteln warned me you'd come this far. Perhaps it's time I stood beside him, not against. Or perhaps we settle this here."
  - After dialogue, standard battle engagement (cite **enemies-and-npcs.md** line 83 and **SceneManager.gd** line 226 _on_enemy_engaged).
  - Post-victory dialogue (optional narration, not forced): "You've bested me twice now. Maiteln would be proud. Go — the Martarquas wait for no one."

- **Unique reward card** — a new CardData .tres file, e.g., `isfig_shadow_echo.tres` in `data/cards/`:
  - Card ID: `isfig_shadow_echo` (unique, non-craftable).
  - Display name: "Shadow Echo" or similar (cite **GID-028 / card data format** — must have `can_craft: bool = false` and `unique: bool = true` fields on CardData; verify in **data/CardData.gd**).
  - Stats: mid-tier legendary (attack/health to be balanced, cost ~4–5 mana).
  - Ability: flavor text referencing Isfig's journey (e.g., "Plays twice if you've fought a rival").
  - Create sidecar `.uid` file (cite **CLAUDE.md** rule, format `uid://` + 12 random chars).
  - Register in **autoloads/CardRegistry.gd** — like all card .tres files, auto-scanned from `data/cards/` (cite how EnemyRegistry scans; CardRegistry likely has similar pattern; verify code).

- **Single grant guard** — reward granted exactly once:
  - At **SceneManager._on_battle_won()** (line 253), detect rival final showdown: `enemy_type == "rival_isfig_3" and not SaveManager.rival_defeated`.
  - Call `SaveManager.add_card_instance("isfig_shadow_echo", "legendary")` (cite **SaveManager.gd** line 513–530 for add_card_instance signature: `add_card_instance(template_id: String, rarity: String, attack: int = -1, health: int = -1, cost: int = -1) -> String`).
  - Set SaveManager.rival_defeated = true immediately after (or do it as part of TID-195's win logic for any rival).
  - If player saves/loads after the encounter, rival_defeated persists (cite migration in TID-194), so re-entering the map will not re-grant the card.

- **Journal entry** — record the rivalry outcome. Cite **autoloads/ScrollRegistry.gd** (lines 5–54) for the scroll registry structure and **scenes/ui/JournalScene.gd** (lines 1–100) for journal UI.
  - ScrollRegistry holds a `_SCROLLS: Array` of dictionaries: `{ "id": String, "title": String, "lore_text": String, "audio_path": String }`.
  - Add a new scroll entry for the rivalry, e.g., `rival_victory_scroll`:
    ```
    {
        "id": "scroll_isfig_shadow",
        "title": "Isfig's Shadow",
        "lore_text": "Maiteln's brother stood against you three times, and three times you prevailed. When the final blow was struck, Isfig smiled — not in defeat, but in recognition. He had seen something in you that even Maiteln had missed.",
        "audio_path": "res://assets/audio/narration/scroll_isfig_shadow.ogg",
    }
```
  - Automatically unlock this scroll when SaveManager.rival_defeated becomes true (cite **SaveManager.gd** line 52 `collected_scrolls: Array[String] = []` and **StoryScroll.gd** for the entity that marks scrolls collected).
  - Alternative (simpler for now): manually add the scroll to collected_scrolls in _on_battle_won when defeating rival_isfig_3, before granting the card: `SaveManager.collected_scrolls.append("scroll_isfig_shadow")`. Then emit GameBus.story_scroll_collected("scroll_isfig_shadow") so any UI listening can show a toast.

- **Dialog progression with rivals** — after each rival win, subsequent encounters show different dialogue from other NPCs (optional flavor, not required for AC):
  - In farsyth_mansion: Lord Farsyth can comment on news of the rival's defeat via flag-gated dialogue (cite **docs/agent/story-implementation.md** line 46–60 for NPC dialogue gating pattern).
  - Flag key (new): `chapter1_defeated_rival_1`, `chapter1_defeated_rival_2`, `chapter1_defeated_rival_3` (set at end of each rival battle in SceneManager._on_battle_won).
  - Not required for AC; can be deferred to TID-020 (dialogue expansion).

- **Tests (headless)** — in **tests/test_rival_finale.gd**:
  - Test unlock predicate: rival_encounters_won=2, story_flag("chapter1_temple_council")=true → Encounter 3 available. rival_encounters_won=1 → not available. rival_defeated=true → not available on re-entry.
  - Test single grant: first battle_won with rival_isfig_3 → isfig_shadow_echo added to owned_cards; rival_defeated set to true. Second _on_battle_won with rival_isfig_3 (if enemy somehow re-engaged) → card NOT re-granted (guard checked).
  - Test scroll collection: rival_defeated=true → "scroll_isfig_shadow" appears in SaveManager.collected_scrolls.

- **Audio asset note** — narration audio file `res://assets/audio/narration/scroll_isfig_shadow.ogg` must exist (or be created during this task, or deferred to audio/content team). If missing at build time, JournalScene can gracefully skip playback.

- **Documentation updates**:
  - **docs/agent/enemies-and-npcs.md** — expand the "Defeat Persistence" section (line 106–112) to note that rival enemies skip marked_enemy_defeated to allow retry.
  - **docs/agent/save-system.md** — update migration history table (line 91–106) to add v15: `rival_encounters_won`, `rival_defeated`.
  - **docs/agent/story-implementation.md** — add a row to the Planned Flags table noting the two new story flags if defined (chapter1_defeated_rival_1/2/3, optional).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
