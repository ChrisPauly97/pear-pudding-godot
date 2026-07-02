# BID-016: Flag-Gated NPC Dialogue Content Needs Authoring

**Category:** human-action-deferred
**Discovered During:** GID-020 / TID-063

The `TownspersonNPC` flag-routing logic (TID-065) and FLAG map entity syntax (TID-064) are implemented and ready.
However, the human-authored dialogue content in `docs/human/story.md` → **Flag-Gated Dialogue States** table
is incomplete: only the blancogov gate guard row is filled in.

Until more rows are added the flag-routing code runs but most NPCs still show their static fallback line.

**What needs to be done (human):**
Open `docs/human/story.md` and add rows to the Flag-Gated Dialogue States table for at least:
- Maykalene townsperson — `chapter1_met_maiteln`
- A blancogov_temple NPC — `chapter1_entered_temple`
- Any other NPC whose dialogue should change after a story flag

Format: `NPC | Map | Flag Key | Before-Flag Text | After-Flag Text`

Once filled in, mark TID-063 done in `tasks/goals/GID-020--story-completion/TID-063--author-flag-gated-dialogue.md`
and update progress in `goal.md` and `tasks/index.md`.

---

**RESOLVED 2026-07-02 via GID-108:** The full Flag-Gated Dialogue States table (11 NPCs across all 5 named maps) was drafted as the GID-108 story pack, approved by the user, and written into `docs/human/story.md`. TID-063 marked done. Application of the table to the map files is tracked by GID-108/TID-404.
