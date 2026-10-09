## The local player's real-time casting rules (GID-176 / TID-713), pure so the
## balance simulator (`tools/balance_sim.gd`) runs exactly what the game runs.
##
## Owns: the global cooldown gate and spell-queue window (`on_cooldown`), the
## cast state machine (queued delay → cast bar → pushback → fizzle → resolve),
## off-GCD plays, the combo / free-cast payoff on a hand card (GID-139) and the
## technique-card rules (GID-175: cast-time override, Kick / Daze, builder hits).
##
## The scene (`BattleRealtime`) keeps all presentation. It hands `begin` a
## `finish` Callable that plays + resolves the card with its FX, and listens on
## `notify` for feedback events (toasts, procs, stats). The simulator uses
## `play()`, which does the same play + resolve without FX.
##
## Events sent to `notify.call(kind, data)`:
##   "combo"       {n, free}     a hand card spent its combo / free-cast proc
##   "proc"        {}            a builder hit banked a free cast
##   "interrupt"   {name}        Kick interrupted an enemy cast
##   "dazed"       {}            Daze stunned an enemy
##   "fizzled"     {}            the cast's unit target left the board
##   "resolved"    {card, dealt} a cast finished (dealt = enemy HP lost)
##   "technique"   {card, effect} a technique card resolved
##   "returned"    {card}        a technique came back to the hand (GID-178)
extends RefCounted

const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")
const FightStats = preload("res://game_logic/battle/FightStats.gd")
const SpellEffectResolver = preload("res://scenes/battle/SpellEffectResolver.gd")
const SkillMods = preload("res://game_logic/battle/SkillMods.gd")

const SIDE: int = RealtimeCombat.PLAYER

var rt: RealtimeCombat
## Feedback sink (kind: String, data: Dictionary). Empty in the simulator.
var notify: Callable = Callable()

var _card: CardInstance = null
var _left: float = 0.0
var _total: float = 0.0
var _delay: float = 0.0
var _finish: Callable = Callable()
var _target: CardInstance = null
var _pushbacks: int = 0
var _resolving: bool = false
var _last_hp: int = 0
## Resolved techniques waiting to return to the hand: [{card, left}] (GID-178).
## The card sits at the bottom of the draw pile meanwhile, so a saved / resumed
## fight never loses it, and a natural draw simply cancels the return.
var _returning: Array[Dictionary] = []

func _init(combat: RealtimeCombat) -> void:
	rt = combat
	_last_hp = _me().hero.health

func _me() -> PlayerState:
	return rt.state.players[SIDE]

func _emit(kind: String, data: Dictionary = {}) -> void:
	if notify.is_valid():
		notify.call(kind, data)

# --- Global cooldown & casting --------------------------------------------

## True while on global cooldown (outside the queue window) or mid-cast.
func on_cooldown() -> bool:
	return not rt.in_queue_window(SIDE) or _card != null

func is_casting() -> bool:
	return _card != null

## The card being cast (or queued), else null.
func casting_card() -> CardInstance:
	return _card

## Cast bar state: {card, queued, fraction} or {} when idle.
func cast_state() -> Dictionary:
	if _card == null:
		return {}
	var queued: bool = _delay > 0.0 or _total <= 0.0
	return {"card": _card, "queued": queued, "fraction": 0.0 if queued else 1.0 - _left / _total}

## A card play succeeded: start the GCD unless a cast is resolving (its GCD
## already started when the cast began).
func note_play() -> void:
	if not _resolving:
		rt.start_gcd(SIDE)

## Starts a cast of `card`; `finish` plays + resolves it when the cast bar
## completes. `cast_time` < 0 = the technique's own time, else the cost formula.
## A hand card spends the combo (full combo = instant) once it left the hand.
## Returns false while already casting (the caller resolves at once).
func begin(card: CardInstance, finish: Callable, target: CardInstance = null, cast_time: float = -1.0) -> bool:
	if _card != null:
		return false
	if cast_time < 0.0:
		cast_time = TechniqueDefs.cast_time(card.template_id)
	var t: float = maxf(0.0, cast_time if cast_time >= 0.0 else rt.cast_time_for(card.cost))
	var mods := _me().skill_mods
	if mods != null:
		t *= mods.cast_mult(card)
	if not TechniqueDefs.is_technique(card.template_id):
		finish = _with_combo(card, finish)
		if rt.next_card_instant():
			t = 0.0
	if rt.instant_next and t > 0.0:
		t = 0.0
		rt.instant_next = false
	_card = card
	_total = t
	_left = t
	_finish = finish
	_target = target
	_pushbacks = 0
	# Queued inside the spell-queue window: the cast (and its GCD) starts when
	# the current GCD runs out; an instant play resolves on the next tick after.
	_delay = rt.gcd[SIDE]
	if _delay <= 0.0:
		rt.start_gcd(SIDE)
	return true

