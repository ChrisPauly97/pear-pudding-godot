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
## on their own in real time, so the bot never commands them. With `focus` on it
## taps the weakest enemy minion as its auto-attack focus (what a player does
## against a pack, TID-718), else leaves swings on the hero.
##
## Policy variety (GID-187 / TID-784): the knobs `react`, `kick_miss` and `think`
## default to 0 (off), which is exactly the policy above. The `casual` preset turns
## them on: it answers a telegraphed cast or heavy blow only `react` seconds after
## first seeing it, whiffs `kick_miss` of its interrupts (one seeded roll per cast on
## the fight's rng), waits `think` seconds between plays and never swaps focus.
## `preset(name)` gives a full knob dictionary; `tools/balance_sim.gd --bot casual`.
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
## summon: play Allies at all; interrupt: use Kick / Daze; focus: auto-attack the
## weakest enemy minion; react: seconds to see a cast before answering it; kick_miss:
## chance an interrupt whiffs; think: seconds between plays (0 = as fast as the GCD).
const DEFAULT_POLICY: Dictionary = {"heal_below": 0.4, "summon": true, "interrupt": true, "focus": true,
	"react": 0.0, "kick_miss": 0.0, "think": 0.0}
## Named policies. Knobs not listed take DEFAULT_POLICY's value.
const PRESETS: Dictionary = {
	"default": {},
	"casual": {"focus": false, "react": 0.5, "kick_miss": 0.2, "think": 1.0},
}

var policy: Dictionary = DEFAULT_POLICY.duplicate()
## Fight clock, advanced by `act(…, dt)`; drives `react` and `think`.
var _clock: float = 0.0
## The enemy cast first seen at `_seen_at`, and whether its interrupt roll was made.
var _seen: CardInstance = null
var _seen_at: float = 0.0
var _rolled: bool = false
var _whiffed: bool = false
## Clock time of the bot's next play (`think`).
var _next_play: float = 0.0

func _init(knobs: Dictionary = {}) -> void:
	policy.merge(knobs, true)

## Every knob with its value for the named policy (unknown names give the default).
static func preset(name: String) -> Dictionary:
	var out: Dictionary = DEFAULT_POLICY.duplicate()
	out.merge(PRESETS.get(name, {}) as Dictionary, true)
	return out

static func has_preset(name: String) -> bool:
	return PRESETS.has(name)

## Records the enemy cast the bot can see now (null = none). A new cast restarts the reaction clock.
func _sight(cast: CardInstance) -> void:
	if cast == _seen:
		return
	_seen = cast
	_seen_at = _clock
	_rolled = false
	_whiffed = false

## True once the bot has reacted for `react` seconds to the cast it is looking at.
func _reacted() -> bool:
	var react: float = float(policy["react"])
	return react <= 0.0 or _clock - _seen_at >= react - 0.001

## True unless this cast's interrupt whiffs (`kick_miss`, rolled once per cast on the fight rng).
func _kick_lands(rt: RealtimeCombat) -> bool:
	var miss: float = float(policy["kick_miss"])
	if miss <= 0.0:
		return true
	if not _rolled:
		_rolled = true
		_whiffed = rt.rng.randf() < miss
	return not _whiffed

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
		var cast: CardInstance = rt.casting[side] as CardInstance
		_sight(cast)
		var heavy: bool = RealtimeCombat.is_heavy(cast)
		for id: String in (["tech_daze", "tech_kick"] if heavy else ["tech_kick", "tech_daze"]):
			var c: CardInstance = _find(ready, id)
			if c != null:
				if _reacted() and _kick_lands(rt):
					return {"card": c, "target": {}}
				break
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

## Decides and plays; returns the played card's template id, or "". `dt` is the
## seconds since the last call (the fight's tick); it advances the bot's clock.
func act(caster: PlayerCaster, resolver: SpellEffectResolver, dt: float = 0.0) -> String:
	_clock += dt
	if caster.casting_enemy() < 0:
		_sight(null)
	else:
		_sight(caster.rt.casting[caster.casting_enemy()] as CardInstance)
	if bool(policy["focus"]):
		_focus(caster.rt)
	if _clock < _next_play:
		return ""
	var d: Dictionary = decide(caster)
	if d.is_empty():
		return ""
	var card := d["card"] as CardInstance
	if caster.play(card, resolver, d["target"] as Dictionary) != "":
		return ""
	_next_play = _clock + float(policy["think"])
	return card.template_id

## Keeps the auto-attack focus on the weakest living enemy minion (null = hero).
func _focus(rt: RealtimeCombat) -> void:
	if rt.focus_target != null and rt.focus_target.is_alive():
		return
	var foes: Array[CardInstance] = []
	for c: CardInstance in rt.state.players[rt.target_enemy()].board.get_cards():
		if c.is_alive():
			foes.append(c)
	rt.focus_target = _weakest(foes) if not foes.is_empty() else null

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
	return {"type": "hero"} if SpellEffectResolver.HERO_TARGETABLE_EFFECTS.has(c.spell_effect) else {}

func _weakest(cards: Array[CardInstance]) -> CardInstance:
	var w: CardInstance = cards[0]
	for c: CardInstance in cards:
		if c.health < w.health:
			w = c
	return w
