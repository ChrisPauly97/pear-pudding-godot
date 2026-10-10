## Bestiary school knowledge (GID-181 / TID-753): what the player has learned about an
## enemy type's damage schools. Knowledge is progression: the first encounter shows the
## enemy's attack school, and a defeat reveals its weak and resist profile. Pure rules over
## one bestiary entry `{"seen": int, "defeated": int}` (SaveManager.get_bestiary_entry), so
## no save field is needed. No autoloads, no scene tree; unit tests load it directly.
extends RefCounted

const _DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")

## Unknown attack school reads as this (the UI shows "?").
const UNKNOWN: String = ""

## The attack school is known once the enemy has been seen at least once.
static func attack_school_known(entry: Dictionary) -> bool:
	return int(entry.get("seen", 0)) >= 1

## Weak and resist tags are known once the enemy has been defeated at least once.
static func profile_known(entry: Dictionary) -> bool:
	return int(entry.get("defeated", 0)) >= 1

## The attack school the player knows: `attack_school` once seen, else UNKNOWN.
static func known_attack_school(attack_school: String, entry: Dictionary) -> String:
	return attack_school if attack_school_known(entry) else UNKNOWN

## The part of a full profile the player knows: all of it once defeated, else empty.
## Returns a copy, so callers can keep or edit it without touching the source profile.
static func known_profile(profile: Dictionary, entry: Dictionary) -> Dictionary:
	if not profile_known(entry):
		return {}
	return profile.duplicate(true)

## Everything the bestiary page shows about an enemy's schools, already gated:
## {"attack_known": bool, "attack": String (UNKNOWN when not known),
##  "profile_known": bool, "weak": Array[String], "resist": Array[String]}.
## Weak and resist lists follow `all_schools()` order and are empty when not known.
static func journal_view(attack_school: String, profile: Dictionary, entry: Dictionary) -> Dictionary:
	var shown: Dictionary = known_profile(profile, entry)
	var weak: Array[String] = _tagged(shown, "weak")
	var resist: Array[String] = _tagged(shown, "resist")
	return {
		"attack_known": attack_school_known(entry),
		"attack": known_attack_school(attack_school, entry),
		"profile_known": profile_known(entry),
		"weak": weak,
		"resist": resist,
	}

static func _tagged(profile: Dictionary, kind: String) -> Array[String]:
	var out: Array[String] = []
	var tags: Dictionary = profile.get(kind, {})
	for school: String in _DamageSchools.all_schools():
		if tags.has(school):
			out.append(school)
	return out
