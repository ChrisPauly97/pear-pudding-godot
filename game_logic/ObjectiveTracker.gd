## Derives the current Chapter 1 story objective from story flags.
## Returns {label: String, map: String, tx: int, tz: int} or {} if no active objective.
## Checks most-advanced flag first so the correct next step is always returned.
class_name ObjectiveTracker
extends RefCounted

static func current_objective(flags: Dictionary) -> Dictionary:
	if flags.get("chapter1_complete", false):
		return {}
	if flags.get("chapter1_temple_council", false):
		return {"label": "Speak with the Queen and Scargroth, then the King",
			"map": "blancogov_temple", "tx": 42, "tz": 15}
	if flags.get("chapter1_reached_blancogov", false):
		return {"label": "Enter the Temple", "map": "blancogov_temple", "tx": 42, "tz": 15}
	if flags.get("chapter1_received_letter", false):
		return {"label": "Reach Blancogov", "map": "blancogov", "tx": 49, "tz": 9}
	if flags.get("chapter1_warned_farsyth", false):
		# Isfig encounter is a scripted open-world event with no fixed tile.
		return {"label": "Encounter Isfig", "map": "main", "tx": -1, "tz": -1}
	if flags.get("chapter1_learned_fire", false):
		return {"label": "Find Lord Farsyth", "map": "farsyth_mansion", "tx": 49, "tz": 20}
	if flags.get("chapter1_camp_night", false):
		# Fire-making lesson is a scripted open-world event with no fixed tile.
		return {"label": "Learn to make fire", "map": "main", "tx": -1, "tz": -1}
	if flags.get("chapter1_left_madrian", false):
		# Rabbit-hunt camp is a scripted open-world event with no fixed tile.
		return {"label": "Make camp for the night", "map": "main", "tx": -1, "tz": -1}
	if flags.get("story_intro_complete", false):
		return {"label": "Leave Madrian", "map": "madrian", "tx": 50, "tz": 50}
	return {"label": "Speak to Maiteln", "map": "madrian", "tx": 45, "tz": 36}
