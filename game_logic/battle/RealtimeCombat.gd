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

## Seconds after any card play before that side can play again.
const PLAYER_GCD: float = 1.5
const ENEMY_GCD: float = 3.5
## Enemy "cast bar": telegraph time between choosing a card and playing it.
const ENEMY_CAST_TIME: float = 1.5
## Mana runs in points: MANA_SCALE points per card-cost unit (a 3-cost card costs
## 300), so regen, level and gear can move in small steps (HeroState.mana_scale).
const MANA_SCALE: int = 100
## Max mana is fixed for the whole fight (WoW-style): it comes from character
## level plus `hero.bonus_mana` (gear / passive skills, in cost units), never
## from fight time. Level 1 = BASE_MAX_MANA, +MANA_PER_LEVEL each level after.
const BASE_MAX_MANA: int = 400
const MANA_PER_LEVEL: int = 35
const MANA_CAP: int = 1000
## You start full, then regenerate continuously at MANA_REGEN_PER_SEC (1 cost unit / 2 s).
const MANA_REGEN_PER_SEC: float = 50.0
## One card drawn every DRAW_INTERVAL while the hand is below HAND_CAP.
const DRAW_INTERVAL: float = 6.0
const HAND_CAP: int = 7
## Player Allies don't auto-attack: they become *ready* every ALLY_READY_INTERVAL
## (a fresh Ally waits one interval; Surge is ready at once) and the player
## commands the attack — tap the Ally, then a target — off the global cooldown,
## through the normal attack path (lunge + retaliation). Ready Allies wait.
const ALLY_READY_INTERVAL: float = 3.0
## Enemy minions auto-attack on their own, slower, schedule.
const ENEMY_SWING_INTERVAL: float = 4.5
## Hero auto-attack (WoW-style, always on): main hand every HERO_SWING_INTERVAL,
## off hand on its own OFFHAND_SWING_INTERVAL timer when `offhand_damage` > 0.
## The player's main hand always deals at least UNARMED_DAMAGE on top of
## `hero.attack` (weapon/passive bonuses), so an empty mana bar is never idle.
## Enemy heroes swing only with `hero.attack` > 0 (summoners fight through units).
const HERO_SWING_INTERVAL: float = 3.0
const OFFHAND_SWING_INTERVAL: float = 2.0
const UNARMED_DAMAGE: int = 2

var state: GameState
## Seconds of global cooldown left, per side.
var gcd: Array[float] = [0.0, 0.0]
## The player's chosen target (enemy minion) for Ally/hero swings; null = default.
var focus_target: CardInstance = null
## Enemy cast in progress (the telegraph): card being cast and time left.
var enemy_casting: CardInstance = null
var enemy_cast_remaining: float = 0.0
## Off-hand weapon damage per side (0 = no off hand). Set from gear (TID-545).
var offhand_damage: Array[int] = [0, 0]

## Per-side resource and hero-swing timers.
## Fractional mana points carried between ticks.
var _mana_carry: Array[float] = [0.0, 0.0]
var _draw_timer: Array[float] = [0.0, 0.0]
var _hero_swing: Array[float] = [HERO_SWING_INTERVAL, HERO_SWING_INTERVAL]
var _offhand_swing: Array[float] = [OFFHAND_SWING_INTERVAL, OFFHAND_SWING_INTERVAL]
## instance_id -> seconds until next swing
var _swing: Dictionary = {}

## `levels` = [player character level, enemy level-equivalent].
func _init(s: GameState, levels: Array[int] = [1, 1]) -> void:
	state = s
	state.current_player_idx = PLAYER
	for i in range(2):
		var h := state.players[i].hero
		h.mana_scale = MANA_SCALE
		h.max_mana = max_mana_for(levels[i] if i < levels.size() else 1, h.bonus_mana)
		h.mana = h.max_mana
	# Units already on the board (pack encounters, resumed state) start mid-swing.
	for i in range(2):
		for c: CardInstance in state.players[i].board.get_cards():
			_swing[c.instance_id] = _unit_interval(i) * 0.5

## Pure: fixed max mana (points) for a character level plus gear/skill bonus
## mana (cost units, ×MANA_SCALE).
static func max_mana_for(level: int, bonus_mana: int = 0) -> int:
	var from_level: int = BASE_MAX_MANA + maxi(0, level - 1) * MANA_PER_LEVEL
	return mini(MANA_CAP, from_level + maxi(0, bonus_mana) * MANA_SCALE)

## Starts `side`'s global cooldown. Call after every card that side plays.
func start_gcd(side: int) -> void:
	gcd[side] = PLAYER_GCD if side == PLAYER else ENEMY_GCD

func gcd_ready(side: int) -> bool:
	return gcd[side] <= 0.0

