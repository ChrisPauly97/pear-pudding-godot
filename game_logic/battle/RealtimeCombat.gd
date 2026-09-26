## Real-time combat driver (GID-135 / TID-546, multi-enemy TID-551).
##
## Runs a solo GameState without turns: every side acts on its own global
## cooldown (GCD), mana regenerates on a clock, cards are drawn on a clock, and
## every unit on the board (plus each hero) swings on its own timer. Pure logic
## — no rendering — so tests can drive `advance()`.
##
## Sides: players[0] is you; players[1..] are enemies. A second enemy can join a
## running fight (`add_enemy`, a WoW "add"); the state then becomes a team
## battle (teams [0, 1, 1, …]) so GameState's win rules end the fight only when
## every enemy hero is down. The scene keeps `current_player_idx` pinned to 0 so
## the existing hand/targeting input works unchanged; enemies act through
## `advance()` events instead of turns. See docs/agent/combat-model.md.
extends RefCounted

const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const Keywords = preload("res://game_logic/battle/Keywords.gd")
const BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")
const CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")

const PLAYER: int = 0
## The first (original) enemy. Adds get later indices.
const ENEMY: int = 1

## Every timing, rate and base damage comes from `tune` (see CombatTuning DEFS
## and the in-battle tuning panel). Only structural numbers stay constants.

## Mana runs in points: MANA_SCALE points per card-cost unit (a 3-cost card costs
## 300), so regen, level and gear can move in small steps (HeroState.mana_scale).
const MANA_SCALE: int = 100
const MANA_CAP: int = 1000
## Board caps in real time: fights lean on the hero and spells, not a wall of units.
## (Structural — the arena layout is built around them.)
const MAX_ALLIES: int = 3
const MAX_ENEMY_MINIONS: int = 2
## At most this many enemy heroes in one fight (the original + one add).
const MAX_ENEMIES: int = 2
## Surge units act this soon after being played.
const SURGE_DELAY: float = 0.5

var state: GameState
var tune: CombatTuning
## Seconds of global cooldown left, per side.
var gcd: Array[float] = []
## The player's chosen target (any enemy's minion) for hero swings; null = default.
var focus_target: CardInstance = null
## Enemy hero your auto-attack goes at when no minion is focused (-1 = first alive).
var focus_enemy: int = -1
## Per side: card being cast (the telegraph), seconds left, pushback hits so far.
var casting: Array = []
var cast_remaining: Array[float] = []
var pushbacks: Array[int] = []
## Off-hand weapon damage per side (0 = no off hand). Set from gear (TID-545).
var offhand_damage: Array[int] = []
## Base main-hand damage per side before `hero.attack`.
var unarmed: Array[int] = []
## Main-hand swing speed per side (s). 0 = the unarmed speed from `tune`; a weapon
## sets its own (WoW-style: slower weapons hit proportionally harder per swing).
var weapon_speed: Array[float] = []

## The original enemy's cast — kept as properties for callers from before adds.
var enemy_casting: CardInstance:
	get:
		return casting[ENEMY] as CardInstance
	set(v):
		casting[ENEMY] = v
var enemy_cast_remaining: float:
	get:
		return cast_remaining[ENEMY]
	set(v):
		cast_remaining[ENEMY] = v
var enemy_pushbacks: int:
	get:
		return pushbacks[ENEMY]
	set(v):
		pushbacks[ENEMY] = v

## Per-side resource and hero-swing timers.
var _mana_carry: Array[float] = []
var _draw_timer: Array[float] = []
var _hero_swing: Array[float] = []
var _offhand_swing: Array[float] = []
## Five-second rule: regen is paused this long after spending mana.
var _regen_pause: Array[float] = []
var _last_mana: Array[int] = []
var _last_hp: Array[int] = []
## instance_id -> seconds until next swing
var _swing: Dictionary = {}
## enemy minion instance_id -> true when its next swing goes at an Ally
var _hit_ally_next: Dictionary = {}

## `levels` = [player character level, enemy level-equivalent].
func _init(s: GameState, levels: Array[int] = [1, 1], tuning: CombatTuning = null) -> void:
	state = s
	tune = tuning if tuning != null else CombatTuning.new()
	state.current_player_idx = PLAYER
	for i in range(state.players.size()):
		_init_side(i, levels[i] if i < levels.size() else 1)

