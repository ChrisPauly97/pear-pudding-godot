## StoryQuests — the main story as an ordered table of steps (GID-140).
##
## Each step is one objective the player is sent on. A step is finished once its
## `done_flag` story flag is set; the current step is the one after the most
## advanced finished step, so a save that skipped a flag (debug, migration) still
## lands on the right objective.
##
## Step keys:
##   id        — stable id
##   chapter   — 1, 2, …   (CHAPTERS holds the title)
##   label     — the short objective shown on the compass / HUD
##   giver     — who sent the player
##   summary   — one or two lines of "why", shown in the Journal
##   done_flag — story flag that completes the step
##   map, tx, tz, site — where it happens (see ObjectiveTracker for resolution)
##
## Pure static data — no autoloads — so tests and every UI read one table.
extends RefCounted

const CHAPTERS: Dictionary = {
	1: "Into the Wild World",
	2: "The Road to Larik",
}

## Set once the last Chapter 2 beat plays; nothing after it has a step yet.
const STORY_END_FLAGS: Array[String] = ["chapter2_warcamp_cleared", "chapter2_complete"]

const STEPS: Array[Dictionary] = [
	{"id": "speak_maiteln", "chapter": 1, "label": "Speak to Maiteln", "giver": "Maiteln",
		"summary": "The old wizard Maiteln has come looking for you in Madrian. He has news that cannot wait.",
		"done_flag": "story_intro_complete", "map": "madrian", "tx": 45, "tz": 36},
	{"id": "leave_madrian", "chapter": 1, "label": "Leave Madrian", "giver": "Maiteln",
		"summary": "The Martarquas are rising again, as the prophecy warned. Slip out of Madrian by the south "
			+ "road before your master notices you are gone.",
		"done_flag": "chapter1_left_madrian", "map": "main", "tx": -1, "tz": -1, "site": "madrian_south_road"},
	{"id": "make_camp", "chapter": 1, "label": "Make camp for the night", "giver": "Maiteln",
		"summary": "Night falls on the road south. Maiteln wants a wee rabbit for tea — hunt one at the camp.",
		"done_flag": "chapter1_camp_night", "map": "main", "tx": -1, "tz": -1, "site": "wilderness_camp"},
	{"id": "learn_fire", "chapter": 1, "label": "Learn to make fire", "giver": "Maiteln",
		"summary": "Last night's rain kept the fire out. Maiteln will show you flint and tinder at the camp.",
		"done_flag": "chapter1_learned_fire", "map": "main", "tx": -1, "tz": -1, "site": "wilderness_camp"},
	{"id": "find_farsyth", "chapter": 1, "label": "Find Lord Farsyth", "giver": "Maiteln",
		"summary": "Lord Farsyth of Maykalene must hear the prophecy. His mansion stands at the end of the "
			+ "cobbled street.",
		"done_flag": "chapter1_warned_farsyth", "map": "farsyth_mansion", "tx": 49, "tz": 20},
	{"id": "meet_isfig", "chapter": 1, "label": "Encounter Isfig", "giver": "Lord Farsyth",
		"summary": "Farsyth sends word to the other lords. Take the road south-east toward Blancogov — "
			+ "a rider is coming the other way.",
		"done_flag": "chapter1_received_letter", "map": "main", "tx": -1, "tz": -1, "site": "isfig_road"},
	{"id": "reach_blancogov", "chapter": 1, "label": "Reach Blancogov", "giver": "Scargroth",
		"summary": "Isfig carried Scargroth's summons: the council meets at the temple in three days. "
			+ "Ride hard for Blancogov's gates.",
		"done_flag": "chapter1_reached_blancogov", "map": "blancogov", "tx": 49, "tz": 9},
	{"id": "enter_temple", "chapter": 1, "label": "Enter the Temple", "giver": "Scargroth",
		"summary": "The letter proves your right of entry. King Eldar and the council wait in the great temple.",
		"done_flag": "chapter1_temple_council", "map": "blancogov_temple", "tx": 42, "tz": 15},
	{"id": "council", "chapter": 1, "label": "Speak with the Queen and Scargroth, then the King",
		"giver": "King Eldar",
		"summary": "The council has assembled. Hear the Queen and Scargroth out, then bring it all before the King.",
		"done_flag": "chapter1_complete", "map": "blancogov_temple", "tx": 42, "tz": 15},
	{"id": "eldar_charge", "chapter": 2, "label": "Speak to King Eldar", "giver": "King Eldar",
		"summary": "The alliance is re-sworn. The King is sending riders to every lord — and Scargroth has "
			+ "found a name from Larik in the old registers.",
		"done_flag": "chapter2_charged", "map": "blancogov_temple", "tx": 42, "tz": 15},
	{"id": "travel_larik", "chapter": 2, "label": "Travel west to Larik", "giver": "King Eldar",
		"summary": "You and Maiteln drew the western road to Lord Marsax. It runs through Larik — your home.",
		"done_flag": "chapter2_reached_larik", "map": "larik", "tx": 64, "tz": 50},
	{"id": "search_larik", "chapter": 2, "label": "Search Larik for answers", "giver": "Maiteln",
		"summary": "Your old house stands empty. If your parents left anything behind, it will be in there.",
		"done_flag": "chapter2_found_letter", "map": "larik", "tx": 59, "tz": 58},
	{"id": "west_to_marsax", "chapter": 2, "label": "Continue west toward Marsax Hold", "giver": "Maiteln",
		"summary": "Your parents were taken, not lost — under the tribe's mark and a councilman's seal. "
			+ "Carry the warning north to Marsax Hold.",
		"done_flag": "chapter2_ambush_survived", "map": "main", "tx": -1, "tz": -1, "site": "scout_ambush"},
	{"id": "defend_marsax", "chapter": 2, "label": "Defend Marsax Hold", "giver": "Lord Marsax",
		"summary": "The Martarquas scouts were only the vanguard. The hold is already under attack.",
		"done_flag": "chapter2_siege_won", "map": "marsax_hold", "tx": 50, "tz": 77},
	{"id": "search_hold", "chapter": 2, "label": "Search the hold for clues", "giver": "Lord Marsax",
		"summary": "The siege is broken. The raiders left their effects behind — search them.",
		"done_flag": "chapter2_traitor_seal", "map": "marsax_hold", "tx": 52, "tz": 62},
	{"id": "war_camp", "chapter": 2, "label": "Infiltrate the war-camp", "giver": "Lord Marsax",
		"summary": "The muster orders bear a seal from the King's own council. Steal the tribe's plans from "
			+ "their war-camp in the hills west of the hold.",
		"done_flag": "chapter2_warcamp_cleared", "map": "marsax_hold", "tx": 20, "tz": 50},
]


## Index of the current step in STEPS, or STEPS.size() when the story so far is done.
static func current_index(flags: Dictionary) -> int:
	for f: String in STORY_END_FLAGS:
		if flags.get(f, false):
			return STEPS.size()
	for i: int in range(STEPS.size() - 1, -1, -1):
		if flags.get(str(STEPS[i]["done_flag"]), false):
			return i + 1
	return 0

## The current step (a copy), or {} when every step is done.
static func current_step(flags: Dictionary) -> Dictionary:
	var i: int = current_index(flags)
	if i >= STEPS.size():
		return {}
	return STEPS[i].duplicate()

## Finished steps in story order.
static func completed_steps(flags: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in range(current_index(flags)):
		out.append(STEPS[i])
	return out

static func is_story_done(flags: Dictionary) -> bool:
	return current_index(flags) >= STEPS.size()

static func chapter_title(chapter: int) -> String:
	return "Chapter %d: %s" % [chapter, str(CHAPTERS.get(chapter, ""))]
