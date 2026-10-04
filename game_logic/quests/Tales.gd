## Tales — the secret Pear Pudding legend's rumours (GID-153 / TID-654).
##
## Certain townsfolk tell a tale once, in order. Each tale is a riddle that points
## at a world puzzle (RiddleSpots, TID-655). Deliberately invisible to the quest
## systems: no QuestLog row, no NPC mark, no compass or map waypoint. Progress is
## story flags only: `legend_tale_<id>` once heard, the tale's `solve_flag` once
## its riddle is solved. Pure static data, like SideQuests / StoryQuests.
##
## Keys: id, npc (stitched-town entity id), npc_name, town, title, lines (what
##       the teller says), riddle (what the Journal keeps), after (tale id that
##       must be heard first, "" = none), solve_flag.
extends RefCounted

const FLAG_PREFIX: String = "legend_tale_"
## Every legend flag starts with this. They are personal: co-op never syncs them
## (CoopSession), so a friend's progress can't spoil the secret.
const PERSONAL_PREFIX: String = "legend_"

const TALES: Array[Dictionary] = [
	{"id": "soldier", "npc": "old_garrick", "npc_name": "Old Garrick", "town": "madrian",
		"title": "The King Who Woke",
		"lines": ("Pear Pudding? Ha! My grandsire stood guard at the old king's door. Swore the man was dead by "
			+ "dusk and laughing by dawn, all on account of a pudding Mother Perrine brought him. Her recipe "
			+ "went into the ground with her, they say."),
		"riddle": "Where three stones lean and the sun goes down, the earth remembers.",
		"after": "", "solve_flag": "legend_recipe"},
	{"id": "rhyme", "npc": "little_pip", "npc_name": "Little Pip", "town": "maykalene",
		"title": "The Skipping Rhyme",
		"lines": ("Pear so gold, never old, hangs where no orchard grows! Climb the cliff and mind your toes, "
			+ "Mother Perrine knows, knows, knows! ...That's how the rhyme goes. Gran taught me."),
		"riddle": "Pear so gold, never old, hangs where no orchard grows.",
		"after": "soldier", "solve_flag": "legend_golden_pear"},
	{"id": "bard", "npc": "lisette_bard", "npc_name": "Lisette the Bard", "town": "blancogov",
		"title": "The Ballad of Mother Perrine",
		"lines": ("Ah, you know the old ballad? Few do. Perrine walked the night roads when the dead walk too. "
			+ "She asked the dead what they sighed, and bottled the answer. A pretty line. I never knew "
			+ "what it meant."),
		"riddle": "Ask the dead what they sighed.",
		"after": "rhyme", "solve_flag": "legend_sigh"},
	{"id": "farmer", "npc": "farmer_odd", "npc_name": "Odd the Farmer", "town": "larik",
		"title": "The Farmer's Grumble",
		"lines": ("Pear Pudding, pear pudding. My old mam never stopped on about it. 'Stir it where the old queen "
			+ "drank, when the rain sings.' Nonsense, if you ask me. The queen's well's been dry rubble for "
			+ "a hundred years."),
		"riddle": "Stir it where the old queen drank, when the rain sings.",
		"after": "bard", "solve_flag": "legend_pudding_owned"},
]


static func is_personal_flag(key: String) -> bool:
	return key.begins_with(PERSONAL_PREFIX)


static func flag_for(tale_id: String) -> String:
	return FLAG_PREFIX + tale_id


static func def(tale_id: String) -> Dictionary:
	for t: Dictionary in TALES:
		if str(t["id"]) == tale_id:
			return t
	return {}


static func is_heard(tale_id: String, flags: Dictionary) -> bool:
	return bool(flags.get(flag_for(tale_id), false))


## The tale `npc_id` would tell now: not yet heard and its `after` tale heard. {} if none.
static func tale_for_npc(npc_id: String, flags: Dictionary) -> Dictionary:
	for t: Dictionary in TALES:
		if str(t["npc"]) != npc_id or is_heard(str(t["id"]), flags):
			continue
		var after: String = str(t.get("after", ""))
		if after == "" or is_heard(after, flags):
			return t
	return {}


## Tales heard so far, in legend order (the Journal's "Old Tales" page).
static func heard(flags: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Dictionary in TALES:
		if is_heard(str(t["id"]), flags):
			out.append(t)
	return out


static func is_solved(tale: Dictionary, flags: Dictionary) -> bool:
	return bool(flags.get(str(tale.get("solve_flag", "")), false))