## Sets up per-side timers and mana for players[i] (you or an enemy).
func _init_side(i: int, level: int) -> void:
	gcd.append(0.0)
	casting.append(null)
	cast_remaining.append(0.0)
	pushbacks.append(0)
	offhand_damage.append(0)
	unarmed.append(tune.get_i("unarmed") if i == PLAYER else tune.get_i("enemy_unarmed"))
	weapon_speed.append(0.0)
	_mana_carry.append(0.0)
	_draw_timer.append(0.0)
	_regen_pause.append(0.0)
	_hero_swing.append(0.0)
	_offhand_swing.append(tune.get_f("offhand_swing"))
	_hero_swing[i] = swing_speed(i)
	var p: PlayerState = state.players[i]
	p.max_units = MAX_ALLIES if i == PLAYER else MAX_ENEMY_MINIONS
	var h := p.hero
	h.mana_scale = MANA_SCALE
	h.max_mana = max_mana_for(level, h.bonus_mana, tune)
	h.mana = h.max_mana
	_last_mana.append(h.mana)
	_last_hp.append(h.health)
	# Units already on the board (pack encounters, resumed state) start mid-swing.
	for c: CardInstance in p.board.get_cards():
		_swing[c.instance_id] = _unit_interval(i) * 0.5

## A second enemy joins the fight (a WoW "add"). `ps` is a fresh PlayerState with
## its deck built and opening hand drawn. The state becomes a team battle (you
## vs every enemy); returns the new side's index, or -1 when the fight is full.
func add_enemy(ps: PlayerState, level: int = 1) -> int:
	if enemy_sides().size() >= MAX_ENEMIES or state.is_game_over():
		return -1
	var idx: int = state.players.size()
	ps.player_id = idx
	ps.is_ai = true
	ps.battlefield_biome = state.battlefield_biome
	ps.is_night = state.is_night
	ps.gamebus_emitter = state.gamebus_emitter
	state.players.append(ps)
	state.team_battle = true
	state.player_teams.clear()
	for i in range(state.players.size()):
		state.player_teams.append(0 if i == PLAYER else 1)
	while state.player_turn_numbers.size() < state.players.size():
		state.player_turn_numbers.append(0)
	_init_side(idx, level)
	# The add arrives mid-swing so it doesn't hit on the frame it appears.
	_hero_swing[idx] = swing_speed(idx) * 0.5
	start_gcd(idx)
	return idx

## Every enemy side, alive or not.
func enemy_sides() -> Array[int]:
	var out: Array[int] = []
	for i in range(1, state.players.size()):
		out.append(i)
	return out

func is_alive(side: int) -> bool:
	return side >= 0 and side < state.players.size() and state.players[side].hero.is_alive()

## The enemy your hero goes at by default: `focus_enemy` if alive, else the first alive enemy.
func target_enemy() -> int:
	if is_alive(focus_enemy) and focus_enemy != PLAYER:
		return focus_enemy
	for i: int in enemy_sides():
		if is_alive(i):
			return i
	return ENEMY

## Index of the side whose board holds `c` (-1 if none).
func owner_of(c: CardInstance) -> int:
	for i in range(state.players.size()):
		if state.players[i].board.get_cards().has(c):
			return i
	return -1

## Pure: fixed max mana (points) for a character level plus gear/skill bonus
## mana (cost units, ×MANA_SCALE).
static func max_mana_for(level: int, bonus_mana: int = 0, tuning: CombatTuning = null) -> int:
	var t: CombatTuning = tuning if tuning != null else CombatTuning.new()
	var from_level: int = t.get_i("base_max_mana") + maxi(0, level - 1) * t.get_i("mana_per_level")
	return mini(MANA_CAP, from_level + maxi(0, bonus_mana) * MANA_SCALE)

## Starts `side`'s global cooldown. Call after every card that side plays.
func start_gcd(side: int) -> void:
	gcd[side] = _gcd_total(side)

func _gcd_total(side: int) -> float:
	return tune.get_f("player_gcd") if side == PLAYER else tune.get_f("enemy_gcd")

func gcd_ready(side: int) -> bool:
	return gcd[side] <= 0.0

## Progress 0..1 of `side`'s GCD (1 = ready), for UI sweeps.
func gcd_fraction(side: int) -> float:
	return clampf(1.0 - gcd[side] / _gcd_total(side), 0.0, 1.0)

