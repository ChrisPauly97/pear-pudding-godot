# Legends: The Pear Pudding (GID-153)

The game's name, written into the lore as a secret: Old Mother Perrine's lost royal remedy. Canon text lives in
`docs/human/story.md` → "Legends: The Pear Pudding".

## Key Features

- Learned from **tales**, not quest givers: four townsfolk each tell one fragment, once, in order.
- Each tale is a **riddle** kept on the Journal's **Old Tales** tab (the tab appears after the first tale).
- **Invisible to the quest systems**: no QuestLog row, no NPC "!" / "?", no compass, minimap or beacon.
- Riddles resolve at world puzzle spots (TID-655) and end in **Perrine's Bottomless Pudding**, a never-consumed
  legendary potion (see `home-garden-potions.md`).

## How It Works

### Tales (`game_logic/quests/Tales.gd`, TID-654)

Pure static `TALES` table: `{id, npc, npc_name, town, title, lines, riddle, after, solve_flag}`.

| id | teller (entity id) | town | riddle → solve_flag |
|---|---|---|---|
| `soldier` | Old Garrick (`old_garrick`) | madrian | three leaning stones at dusk → `legend_recipe` |
| `rhyme` | Little Pip (`little_pip`) | maykalene | golden pear on a cliff → `legend_golden_pear` |
| `bard` | Lisette the Bard (`lisette_bard`) | blancogov | ask the dead what they sighed → `legend_sigh` |
| `farmer` | Odd the Farmer (`farmer_odd`) | larik | the queen's well in the rain → `legend_pudding_owned` |

Helpers: `flag_for(id)` (`legend_tale_<id>`), `def`, `is_heard`, `tale_for_npc(npc_id, flags)` (not yet heard and
its `after` tale heard), `heard(flags)`, `is_solved(tale, flags)`, `is_personal_flag(key)`.

- **State** is story flags only (`SaveManager.story_flags`), no new persisted field.
- **Telling:** `NpcInteractions.interact()` → after the side-quest panel, `show_tale_panel(npc)` sets the tale flag
  on open, emits `GameBus.legend_tale_heard(tale_id)`, and shows the teller's lines ("Farewell"; "Other business"
  for service NPCs).
- **Journal:** `JournalScene` adds an "Old Tales" tab only when `Tales.heard()` is non-empty; entries show the
  lines, the riddle in bold and a ✓ / "Solved." once `solve_flag` is set.
- **Co-op:** every `legend_*` flag is personal — `CoopSession._on_local_story_flag_set` skips
  `Tales.is_personal_flag(key)`, so a party member's progress never spoils yours.
- **Tests:** `tests/unit/test_tales.gd` (table integrity, order gating, heard/solved, and a guard that QuestLog,
  ObjectiveTracker, QuestTracker and SideQuests never reference the legend).

### Riddle Spots (`game_logic/world/RiddleSpots.gd`, TID-655)

Pure static `SPOTS` table + `evaluate(spot, action, ctx) -> idle | hint | missing | solved | done` and
`line_for(spot, result)`. `ctx = {flags, time_of_day, weather}`; `phase(t)` → dawn [0.20, 0.30), dusk
[0.70, 0.80), else night/day by `DayNightCycle.is_night`'s sine.

| id | prop | overworld tile | tale | condition | sets |
|---|---|---|---|---|---|
| `leaning_stones` | `legend_stones` | (-6, 46) west of the Madrian→Maykalene road | soldier | Skeleton Dig at dusk | `legend_recipe` |
| `golden_pear_tree` | `legend_pear_tree` (→ `_bare`) | (112, 148) east of the Maykalene→Blancogov road, in a glade | rhyme | look, any time | `legend_golden_pear` |
| `queens_well` | `legend_well` | (-62, 300) south of the Blancogov→Larik road | farmer | rain/storm + recipe, pear, sigh | `legend_pudding_owned` |

- Before the tale is heard a spot is plain scenery (`idle` line). Afterwards the wrong hour/weather/action gives a
  `hint`; the right moment without ingredients gives `missing`.
- **World module** `scenes/world/modules/Legend.gd` (`WorldScene.legend`): builds one `RiddleSpot` per spot on the
  overworld (`map_name == "main"`) on first tick, `examine(spot_id, action)` shows the line, and on `solved` sets the
  flag, emits `GameBus.legend_riddle_solved(spot_id)` and refreshes the prop. `try_dig(px, pz)` is called by
  `Cantrips.activate_skeleton_dig` when no burial mound is in reach.
- **Entity** `scenes/world/entities/RiddleSpot.gd`: billboard + `interact()` callback. No ring, label or marker.
- **Interaction:** `INTERACT_PRIORITY` entry `riddle_spot` (after `burial_mound`), prompt "EXAMINE",
  `_find_nearby_riddle_spot` in `_try_simple_interaction`.
- **Art:** `tools/generate_legend_props.py` → `assets/textures/props/legend_*.png`, preloaded in
  `SpriteRegistry._LEGEND_PROPS` (`legend_prop(key)`).
- **Tests:** `tests/unit/test_riddle_spots.gd`.

### Content & Payoff (TID-657)

- **Tellers** placed with `scripts/add_map_npc.py` (plain townsfolk, no name label, no type): `old_garrick` madrian
  (35, 27) by the inn, `little_pip` maykalene (54, 48), `lisette_bard` blancogov (46, 69), `farmer_odd` larik
  (57, 45). Their map `dialogue` is the everyday line once the tale is told (or before its turn).
- **Glades:** `RealmLayout.legend_site_distance()` folds each spot into `reserved_distance` (+`LEGEND_SITE_PAD`
  0.5, so never a path tile) and `chunk_touches_realm` counts a spot's chunk. World gen therefore flattens the
  ground, keeps streams/ponds, trees, ruins, landmarks and random spawns away — a natural clearing, no marker.
- **Spectre's Sigh:** `RiddleSpots.earns_sigh(type, flags)` (spectre kill + bard's tale + recipe). Checked in
  `SaveQuests.progress_event("kill")`, which every won fight calls for every kill (spectres included). Sets
  `legend_sigh`, emits `legend_riddle_solved("spectre_sigh")`, toasts `SIGH_TEXT`.
- **Brew:** solving `queens_well` (`PUDDING_FLAG`) runs `Legend._brew_pudding`: `garden.grant_legendary("pear_pudding")`
  and a gold modal (flask icon, the solved text, how the flask works, "Drink deep").
- **Tests:** `tests/unit/test_pear_pudding_legend.gd` — tellers placed in their towns, glades reserved but unmarked,
  glades grass/flat/dry/spawn-free across seeds, the full chain, sigh gating, one-time grant, no quest-log leak.

### Achievement (TID-658)

`AchievementRegistry` entry `spoonful_of_legend` ("A Spoonful of Legend"), `specific_flag` on
`legend_pudding_owned`, `"secret": true`. `AchievementRegistry.display_text(a, unlocked)` returns `???` and a
teaser line until it unlocks; `AchievementsScene` reads it. The toast fires on unlock as usual.

## Integrations

- Story flags (`SaveManager.set_story_flag`), GameBus, NpcInteractions, JournalScene, CoopSession, world gen
  (`RealmLayout.reserved_distance`), SaveQuests kill events, quick-slot potions, AchievementRegistry.

## Asset Requirements

- `assets/icons/items/pear_pudding.png` (generated by `tools/generate_app_icon.py`).
- `assets/textures/props/legend_stones.png`, `legend_pear_tree.png`, `legend_pear_tree_bare.png`, `legend_well.png`
  (generated by `tools/generate_legend_props.py`).