## GID-139: a hand card spends every combo charge for mana (or its banked free cast).
func _with_combo(card: CardInstance, finish: Callable) -> Callable:
	var me := _me()
	var free: bool = me.next_card_free
	return func() -> void:
		finish.call()
		if me.hand.has(card):
			return
		var n: int = rt.spend_combo()
		if free or n > 0:
			_emit("combo", {"n": n, "free": free})

## Off-GCD play (Kick, Daze): resolves now, neither starting nor waiting on the GCD.
func run_off_gcd(card: CardInstance, finish: Callable) -> void:
	if _card != null:
		return
	_resolving = true
	var foe_hp: int = FightStats.enemy_health(rt)
	finish.call()
	_resolving = false
	_after_technique(card, foe_hp - FightStats.enemy_health(rt))

## Per tick, before `rt.advance`: queue delay, pushback from hits taken since
## the last tick, then resolve a finished cast.
func tick(dt: float) -> void:
	_tick_returns(dt)
	var hp: int = _me().hero.health
	var hit: bool = hp < _last_hp
	_last_hp = hp
	if _card == null:
		return
	if _delay > 0.0:
		_delay -= dt
		if _delay <= 0.0:
			rt.start_gcd(SIDE)
		return
	if hit:
		var add: float = rt.pushback_for_hit(_pushbacks)
		if add > 0.0:
			_left += add
			_total += add
			_pushbacks += 1
	_left -= dt
	if _left > 0.0:
		return
	var finish: Callable = _finish
	var target: CardInstance = _target
	var card: CardInstance = _card
	_card = null
	_finish = Callable()
	_target = null
	if target != null and not (target.is_alive() and rt.owner_of(target) >= 0):
		_emit("fizzled")
		return
	_resolving = true
	var foe_hp: int = FightStats.enemy_health(rt)
	finish.call()
	_resolving = false
	var dealt: int = foe_hp - FightStats.enemy_health(rt)
	_emit("resolved", {"card": card, "dealt": dealt})
	_after_technique(card, dealt)
	_last_hp = _me().hero.health

# --- Technique cards (GID-175) --------------------------------------------

## True for a technique that is off the global cooldown (Kick, Daze).
func is_off_gcd(card: CardInstance) -> bool:
	return TechniqueDefs.off_gcd(card.template_id)

## Why technique `card` can't be played right now, or "".
func technique_blocker(card: CardInstance) -> String:
	if card.template_id == "tech_kick" and casting_enemy() < 0:
		return "Nothing to interrupt"
	if is_off_gcd(card) and _card != null:
		return "Busy casting"
	return ""

## Kick / Daze act on enemy casts instead of their turn-based minion stun /
## freeze. Returns true when it handled `card` (the caller skips the resolver).
func resolve_reactive(card: CardInstance) -> bool:
	match card.template_id:
		"tech_kick":
			var side: int = casting_enemy()
			var cut: CardInstance = rt.interrupt_enemy_cast(side) if side >= 0 else null
			if cut != null:
				_emit("interrupt", {"name": cut.name})
			return true
		"tech_daze":
			var side: int = casting_enemy()
			if side < 0:
				side = rt.target_enemy()
			rt.state.players[side].hero.apply_status("stun", 1)
			rt.interrupt_enemy_cast(side)
			_emit("dazed")
			return true
	return false

## The enemy side to interrupt: your target if it is casting, else any caster (-1 = none).
func casting_enemy() -> int:
	var first: int = rt.target_enemy()
	if first < rt.casting.size() and rt.casting[first] != null:
		return first
	for side: int in rt.enemy_sides():
		if rt.casting[side] != null:
			return side
	return -1

