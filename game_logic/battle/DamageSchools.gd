## Damage schools (GID-181 / TID-748): one pure table deciding how much a hit of
## school S does to a target whose school profile is P.
##
## Schools are `physical` plus the four magic types in `MagicTypes` (never re-listed
## here). A card's school is its `magic_type`; a card with no magic type (plain
## minions, Strike, Kick) is `physical`. A target's profile is
## `{"resist": {school: true}, "weak": {school: true}, "immune": {school: true}}`
## (any key may be absent). `outcome()` says which tag applies; `mult()` turns it
## into a damage multiplier from the CombatTuning knobs `resist_mult`, `weak_mult`
## and `immune_mult`. Immune beats resist, resist beats weak, and a school tagged
## in none of them is neutral (×1.0).
##
## Pure logic: no autoloads, no scene tree, so the balance sim and `-s` tests can
## load it. `DamageResolver.deal` calls `scale` at every damage site.
extends RefCounted

const _MagicTypes = preload("res://game_logic/MagicTypes.gd")
const _CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")

## The school of cards with no magic type.
const PHYSICAL: String = "physical"

## Profile keys and outcome strings.
const RESIST: String = "resist"
const WEAK: String = "weak"
const IMMUNE: String = "immune"

## Every school: `physical` first, then the magic types in MagicTypes order.
static func all_schools() -> Array[String]:
	var out: Array[String] = [PHYSICAL]
	out.append_array(_MagicTypes.all_types())
	return out

static func is_school(school: String) -> bool:
	return all_schools().has(school)

## The school a card deals damage as. Accepts a CardInstance (or any Object with a
## `magic_type` property) or a template Dictionary with a `magic_type` key. Anything
## without a valid magic type is `physical`.
static func school_of(card: Variant) -> String:
	var mt: String = ""
	if card is Dictionary:
		mt = str((card as Dictionary).get("magic_type", ""))
	elif card is Object:
		var v: Variant = (card as Object).get("magic_type")
		if v != null:
			mt = str(v)
	return mt if _MagicTypes.is_valid_type(mt) else PHYSICAL

## Which tag `school` carries in `profile`: `"immune"`, `"resist"`, `"weak"` or `""`
## (neutral). Immune is checked first, then resist, then weak.
static func outcome(school: String, profile: Dictionary) -> String:
	if _tagged(profile, IMMUNE, school):
		return IMMUNE
	if _tagged(profile, RESIST, school):
		return RESIST
	if _tagged(profile, WEAK, school):
		return WEAK
	return ""

## Damage multiplier for a hit of `school` on a target with `profile`. `tune` supplies
## the knobs; null uses the defaults. Neutral is 1.0. Physical has its own resist / weak
## knobs (GID-186).
static func mult(school: String, profile: Dictionary, tune: _CombatTuning = null) -> float:
	var t: _CombatTuning = tune if tune != null else _CombatTuning.new()
	match outcome(school, profile):
		IMMUNE:
			return t.get_f("immune_mult")
		RESIST:
			return t.get_f("physical_resist_mult" if school == PHYSICAL else "resist_mult")
		WEAK:
			return t.get_f("physical_weak_mult" if school == PHYSICAL else "weak_mult")
	return 1.0

## Scaled damage for a hit: `damage * mult`, rounded to the nearest whole point and
## never below 1 for a positive hit. A zero multiplier (immune at the default knob)
## deals nothing; a non-positive `damage` stays 0.
static func scale(damage: int, school: String, profile: Dictionary, tune: _CombatTuning = null) -> int:
	return apply_mult(damage, mult(school, profile, tune))

## `damage * m` with the same rounding and floor as `scale()`. The resolver multiplies the
## matchup and the battlefield boost together and rounds once through here.
static func apply_mult(damage: int, m: float) -> int:
	if damage <= 0 or m <= 0.0:
		return 0
	return maxi(1, roundi(float(damage) * m))

## Hero school resistances (GID-181 / TID-751): `raw` is school → fraction of incoming
## damage of that school soaked. Keeps only known schools and clamps each fraction to
## 0..`max_player_resist` (CombatTuning). Returns a new Dictionary; zero entries dropped.
static func capped_resists(raw: Dictionary, tune: _CombatTuning = null) -> Dictionary:
	var t: _CombatTuning = tune if tune != null else _CombatTuning.new()
	var cap: float = t.get_f("max_player_resist")
	var out: Dictionary = {}
	for k: Variant in raw.keys():
		var school: String = str(k)
		if not is_school(school):
			continue
		var frac: float = clampf(float(raw[k]), 0.0, cap)
		if frac > 0.0:
			out[school] = frac
	return out

## The resistance fraction `resists` gives `school` (0 when none).
static func resist_of(resists: Dictionary, school: String) -> float:
	var v: Variant = resists.get(school, 0.0)
	return clampf(float(v), 0.0, 1.0)

static func _tagged(profile: Dictionary, kind: String, school: String) -> bool:
	var tags: Variant = profile.get(kind, {})
	if not (tags is Dictionary):
		return false
	return bool((tags as Dictionary).get(school, false))