## Progress 0..1 of `side`'s GCD (1 = ready), for UI sweeps.
func gcd_fraction(side: int) -> float:
	var total: float = PLAYER_GCD if side == PLAYER else ENEMY_GCD
	return clampf(1.0 - gcd[side] / total, 0.0, 1.0)

## Progress 0..1 until `unit` swings (1 = about to swing).
func swing_fraction(unit: CardInstance) -> float:
	if not _swing.has(unit.instance_id):
		return 0.0
	var side: int = PLAYER if state.players[PLAYER].board.get_cards().has(unit) else ENEMY
	return clampf(1.0 - float(_swing[unit.instance_id]) / _unit_interval(side), 0.0, 1.0)

func _unit_interval(side: int) -> float:
	return ALLY_READY_INTERVAL if side == PLAYER else ENEMY_SWING_INTERVAL

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
	_tick_swings(delta, events)
	if not state.is_game_over():
		_tick_enemy(delta, events)
	return events

func _tick_resources(side: int, delta: float, events: Array[Dictionary]) -> void:
	var p: PlayerState = state.players[side]
	var h := p.hero
	if h.mana < h.max_mana:
		_mana_carry[side] += delta * MANA_REGEN_PER_SEC
		var whole: int = int(_mana_carry[side])
		_mana_carry[side] -= whole
		var before_units: int = h.mana / h.mana_scale
		h.mana = mini(h.max_mana, h.mana + whole)
		# Only a whole cost unit changes what's affordable — emit then, not per point.
		if h.mana / h.mana_scale != before_units:
			events.append({"type": "mana", "side": side})
	else:
		_mana_carry[side] = 0.0
	_draw_timer[side] += delta
	if _draw_timer[side] >= DRAW_INTERVAL:
		_draw_timer[side] -= DRAW_INTERVAL
		if p.hand.size() < HAND_CAP:
			p.draw_card(false)
			events.append({"type": "draw", "side": side})

func _tick_swings(delta: float, events: Array[Dictionary]) -> void:
	var live: Dictionary = {}
	for side in range(2):
		for c: CardInstance in state.players[side].board.get_cards():
			live[c.instance_id] = true
			if not _swing.has(c.instance_id):
				# Newly played: Surge acts soon, everything else waits a full interval.
				_swing[c.instance_id] = 0.5 if c.keywords.has(Keywords.SURGE) else _unit_interval(side)
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
			_swing[c.instance_id] = ENEMY_SWING_INTERVAL + left
			if c.attack <= 0:
				continue
			var target: CardInstance = pick_target(side)
			_resolve_swing(side, c, c.attack, target)
			events.append({"type": "swing", "side": side, "attacker": c, "target": target})
		_tick_hero(side, delta, events)

## Ally readiness: a ready Ally (can_attack) waits for the player's command;
## otherwise its timer runs and, on expiry, the Ally becomes ready.
func _tick_ally(c: CardInstance, delta: float, events: Array[Dictionary]) -> void:
	if c.can_attack():
		_swing[c.instance_id] = ALLY_READY_INTERVAL
		return
	var left: float = float(_swing[c.instance_id]) - delta
	if left > 0.0:
		_swing[c.instance_id] = left
		return
	_swing[c.instance_id] = ALLY_READY_INTERVAL
	c.summoning_sick = false
	c.attack_count = maxi(1, c.attack_count)
	events.append({"type": "ally_ready", "card": c})

## Main-hand damage for `side` (0 = this hero doesn't auto-attack).
func main_hand_damage(side: int) -> int:
	var atk: int = state.players[side].hero.attack
	return atk + UNARMED_DAMAGE if side == PLAYER else atk

## Progress 0..1 of `side`'s main-hand swing (1 = about to swing).
func hero_swing_fraction(side: int) -> float:
	return clampf(1.0 - _hero_swing[side] / HERO_SWING_INTERVAL, 0.0, 1.0)

func _tick_hero(side: int, delta: float, events: Array[Dictionary]) -> void:
	var hero := state.players[side].hero
	if not hero.is_alive() or hero.has_status("freeze") or hero.has_status("stun"):
		return
	var main: int = main_hand_damage(side)
	if main > 0:
		_hero_swing[side] -= delta
		if _hero_swing[side] <= 0.0:
			_hero_swing[side] += HERO_SWING_INTERVAL
			_hero_hit(side, main, "main", events)
	if offhand_damage[side] > 0 and not state.is_game_over():
		_offhand_swing[side] -= delta
		if _offhand_swing[side] <= 0.0:
			_offhand_swing[side] += OFFHAND_SWING_INTERVAL
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
	enemy_cast_remaining = ENEMY_CAST_TIME
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
