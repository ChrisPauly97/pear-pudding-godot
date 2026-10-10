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
	var profile: Dictionary = profile_of(defender)
	var outcome: String = _DamageSchools.outcome(school, profile)
	var scaled: int = _DamageSchools.scale(amount, school, profile, tune)
	var dealt: int = 0
	if target is _HeroState:
		var hero: _HeroState = target as _HeroState
		var hp_before: int = hero.health
		hero.take_damage(scaled)
		dealt = maxi(0, hp_before - hero.health)
	elif target is _CardInstance:
		var card: _CardInstance = target as _CardInstance
		var card_hp_before: int = card.health
		card.take_damage(scaled)
		dealt = maxi(0, card_hp_before - card.health)
	return {"dealt": dealt, "outcome": outcome}

## Scaled amount for HP loss that does not go through `take_damage` (Curse-style
## direct health hits that ignore armor). Same profile and rules as `deal()`.
static func scaled_amount(defender: _PlayerState, amount: int, school: String,
		tune: _CombatTuning = null) -> int:
	return _DamageSchools.scale(amount, school, profile_of(defender), tune)

## The school profile a side takes damage against; empty (neutral) when there is no side.
static func profile_of(defender: _PlayerState) -> Dictionary:
	if defender == null:
		return {}
	return defender.school_profile