## Spell queue: within this many seconds of the GCD ending, the next play is
## accepted and starts the moment the GCD ends (WoW's spell queue window).
func in_queue_window(side: int) -> bool:
	return gcd[side] <= tune.get_f("spell_queue")

## Progress 0..1 until `unit` swings (1 = about to swing).
func swing_fraction(unit: CardInstance) -> float:
	if not _swing.has(unit.instance_id):
		return 0.0
	var side: int = owner_of(unit)
	return clampf(1.0 - float(_swing[unit.instance_id]) / _unit_interval(side), 0.0, 1.0)

func _unit_interval(side: int) -> float:
	return tune.get_f("ally_ready") if side == PLAYER else tune.get_f("enemy_swing")

## Advance the clock. Returns events in the order they happened:
##   {"type": "mana", "side"} / {"type": "draw", "side"} /
##   {"type": "swing", "side", "attacker": CardInstance|null (hero), "target": CardInstance|null (hero),
##    "target_side"} / {"type": "enemy_cast_start", "side", "card"} / {"type": "enemy_cast", "side", "card"} /
##   {"type": "ally_ready", "card"} / {"type": "enemy_down", "side"}
## Swings are resolved here (damage applied, dead units removed to discard).
func advance(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if state.is_game_over():
		return events
	for side in range(state.players.size()):
		gcd[side] = maxf(0.0, gcd[side] - delta)
		if is_alive(side):
			_tick_resources(side, delta, events)
	_track_enemy_hits()
	_tick_swings(delta, events)
	for side: int in enemy_sides():
		if state.is_game_over():
			break
		if is_alive(side):
			_tick_enemy(side, delta, events)
	_clear_fallen_enemies(events)
	return events

func _tick_resources(side: int, delta: float, events: Array[Dictionary]) -> void:
	var p: PlayerState = state.players[side]
	var h := p.hero
	# Five-second rule: any spend since the last tick pauses regen for a while.
	if h.mana < _last_mana[side]:
		_regen_pause[side] = tune.get_f("mana_regen_delay")
		_mana_carry[side] = 0.0
	_regen_pause[side] = maxf(0.0, _regen_pause[side] - delta)
	if h.mana < h.max_mana and _regen_pause[side] <= 0.0:
		_mana_carry[side] += delta * tune.get_f("mana_regen")
		var whole: int = int(_mana_carry[side])
		_mana_carry[side] -= whole
		var before_units: int = h.mana / h.mana_scale
		h.mana = mini(h.max_mana, h.mana + whole)
		# Only a whole cost unit changes what's affordable — emit then, not per point.
		if h.mana / h.mana_scale != before_units:
			events.append({"type": "mana", "side": side})
	elif h.mana >= h.max_mana:
		_mana_carry[side] = 0.0
	_last_mana[side] = h.mana
	_draw_timer[side] += delta
	if _draw_timer[side] >= tune.get_f("draw_interval"):
		_draw_timer[side] -= tune.get_f("draw_interval")
		if p.hand.size() < tune.get_i("hand_cap"):
			p.draw_card(false)
			events.append({"type": "draw", "side": side})

func _tick_swings(delta: float, events: Array[Dictionary]) -> void:
	var live: Dictionary = {}
	for side in range(state.players.size()):
		for c: CardInstance in state.players[side].board.get_cards():
			live[c.instance_id] = true
			if not _swing.has(c.instance_id):
				# Newly played: Surge acts soon, everything else waits a full interval.
				_swing[c.instance_id] = SURGE_DELAY if c.keywords.has(Keywords.SURGE) else _unit_interval(side)
	for k: Variant in _swing.keys():
		if not live.has(k):
			_swing.erase(k)
	for side in range(state.players.size()):
		if not is_alive(side):
			continue
		var board_cards: Array[CardInstance] = state.players[side].board.get_cards().duplicate()
		for c: CardInstance in board_cards:
			if state.is_game_over():
				return
			if not c.is_alive() or c.out_of_play > 0 or c.has_status("freeze"):
				continue
			if side == PLAYER:
				_tick_ally(c, delta, events)
				continue
			var left: float = float(_swing[c.instance_id]) - delta
			if left > 0.0:
				_swing[c.instance_id] = left
				continue
			_swing[c.instance_id] = tune.get_f("enemy_swing") + left
			if c.attack <= 0:
				continue
			var target: CardInstance = pick_minion_target(c)
			_resolve_swing(c, c.attack, target, PLAYER)
			events.append({"type": "swing", "side": side, "attacker": c, "target": target, "target_side": PLAYER})
		_tick_hero(side, delta, events)

## Ally readiness: a ready Ally (can_attack) waits for the player's command;
## otherwise its timer runs and, on expiry, the Ally becomes ready.
func _tick_ally(c: CardInstance, delta: float, events: Array[Dictionary]) -> void:
	if c.can_attack():
		_swing[c.instance_id] = tune.get_f("ally_ready")
		return
	var left: float = float(_swing[c.instance_id]) - delta
	if left > 0.0:
		_swing[c.instance_id] = left
		return
	_swing[c.instance_id] = tune.get_f("ally_ready")
	c.summoning_sick = false
	c.attack_count = maxi(1, c.attack_count)
	events.append({"type": "ally_ready", "card": c})

## Main-hand swing interval for `side` (s): the weapon's speed, else unarmed.
func swing_speed(side: int) -> float:
	return weapon_speed[side] if weapon_speed[side] > 0.0 else tune.get_f("hero_swing")

## Main-hand damage per swing for `side` (0 = this hero doesn't auto-attack).
## Scaled by swing speed ÷ unarmed speed, so a slow two-hander hits harder per
## swing and a dagger lighter, at roughly the same damage per second.
func main_hand_damage(side: int) -> int:
	var base: int = state.players[side].hero.attack + unarmed[side]
	if base <= 0:
		return 0
	return maxi(1, roundi(float(base) * swing_speed(side) / tune.get_f("hero_swing")))

## Progress 0..1 of `side`'s main-hand swing (1 = about to swing).
func hero_swing_fraction(side: int) -> float:
	return clampf(1.0 - _hero_swing[side] / swing_speed(side), 0.0, 1.0)

func _tick_hero(side: int, delta: float, events: Array[Dictionary]) -> void:
	var hero := state.players[side].hero
	if not hero.is_alive() or hero.has_status("freeze") or hero.has_status("stun"):
		return
	var main: int = main_hand_damage(side)
	if main > 0:
		_hero_swing[side] -= delta
		if _hero_swing[side] <= 0.0:
			_hero_swing[side] += swing_speed(side)
			_hero_hit(side, main, "main", events)
	if offhand_damage[side] > 0 and not state.is_game_over():
		_offhand_swing[side] -= delta
		if _offhand_swing[side] <= 0.0:
			_offhand_swing[side] += tune.get_f("offhand_swing")
			_hero_hit(side, offhand_damage[side], "off", events)

func _hero_hit(side: int, dmg: int, hand: String, events: Array[Dictionary]) -> void:
	var target: CardInstance = pick_target(side)
	var target_side: int = owner_of(target) if target != null else (target_enemy() if side == PLAYER else PLAYER)
	_resolve_swing(null, dmg, target, target_side)
	events.append({"type": "swing", "side": side, "attacker": null, "hand": hand, "target": target,
		"target_side": target_side})

## Who `side`'s hero hits (null = the opposing hero). You: a Ward minion on the
## targeted enemy's board first; else your focused minion; else that enemy's hero.
## An enemy: a Ward Ally first, else your hero.
func pick_target(side: int) -> CardInstance:
	if side == PLAYER and focus_target != null and focus_target.is_alive():
		var fo: int = owner_of(focus_target)
		if fo > PLAYER and _wards(fo).is_empty() or _wards(fo).has(focus_target):
			return focus_target
	var opp: int = target_enemy() if side == PLAYER else PLAYER
	var wards: Array[CardInstance] = _wards(opp)
	return wards[0] if not wards.is_empty() else null

func _wards(side: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	if side < 0:
		return out
	for c: CardInstance in state.players[side].board.get_cards():
		if c.keywords.has(Keywords.WARD) and c.is_alive():
			out.append(c)
	return out

## Enemy minions alternate between the player's hero and an Ally (the one with
## the least health), so Allies soak hits and a board of them is worth guarding.
func pick_minion_target(minion: CardInstance) -> CardInstance:
	var forced: Array[CardInstance] = _wards(PLAYER)
	if not forced.is_empty():
		return forced[0]
	var allies: Array[CardInstance] = state.players[PLAYER].board.get_cards()
	var go_ally: bool = not bool(_hit_ally_next.get(minion.instance_id, false))
	_hit_ally_next[minion.instance_id] = go_ally
	if not go_ally or allies.is_empty():
		return null
	var weakest: CardInstance = allies[0]
	for a: CardInstance in allies:
		if a.health < weakest.health:
			weakest = a
	return weakest

## Seconds to cast a `units`-cost card (0 = instant).
func cast_time_for(units: int) -> float:
	if units <= 0:
		return 0.0
	return minf(tune.get_f("cast_max"), tune.get_f("cast_base") + tune.get_f("cast_per_cost") * float(units))

## Pushback: each hit on a casting hero delays the cast, up to a few hits per cast.
## Returns the seconds added (0 once the cap is reached).
func pushback_for_hit(hits_so_far: int) -> float:
	return tune.get_f("cast_pushback") if hits_so_far < tune.get_i("pushback_max_hits") else 0.0

## Interrupt: cancels `side`'s cast (the card stays in its hand, no mana spent)
## and puts it on its global cooldown. Returns the interrupted card, or null.
func interrupt_enemy_cast(side: int = ENEMY) -> CardInstance:
	if side < 0 or side >= casting.size():
		return null
	var card: CardInstance = casting[side] as CardInstance
	if card == null:
		return null
	casting[side] = null
	pushbacks[side] = 0
	start_gcd(side)
	return card

## Damage to a casting enemy hero pushes its cast back.
func _track_enemy_hits() -> void:
	for side: int in enemy_sides():
		var hp: int = state.players[side].hero.health
		if hp < _last_hp[side] and casting[side] != null:
			var add: float = pushback_for_hit(pushbacks[side])
			if add > 0.0:
				cast_remaining[side] += add
				pushbacks[side] += 1
		_last_hp[side] = hp

## One-way hit: in real time the target answers on its own swing timer,
## so there is no Hearthstone-style retaliation damage.
func _resolve_swing(attacker: CardInstance, dmg: int, target: CardInstance, target_side: int) -> void:
	var opp: PlayerState = state.players[target_side]
	var d: int = BattlefieldRules.modify_damage(dmg, state.battlefield_biome)
	if target == null:
		opp.hero.take_damage(d)
		return
	target.take_damage(d)
	if not target.is_alive():
		if attacker != null:
			attacker.battle_kills += 1
		opp.board.remove_card(target)
		opp.discard.append(target)
		if focus_target == target:
			focus_target = null

## A fallen enemy's minions flee and its cast fizzles, so the fight carries on
## against whoever is left.
func _clear_fallen_enemies(events: Array[Dictionary]) -> void:
	for side: int in enemy_sides():
		var p: PlayerState = state.players[side]
		if p.hero.is_alive() or (p.board.get_cards().is_empty() and casting[side] == null):
			continue
		for c: CardInstance in p.board.get_cards().duplicate():
			p.board.remove_card(c)
			p.discard.append(c)
		casting[side] = null
		if focus_target != null and owner_of(focus_target) < 0:
			focus_target = null
		events.append({"type": "enemy_down", "side": side})

func _tick_enemy(side: int, delta: float, events: Array[Dictionary]) -> void:
	var ai: PlayerState = state.players[side]
	if casting[side] != null:
		cast_remaining[side] -= delta
		if cast_remaining[side] > 0.0:
			return
		var card: CardInstance = casting[side] as CardInstance
		casting[side] = null
		pushbacks[side] = 0
		if ai.hand.has(card) and ai.can_play(card) and ai.play_card(card):
			events.append({"type": "enemy_cast", "side": side, "card": card})
		start_gcd(side)
		return
	if not gcd_ready(side):
		return
	var pick: CardInstance = choose_enemy_card(side)
	if pick == null:
		return
	casting[side] = pick
	pushbacks[side] = 0
	cast_remaining[side] = tune.get_f("enemy_cast")
	events.append({"type": "enemy_cast_start", "side": side, "card": pick})

## An enemy picks the most expensive unit it can afford. Enemy spells are skipped:
## the turn-based AI plays them without resolving an effect, so the prototype
## does not spend mana on them. Heuristic only — AI personas apply in TID-541.
func choose_enemy_card(side: int = ENEMY) -> CardInstance:
	var ai: PlayerState = state.players[side]
	var best: CardInstance = null
	for c: CardInstance in ai.hand:
		if c.card_class == "spell" or not ai.can_play(c):
			continue
		if best == null or ai.effective_cost(c) > ai.effective_cost(best):
			best = c
	return best
