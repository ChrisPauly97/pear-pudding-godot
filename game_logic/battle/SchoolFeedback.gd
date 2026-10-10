## Pure presentation rules for school matchups (GID-181 / TID-752): the text and
## colour of a school-coloured damage number, and the data behind an enemy's school
## pips. No autoloads, no scene tree, so unit tests load it directly. The scene side
## (BattleFx labels, RealtimeVisuals pips) only turns these values into controls.
extends RefCounted

const _DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const _CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")
const _MagicTypes = preload("res://game_logic/MagicTypes.gd")
const _HeroState = preload("res://game_logic/battle/HeroState.gd")
const _CardInstance = preload("res://game_logic/battle/CardInstance.gd")

## Physical is not a magic type, so it has no MagicTypes colour: neutral off-white.
const NEUTRAL_COLOR: Color = Color(0.92, 0.92, 0.95)

## Colour for a hit of `school`: its magic type's colour, neutral for physical.
static func school_color(school: String) -> Color:
	if not _MagicTypes.is_valid_type(school):
		return NEUTRAL_COLOR
	return _MagicTypes.type_color(school)

## Suffix shown after the number: "Weak!", "Resisted", "Immune", or "" when neutral.
static func outcome_word(outcome: String) -> String:
	match outcome:
		_DamageSchools.WEAK:
			return "Weak!"
		_DamageSchools.RESIST:
			return "Resisted"
		_DamageSchools.IMMUNE:
			return "Immune"
	return ""

## Floating label text for `amount` (a signed HP change, e.g. -7). An immune hit reads
## "Immune" on its own, since it lands for nothing; any other outcome is "-7 Weak!".
static func damage_text(amount: int, outcome: String) -> String:
	if outcome == _DamageSchools.IMMUNE:
		return outcome_word(outcome)
	var word: String = outcome_word(outcome)
	var num: String = str(amount)
	return num if word == "" else num + " " + word

## The pips an enemy shows, one per school its profile tags, in `all_schools()` order.
## Each entry: {"school": String, "outcome": "weak" | "resist" | "immune"}.
static func pips_for(profile: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for school: String in _DamageSchools.all_schools():
		var outcome: String = _DamageSchools.outcome(school, profile)
		if outcome != "":
			out.append({"school": school, "outcome": outcome})
	return out

## Tap / hover text for a pip: what the school does to this enemy.
static func pip_tooltip(school: String, outcome: String, tune: _CombatTuning = null) -> String:
	var school_name: String = _MagicTypes.display_name(school) if _MagicTypes.is_valid_type(school) else "Physical"
	var mult: float = _DamageSchools.mult(school, {outcome: {school: true}}, tune)
	match outcome:
		_DamageSchools.WEAK:
			return "Weak to %s: takes x%.1f damage" % [school_name, mult]
		_DamageSchools.RESIST:
			return "Resists %s: takes x%.1f damage" % [school_name, mult]
		_DamageSchools.IMMUNE:
			return "Immune to %s: takes no damage" % school_name
	return "%s: neutral" % school_name

## The last-hit record of a hero or card: {"school", "outcome", "serial"}, serial -1 for
## anything else. Read from the unit's own fields that DamageResolver.deal writes.
static func hit_record(unit: Variant) -> Dictionary:
	if unit is _HeroState:
		var h: _HeroState = unit as _HeroState
		return {"school": h.hit_school, "outcome": h.hit_outcome, "serial": h.hit_serial}
	if unit is _CardInstance:
		var c: _CardInstance = unit as _CardInstance
		return {"school": c.hit_school, "outcome": c.hit_outcome, "serial": c.hit_serial}
	return {"school": "", "outcome": "", "serial": -1}