## After a technique resolved: damaging ones are builder hits (siphon, combo,
## proc roll — GID-139).
func _after_technique(card: CardInstance, dealt: int) -> void:
	if card == null or not TechniqueDefs.is_technique(card.template_id):
		return
	if _me().hand.has(card):
		return  # never left the hand (fizzled / refused)
	if dealt > 0 and rt.on_player_hit(dealt, true):
		_emit("proc")
	_emit("technique", {"card": card, "effect": card.spell_effect})
	var recycle: float = TechniqueDefs.recycle_time(card.template_id) * rt.tune.get_f("tech_recycle_mult")
	if _me().skill_mods != null:
		recycle *= _me().skill_mods.recycle_mult(card)
	_returning.append({"card": card, "left": recycle})

## SpellEffectResolver.power_hook (GID-179): a player spell / technique's power
## after skill-tree `mod_power`, then its crit roll and on-crit triggers.
func modify_power(card: CardInstance, caster_pid: int, power: int) -> int:
	if caster_pid != SIDE:
		return power
	var mods := _me().skill_mods
	if mods != null:
		power = mods.power_for(card, power)
	if not SkillMods.can_crit(card) or power <= 0:
		return power
	# The swing crit roll (TID-728) on the same seeded rng, plus `mod_crit` nodes (TID-732).
	var chance: float = rt.tune.get_f("crit_chance") + (0.0 if mods == null else mods.crit_bonus(card))
	if rt.rng.randf() >= chance:
		return power
	var instant: bool = mods != null and mods.instant_on_crit(card)
	var refund: int = 0 if mods == null else mods.refund_on_crit(card)
	if instant:
		rt.instant_next = true
	if refund > 0:
		_me().hero.gain_mana(refund)
	_emit("crit", {"card": card, "instant": instant, "refund": refund})
	return maxi(power + 1, roundi(float(power) * rt.tune.get_f("crit_mult")))

## Seconds until `card` is back in the hand (0 = not waiting).
func return_left(card: CardInstance) -> float:
	for r: Dictionary in _returning:
		if r["card"] == card:
			return maxf(0.0, float(r["left"]))
	return 0.0

## Counts the returns down; a ready technique leaves the draw pile for the hand.
## Returns ignore the hand cap (only draws respect it), so a hand clogged with
## Allies never locks out Strike. Drawn early or gone → dropped from the queue.
func _tick_returns(dt: float) -> void:
	if _returning.is_empty():
		return
	var me := _me()
	for r: Dictionary in _returning.duplicate():
		var card := r["card"] as CardInstance
		if not me.draw_deck.has(card):
			_returning.erase(r)
			continue
		r["left"] = float(r["left"]) - dt
		if float(r["left"]) > 0.0:
			continue
		me.draw_deck.erase(card)
		me.hand.append(card)
		_returning.erase(r)
		_emit("returned", {"card": card})

# --- Headless play (balance simulator) ------------------------------------

## Why `card` can't be played now ("" = it can): the same gates the scene's
## hand tap applies (affordable, a free Ally slot, technique rules, the GCD).
func play_blocker(card: CardInstance) -> String:
	var me := _me()
	if not me.hand.has(card):
		return "Not in hand"
	if not me.can_play(card):
		return "Can't afford"
	if TechniqueDefs.is_technique(card.template_id):
		var why: String = technique_blocker(card)
		if why != "":
			return why
	if not is_off_gcd(card) and on_cooldown():
		return "On cooldown"
	return ""

## Plays `card` the way the scene's input path does, without FX: through the
## cast bar (or off the GCD), then `PlayerState.play_card*` + the resolver.
## `target`: {} (untargeted), {"type": "minion", "card": c} or {"type": "hero"}.
## Minions go to the first free slot. Returns play_blocker's reason or "".
func play(card: CardInstance, resolver: SpellEffectResolver, target: Dictionary = {}) -> String:
	var why: String = play_blocker(card)
	if why != "":
		return why
	var me := _me()
	if card.card_class != "spell":
		var slot: int = me.board.slots.find(null)
		if slot < 0:
			return "Board full"
		begin(card, func() -> void:
			if me.play_card_at_slot(card, slot):
				note_play()
				if card.emergence_effect != "":
					resolver.resolve_emergence(card, SIDE), null, 0.0)
		return ""
	var finish := func() -> void:
		if not me.play_card(card):
			return
		note_play()
		if not resolve_reactive(card):
			resolver.resolve_spell(card, SIDE, target)
	if is_off_gcd(card):
		run_off_gcd(card, finish)
	else:
		begin(card, finish, target.get("card", null) as CardInstance)
	return ""
