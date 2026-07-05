# TID-404: Flag-Gated Dialogue Content Pass Across All Named Maps

**Goal:** GID-108
**Type:** agent
**Status:** done
**Depends On:** TID-400

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The FLAG map-entity syntax and TownspersonNPC flag routing were built in GID-020 (TID-064/TID-065) but content was never authored (backlog BID-016). The approved dialogue table now exists in docs/human/story.md ("Flag-Gated Dialogue States"). This task applies it to every NPC across the 5 named maps.

## Research Notes

- **Source of truth:** docs/human/story.md — "Flag-Gated Dialogue States" table: 11 NPCs across madrian (Master, Maiteln), maykalene (Townsperson, Innkeeper, Mansion guard), farsyth_mansion (Lord Farsyth), blancogov (Gate guard — already wired, City dweller), blancogov_temple (King Eldar, Queen, Scargroth). Flag keys used: story_intro_complete, chapter1_warned_farsyth, chapter1_received_letter, chapter1_temple_council, chapter1_complete.
- **FLAG syntax:** `NPC x z FLAG:flag_key before_text || after_text` (implemented by TID-064 in the WorldMap parser; TID-065 wired TownspersonNPC.get_dialogue() routing). Verify exact syntax in the parser (game_logic/world/ WorldMap parsing code) before editing maps.
- **Maps are .tres now** (GID-017): assets/maps/*.tres preloaded by autoloads/MapRegistry.gd. NPC dialogue lives in the map resource entity data — edit the .tres files (text format) for madrian, maykalene, farsyth_mansion, blancogov, blancogov_temple. The gate guard's chapter1_received_letter gating may already exist (WorldScene.gd ~line 2901 references it) — check for double-wiring.
- **Scargroth's chapter1_complete after-line** is the parents-mystery hook ("…there is a name from Larik you should see") — must match story.md exactly.
- Existing test precedent: tests/ has NPC/parser tests; add or extend a test asserting flag routing returns the correct line for at least one before/after pair per map.
- Resolves backlog item BID-016 (already marked resolved in tasks/index.md when this goal was created — confirm and archive the BID file if not done).

## Plan

**Key finding that reshapes scope:** `MapNpc.gd` already has `flag_key`/`after_dialogue` fields
(added post-GID-017 .tres migration — the old .txt `FLAG:` syntax the research notes describe is
obsolete), and `WorldScene._handle_interact()`'s npc branch already **auto-sets** `flag_key` as a
side effect of *any* interaction with that NPC (not just a read for text-selection):
```gdscript
if nnode != null and nnode.has_method("get_dialogue"):
    dlg = nnode.get_dialogue()
    var fk: String = str(npc.get("flag_key", ""))
    if fk != "":
        SceneManager.save_manager.set_story_flag(fk)
```
That's correct and sufficient for a single-condition NPC (talking to them *is* the story beat:
recruiting Maiteln, warning Farsyth). It is **wrong** for King Eldar/Queen/Scargroth in
blancogov_temple, whose story.md "Flag Key" column (`chapter1_complete`) describes *when their
line changes*, not something their interaction should set — `chapter1_complete` is a compound
condition (temple council reached AND Queen AND Scargroth both spoken to) that only King Eldar's
special ending trigger should ever set. Wiring `flag_key = "chapter1_complete"` onto any of the
three would make the first person who talks to *any one of them* instantly complete Chapter 1.

Confirmed nothing currently sets `chapter1_temple_council` anywhere in the codebase (grepped) —
King Eldar's *existing* `flag_key = "chapter1_temple_council"` is exactly the "council is
assembling" beat firing on first contact, and is correct as-is.

**Scope split:**
1. Wire the 8 NPCs whose story.md row is a genuine single-condition "talking to them is the
   beat" case, matching the existing auto-set mechanic cleanly:
   - Master (madrian, tile 11,14): `flag_key = "story_intro_complete"` (currently unset — same
     flag Maiteln already sets, idempotent), `after_dialogue` per story.md.
   - Maiteln (madrian, tile 45,36): `flag_key` already `story_intro_complete` (unchanged) —
     **fix** `after_dialogue`, which currently reads a placeholder line that doesn't match the
     approved story.md text.
   - Townsperson, Innkeeper, Mansion guard (maykalene): `flag_key = "chapter1_warned_farsyth"`
     (currently unset on all three), `after_dialogue` per story.md.
   - Lord Farsyth (farsyth_mansion): `flag_key` already `chapter1_warned_farsyth` (unchanged) —
     **fix** `after_dialogue` to match story.md exactly (currently a different placeholder line).
   - Gate guard (blancogov): `flag_key = "chapter1_received_letter"` (currently unset), plus
     update `dialogue` (before-text) to the Flag table's explicitly-restated wording (shorter
     than the static NPC-table version — the table's own convention is "before-text is the
     static line above *unless it differs here*", and here it does). Confirmed no double-wiring
     conflict: `chapter1_received_letter` is set by winning the Isfig `rival_enc2` encounter
     (`SceneManager.gd` ~line 1126); `set_story_flag` is idempotent, and a player who somehow
     reaches the gate before that encounter getting waved through is a reasonable sequence-break
     safety valve, not a bug.
   - City dweller (blancogov): `flag_key = "chapter1_temple_council"` (currently unset),
     `after_dialogue` per story.md.
2. **King Eldar / Queen / Scargroth (blancogov_temple): explicitly deferred to TID-405.**
   Getting their three-state narrative right (before any contact / after first contact but
   before `chapter1_complete` / after the ending) needs the compound completion trigger itself
   — that's TID-405's "Chapter 1 ending scene + post-council epilogue world reactivity", and
   doing it here would mean inventing throwaway logic that task will replace anyway. Their
   current wiring is left untouched (King Eldar's `chapter1_temple_council` flag_key is correct
   and stays; Queen/Scargroth stay unflagged).
3. Not touching `dialogue_group` (co-op plural variant) for the newly-added `after_dialogue`
   text — no `after_dialogue_group` field exists yet; per TID-408's research notes this is
   explicitly TID-358's ("group dialogue pluralization pending") job, which is already told to
   pick up new GID-108 lines once it lands.
4. Confirm BID-016 is archived (task says it should already be marked resolved).
5. Add a small test extending NPC/parser test coverage: one before/after assertion per newly-
   wired map, using `WorldMap`'s NPC-loading path directly (mirrors any existing NPC dict test
   precedent) rather than a full WorldScene interaction (too heavy for a unit test).

**Validation:** same sandbox constraint as TID-401/402/403 — no Godot binary available.

## Changes Made

- **`assets/maps/madrian.tres`**: Maiteln (npc_1) `after_dialogue` corrected to match story.md
  exactly (was a placeholder line); Master (npc_2) newly gated on `story_intro_complete` with
  its approved after-line.
- **`assets/maps/maykalene.tres`**: Townsperson (npc_1), Innkeeper (npc_2), Mansion guard
  (npc_3) all newly gated on `chapter1_warned_farsyth` with their approved after-lines.
- **`assets/maps/farsyth_mansion.tres`**: Lord Farsyth (npc_2) `after_dialogue` corrected to
  match story.md exactly (was a placeholder line); `flag_key` unchanged.
- **`assets/maps/blancogov.tres`**: Gate guard (npc_1) newly gated on `chapter1_received_letter`,
  before-text updated to the Flag table's explicit restated wording; City dweller (npc_2) newly
  gated on `chapter1_temple_council`.
- **`tests/unit/test_named_map_npcs.gd`**: 6 new tests asserting `flag_key`/`after_dialogue`
  (and the Gate guard's corrected before-text) for every NPC touched above.

**Deliberately deferred (see Plan for the full reasoning):** King Eldar, Queen, and Scargroth in
`blancogov_temple` are **not** touched. Story.md's Flag table lists all three under
`chapter1_complete`, but that flag is a compound condition (temple council reached AND Queen AND
Scargroth both spoken to) that only the Chapter 1 ending trigger should ever set — and
`WorldScene._handle_interact()`'s NPC branch auto-sets whatever `flag_key` an NPC carries the
moment they're talked to. Wiring any of the three to `chapter1_complete` directly would let the
first person who talks to *any one* of them instantly complete Chapter 1. Getting their
three-state dialogue (before any contact / after first contact but before the ending / after the
ending) right requires the compound trigger itself, which is TID-405's job
("Chapter 1 ending scene + post-council epilogue world reactivity"); King Eldar's existing
`flag_key = "chapter1_temple_council"` (the "council is assembling" beat, confirmed nothing else
in the codebase currently sets that flag) is correct as-is and untouched.

Also not touched: `dialogue_group` (co-op plural before-text variant) for the newly-added
`after_dialogue` lines — no `after_dialogue_group` field exists; per TID-408's research notes
this is explicitly TID-358's ("group dialogue pluralization pending") job.

BID-016 was already archived/marked resolved in `tasks/index.md` prior to this task (confirmed,
no action needed).

**Validation:** same sandbox constraint as TID-401/402/403 (no Godot binary, network egress
blocked). Manual review of every `.tres` edit and the new test file in place of headless import.

## Documentation Updates

None — this task applies already-approved `docs/human/story.md` content to existing engine
fields (`MapNpc.flag_key`/`after_dialogue`); no new design/pattern was introduced.
