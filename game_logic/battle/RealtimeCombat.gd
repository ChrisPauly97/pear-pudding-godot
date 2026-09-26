## Real-time combat driver (GID-135 / TID-546 prototype).
##
## Runs a solo 2-player GameState without turns: each side acts on its own
## global cooldown (GCD), mana regenerates on a clock, cards are drawn on a
## clock, and every unit on the board (plus a hero with attack > 0) swings on
## its own timer. Pure logic — no rendering — so tests can drive `advance()`.
##
## The scene keeps `GameState.current_player_idx` pinned to the player (0) so
## the existing hand/targeting input works unchanged; the enemy (1) acts through
## `advance()` events instead of turns. See docs/agent/combat-model.md.
extends RefCounted

const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const Keywords = preload("res://game_logic/battle/Keywords.gd")
const BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")

const PLAYER: int = 0
const ENEMY: int = 1
const CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")

## Every timing, rate and base damage below comes from `tune` (see CombatTuning
## DEFS for defaults and the in-battle tuning panel). Only structural numbers
## stay constants.

## Mana runs in points: MANA_SCALE points per card-cost unit (a 3-cost card costs
## 300), so regen, level and gear can move in small steps (HeroState.mana_scale).
const MANA_SCALE: int = 100
const MANA_CAP: int = 1000
## Board caps in real time: fights lean on the hero and spells, not a wall of units.
## (Structural — the arena layout is built around them.)
const MAX_ALLIES: int = 3
const MAX_ENEMY_MINIONS: int = 2
## Surge units act this soon after being played.
const SURGE_DELAY: float = 0.5

var state: GameState
var tune: CombatTuning
## Seconds of global cooldown left, per side.
var gcd: Array[float] = [0.0, 0.0]
## The player's chosen target (enemy minion) for Ally/hero swings; null = default.
var focus_target: CardInstance = null
## Enemy cast in progress (the telegraph): card being cast and time left.
var enemy_casting: CardInstance = null
var enemy_cast_remaining: float = 0.0
## Off-hand weapon damage per side (0 = no off hand). Set from gear (TID-545).
var offhand_damage: Array[int] = [0, 0]
## Base main-hand damage per side before `hero.attack`.
var unarmed: Array[int] = [0, 0]
## Main-hand swing speed per side (s). 0 = the unarmed speed from `tune`; a weapon
## sets its own (WoW-style: slower weapons hit proportionally harder per swing).
var weapon_speed: Array[float] = [0.0, 0.0]
## Enemy cast pushback hits taken during the current cast.
var enemy_pushbacks: int = 0

## Per-side resource and hero-swing timers.
## Fractional mana points carried between ticks.
var _mana_carry: Array[float] = [0.0, 0.0]
var _draw_timer: Array[float] = [0.0, 0.0]
var _hero_swing: Array[float] = [0.0, 0.0]
var _offhand_swing: Array[float] = [0.0, 0.0]
## Five-second rule: regen is paused this long after spending mana.
var _regen_pause: Array[float] = [0.0, 0.0]
var _last_mana: Array[int] = [0, 0]
var _last_enemy_hp: int = 0
## instance_id -> seconds until next swing
var _swing: Dictionary = {}
## enemy minion instance_id -> true when its next swing goes at an Ally
var _hit_ally_next: Dictionary = {}

## `levels` = [player character level, enemy level-equivalent].
func _init(s: GameState, levels: Array[int] = [1, 1], tuning: CombatTuning = null) -> void:
	state = s
	tune = tuning if tuning != null else CombatTuning.new()
	unarmed = [tune.get_i("unarmed"), tune.get_i("enemy_unarmed")]
	for side in range(2):
		_hero_swing[side] = swing_speed(side)
		_offhand_swing[side] = tune.get_f("offhand_swing")
	state.current_player_idx = PLAYER
	state.players[PLAYER].max_units = MAX_ALLIES
	state.players[ENEMY].max_units = MAX_ENEMY_MINIONS
	for i in range(2):
		var h := state.players[i].hero
		h.mana_scale = MANA_SCALE
		h.max_mana = max_mana_for(levels[i] if i < levels.size() else 1, h.bonus_mana, tune)
		h.mana = h.max_mana
		_last_mana[i] = h.mana
	_last_enemy_hp = state.players[ENEMY].hero.health
	# Units already on the board (pack encounters, resumed state) start mid-swing.
	for i in range(2):
		for c: CardInstance in state.players[i].board.get_cards():
			_swing[c.instance_id] = _unit_interval(i) * 0.5

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
	var side: int = PLAYER if state.players[PLAYER].board.get_cards().has(unit) else ENEMY
	return clampf(1.0 - float(_swing[unit.instance_id]) / _unit_interval(side), 0.0, 1.0)

func _unit_interval(side: int) -> float:
	return tune.get_f("ally_ready") if side == PLAYER else tune.get_f("enemy_swing")

