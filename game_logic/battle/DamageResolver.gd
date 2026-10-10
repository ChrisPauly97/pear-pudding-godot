## The single damage entry point (GID-181 / TID-749). Every hit a card, hero or
## status deals goes through `deal()`: it reads the defending side's school profile
## (`PlayerState.school_profile`), scales the amount with `DamageSchools`, applies it
## with the target's own `take_damage` (armor and shroud still apply) and reports what
## landed plus the matchup outcome for the UI.
##
## Pure logic: no autoloads, no scene tree, so the balance sim and `-s` tests load it
## too. Raw `take_damage` lives only on HeroState / CardInstance; nothing else calls it
## (tests/unit/test_damage_resolver_guardrail.gd enforces that).
extends RefCounted

const _DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const _CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")
const _HeroState = preload("res://game_logic/battle/HeroState.gd")
const _CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const _PlayerState = preload("res://game_logic/battle/PlayerState.gd")

## Applies one damage event to `target` (a HeroState or CardInstance owned by
## `defender`). `amount` is the pre-school damage, `school` the hit's school
## (`DamageSchools.school_of(card)`, or `DamageSchools.PHYSICAL`). `tune` supplies the
## matchup knobs; null uses the defaults.
## Returns {"dealt": int, "outcome": String}: `dealt` is the HP actually lost (armor and
## shroud can soak some or all of it), `outcome` is "immune", "resist", "weak" or ""
## (neutral). A null `defender` is treated as a profile-less side.
static func deal(defender: _PlayerState, target: Variant, amount: int, school: String,
		tune: _CombatTuning = null) -> Dictionary:
	var outcome: String = _DamageSchools.outcome(school, profile_of(defender))
	if outcome == "" and resist_fraction(defender, school) > 0.0:
		outcome = _DamageSchools.RESIST  # a hero resistance reads as "Resisted" too (TID-751)
	var scaled: int = scaled_amount(defender, amount, school, tune)
	var dealt: int = 0
	if target is _HeroState:
		var hero: _HeroState = target as _HeroState
		var hp_before: int = hero.health
		hero.note_hit(school, outcome)
		hero.take_damage(scaled)
		dealt = maxi(0, hp_before - hero.health)
	elif target is _CardInstance:
		var card: _CardInstance = target as _CardInstance
		var card_hp_before: int = card.health
		card.note_hit(school, outcome)
		card.take_damage(scaled)
		dealt = maxi(0, card_hp_before - card.health)
	return {"dealt": dealt, "outcome": outcome}

## Scaled amount for HP loss that does not go through `take_damage` (Curse-style
## direct health hits that ignore armor). Same profile and rules as `deal()`.
## GID-181 / TID-755: the hit's school is also multiplied by the battlefield boost
## (`PlayerState.env_school_mult`, the same table on both sides, so it is the attacker's
## school's boost whichever side is hit). The matchup and boost multiply, rounded once.
static func scaled_amount(defender: _PlayerState, amount: int, school: String,
		tune: _CombatTuning = null) -> int:
	var frac: float = resist_fraction(defender, school)
	# Matchup x battlefield boost (TID-755) x hero school resistance (TID-751), rounded once.
	var m: float = (_DamageSchools.mult(school, profile_of(defender), tune) * env_mult(defender, school)
			* (1.0 - frac))
	return _DamageSchools.apply_mult(amount, m)

## Battlefield boost for a hit of `school` on `defender`'s side; 1.0 when none is set.
static func env_mult(defender: _PlayerState, school: String) -> float:
	if defender == null:
		return 1.0
	return float(defender.env_school_mult.get(school, 1.0))

## The hero resistance fraction `defender` has against `school` (0 for none or a null side).
static func resist_fraction(defender: _PlayerState, school: String) -> float:
	if defender == null or defender.hero == null:
		return 0.0
	return _DamageSchools.resist_of(defender.hero.school_resist, school)

## The school profile a side takes damage against; empty (neutral) when there is no side.
static func profile_of(defender: _PlayerState) -> Dictionary:
	if defender == null:
		return {}
	return defender.school_profile
