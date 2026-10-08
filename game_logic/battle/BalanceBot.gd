## A simple, predictable stand-in for the player in real-time balance runs
## (GID-176 / TID-715). Each tick, `decide()` picks at most one card to play
## through `PlayerCaster` (the same rules the game runs); `act()` plays it.
##
## Deliberately not clever: its job is to compare one setting against another,
## not to predict a skilled human's win rate. Policy, in priority order:
##   1. Kick (else Daze) when an enemy is casting — Daze first on a heavy blow.
##   2. A heal when hero HP is below `heal_below`.
##   3. Summon an Ally when a slot is free.
##   4. The best-value affordable damage / other card (spell power per mana unit).
## Hand order breaks ties, so a seeded fight stays deterministic. Allies attack
## on their own in real time, so the bot never commands them.
extends RefCounted

const PlayerCaster = preload("res://game_logic/battle/PlayerCaster.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const Keywords = preload("res://game_logic/battle/Keywords.gd")
const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")
const SpellEffectResolver = preload("res://scenes/battle/SpellEffectResolver.gd")

const HEALS: Array[String] = ["heal_hero", "heal_all", "drain_hero", "lifesteal_hit"]
## Spells the bot never plays (need a slot / ally pick it doesn't model).
const SKIPPED: Array[String] = ["bless_slot", "ward_slot"]

## Policy knobs (sweepable). heal_below: HP fraction that triggers healing;
## summon: play Allies at all; interrupt: use Kick / Daze.
var policy: Dictionary = {"heal_below": 0.4, "summon": true, "interrupt": true}

func _init(knobs: Dictionary = {}) -> void:
	policy.merge(knobs, true)

## The card to play now and its target ({card, target}), or {} to wait.
func decide(caster: PlayerCaster) -> Dictionary:
	var rt: RealtimeCombat = caster.rt
	var me: PlayerState = rt.state.players[RealtimeCombat.PLAYER]
	var ready: Array[CardInstance] = []
	for c: CardInstance in me.hand:
		if caster.play_blocker(c) == "" and not SKIPPED.has(c.spell_effect) \
				and not SpellEffectResolver.ALLY_TARGETED_EFFECTS.has(c.spell_effect):
			ready.append(c)
	if ready.is_empty():
		return {}
	if bool(policy["interrupt"]) and caster.casting_enemy() >= 0:
		var side: int = caster.casting_enemy()
		var heavy: bool = RealtimeCombat.is_heavy(rt.casting[side] as CardInstance)
		for id: String in (["tech_daze", "tech_kick"] if heavy else ["tech_kick", "tech_daze"]):
			var c: CardInstance = _find(ready, id)
			if c != null:
				return {"card": c, "target": {}}
	var hp_frac: float = float(me.hero.health) / float(maxi(1, me.hero.max_health))
	if hp_frac < float(policy["heal_below"]):
		for c: CardInstance in ready:
			if HEALS.has(c.spell_effect):
				return _with_target(c, rt)
	if bool(policy["summon"]):
		var best_unit: CardInstance = null
		for c: CardInstance in ready:
			if c.card_class != "spell" and (best_unit == null or _unit_value(c) > _unit_value(best_unit)):
				best_unit = c
		if best_unit != null:
			return {"card": best_unit, "target": {}}
	var ranked: Array = []  # [score, hand index, card]
	for i: int in ready.size():
		var c: CardInstance = ready[i]
		if c.card_class != "spell" or c.template_id in ["tech_kick", "tech_daze"] or HEALS.has(c.spell_effect):
			continue
		var power: int = TechniqueDefs.power(c.template_id, c.spell_power, me.hero.mana_scale > 1)
		ranked.append([float(maxi(1, power)) / float(maxi(1, c.cost)), i, c])
	ranked.sort_custom(func(x: Array, y: Array) -> bool:
		return float(x[0]) > float(y[0]) or (float(x[0]) == float(y[0]) and int(x[1]) < int(y[1])))
	for r: Array in ranked:
		var choice: Dictionary = _with_target(r[2] as CardInstance, rt)
		if not choice.is_empty():
			return choice
	return {}

## Decides and plays; returns the played card's template id, or "".
func act(caster: PlayerCaster, resolver: SpellEffectResolver) -> String:
	var d: Dictionary = decide(caster)
	if d.is_empty():
		return ""
	var card := d["card"] as CardInstance
	if caster.play(card, resolver, d["target"] as Dictionary) != "":
		return ""
	return card.template_id

func _find(cards: Array[CardInstance], id: String) -> CardInstance:
	for c: CardInstance in cards:
		if c.template_id == id:
			return c
	return null

func _unit_value(c: CardInstance) -> float:
	return float(c.attack + c.health) / float(maxi(1, c.cost))

## Picks a target the way a sensible player would: enemy Ward minions first,
## else the weakest enemy minion, else the hero; friendly spells pick your
## weakest Ally. {} when the card has nothing sensible to target.
func _with_target(c: CardInstance, rt: RealtimeCombat) -> Dictionary:
	var target: Dictionary = {}
	if SpellEffectResolver.FRIENDLY_TARGETED_EFFECTS.has(c.spell_effect):
		var mine: Array[CardInstance] = rt.state.players[RealtimeCombat.PLAYER].board.get_cards()
		if mine.is_empty():
			return {}
		target = {"type": "minion", "card": _weakest(mine)}
	elif SpellEffectResolver.ENEMY_TARGETED_EFFECTS.has(c.spell_effect):
		target = _enemy_target(c, rt)
		if target.is_empty():
			return {}
	return {"card": c, "target": target}

func _enemy_target(c: CardInstance, rt: RealtimeCombat) -> Dictionary:
	var foes: Array[CardInstance] = rt.state.players[rt.target_enemy()].board.get_cards()
	var wards: Array[CardInstance] = []
	for f: CardInstance in foes:
		if f.keywords.has(Keywords.WARD):
			wards.append(f)
	if not wards.is_empty():
		return {"type": "minion", "card": _weakest(wards)}
	if not foes.is_empty():
		return {"type": "minion", "card": _weakest(foes)}
	# Only plain damage can go at the hero; a minion-only spell waits.
	return {"type": "hero"} if c.spell_effect == "deal_damage_single" else {}

func _weakest(cards: Array[CardInstance]) -> CardInstance:
	var w: CardInstance = cards[0]
	for c: CardInstance in cards:
		if c.health < w.health:
			w = c
	return w