## Advance the clock. Returns events in the order they happened:
##   {"type": "mana"} / {"type": "draw", "side"} /
##   {"type": "swing", "side", "attacker": CardInstance|null (hero), "target": CardInstance|null (hero)} /
##   {"type": "enemy_cast_start", "card"} / {"type": "enemy_cast", "card"} /
##   {"type": "ally_ready", "card"}
## Swings are resolved here (damage applied, dead units removed to discard).
func advance(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if state.is_game_over():
		return events
	for side in range(2):
		gcd[side] = maxf(0.0, gcd[side] - delta)
		_tick_resources(side, delta, events)
	_track_enemy_hits()
	_tick_swings(delta, events)
	if not state.is_game_over():
		_tick_enemy(delta, events)
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
	for side in range(2):
		for c: CardInstance in state.players[side].board.get_cards():
			live[c.instance_id] = true
			if not _swing.has(c.instance_id):
				# Newly played: Surge acts soon, everything else waits a full interval.
				_swing[c.instance_id] = SURGE_DELAY if c.keywords.has(Keywords.SURGE) else _unit_interval(side)
	for k: Variant in _swing.keys():
		if not live.has(k):
			_swing.erase(k)
	for side in range(2):
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
			_resolve_swing(side, c, c.attack, target)
			events.append({"type": "swing", "side": side, "attacker": c, "target": target})
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
	_resolve_swing(side, null, dmg, target)
	events.append({"type": "swing", "side": side, "attacker": null, "hand": hand, "target": target})

## Who `side`'s units hit: a Ward minion must be hit first; otherwise the
## player's focus target (player side only); otherwise the enemy hero (null).
func pick_target(side: int) -> CardInstance:
	var opp: PlayerState = state.players[1 - side]
	var cards: Array[CardInstance] = opp.board.get_cards()
	var wards: Array[CardInstance] = []
	for c: CardInstance in cards:
		if c.keywords.has(Keywords.WARD) and c.is_alive():
			wards.append(c)
	if side == PLAYER and focus_target != null and cards.has(focus_target) and focus_target.is_alive():
		if wards.is_empty() or wards.has(focus_target):
			return focus_target
	if not wards.is_empty():
		return wards[0]
	return null

## Enemy minions alternate between the player's hero and an Ally (the one with
## the least health), so Allies soak hits and a board of them is worth guarding.
func pick_minion_target(minion: CardInstance) -> CardInstance:
	var forced: CardInstance = pick_target(ENEMY)
	if forced != null:
		return forced
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

## Interrupt: cancels the enemy's cast (the card stays in its hand, no mana
## spent) and puts the enemy on its global cooldown. Returns the interrupted
## card, or null when nothing was being cast.
func interrupt_enemy_cast() -> CardInstance:
	var card: CardInstance = enemy_casting
	if card == null:
		return null
	enemy_casting = null
	enemy_pushbacks = 0
	start_gcd(ENEMY)
	return card

## Damage to the enemy hero during its cast pushes the cast back.
func _track_enemy_hits() -> void:
	var hp: int = state.players[ENEMY].hero.health
	if hp < _last_enemy_hp and enemy_casting != null:
		var add: float = pushback_for_hit(enemy_pushbacks)
		if add > 0.0:
			enemy_cast_remaining += add
			enemy_pushbacks += 1
	_last_enemy_hp = hp

## One-way hit: in real time the target answers on its own swing timer,
## so there is no Hearthstone-style retaliation damage.
func _resolve_swing(side: int, attacker: CardInstance, dmg: int, target: CardInstance) -> void:
	var opp: PlayerState = state.players[1 - side]
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

func _tick_enemy(delta: float, events: Array[Dictionary]) -> void:
	var ai: PlayerState = state.players[ENEMY]
	if enemy_casting != null:
		enemy_cast_remaining -= delta
		if enemy_cast_remaining > 0.0:
			return
		var card: CardInstance = enemy_casting
		enemy_casting = null
		enemy_pushbacks = 0
		if ai.hand.has(card) and ai.can_play(card) and ai.play_card(card):
			events.append({"type": "enemy_cast", "card": card})
		start_gcd(ENEMY)
		return
	if not gcd_ready(ENEMY):
		return
	var pick: CardInstance = choose_enemy_card()
	if pick == null:
		return
	enemy_casting = pick
	enemy_pushbacks = 0
	enemy_cast_remaining = tune.get_f("enemy_cast")
	events.append({"type": "enemy_cast_start", "card": pick})

## Enemy picks the most expensive unit it can afford. Enemy spells are skipped:
## the turn-based AI plays them without resolving an effect, so the prototype
## does not spend mana on them. Heuristic only — AI personas apply in TID-541.
func choose_enemy_card() -> CardInstance:
	var ai: PlayerState = state.players[ENEMY]
	var best: CardInstance = null
	for c: CardInstance in ai.hand:
		if c.card_class == "spell" or not ai.can_play(c):
			continue
		if best == null or ai.effective_cost(c) > ai.effective_cost(best):
			best = c
	return best
