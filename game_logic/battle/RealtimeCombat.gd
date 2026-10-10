# gdlint: disable=max-file-lines
## Real-time combat driver (GID-135 / TID-546, multi-enemy TID-551).
## Runs a solo GameState without turns: every side acts on its own global
## cooldown (GCD), mana regenerates on a clock, cards are drawn on a clock, and
## every unit on the board (plus each hero) swings on its own timer. Pure logic
## — no rendering — so tests can drive `advance()`.
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
const DamageResolver = preload("res://game_logic/battle/DamageResolver.gd")
const DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")

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
## card_class of the heavy-blow pseudo card on an enemy's cast bar (TID-579).
const HEAVY_CLASS: String = "heavy_blow"

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
## Player deck-rule unlocks (GID-185 / TID-775, `BattleSetup.apply_deck_rules`):
## draw interval multiplier and extra hand cap. Enemies use the plain knobs.
var player_draw_mult: float = 1.0
var player_hand_bonus: int = 0
## GID-139 / TID-579: enemies wind up a telegraphed heavy blow every `heavy_every`
## seconds — it rides the cast bar (a pseudo card of class HEAVY_CLASS), so Kick
## interrupts it and Guard / armor soaks it. Off until the player can answer it
## (BattleRealtime enables it once Kick is learned).
var heavy_enabled: bool = false
## School of the enemy's hero swings and heavy blows (GID-181 / TID-751); set from the
## enemy type in BattleSetup.configure_realtime. Physical unless the type says otherwise.
var enemy_attack_school: String = DamageSchools.PHYSICAL
## Each side's level (index = side; the player's character level, an enemy's level-equivalent).
var side_levels: Array[int] = []
## Most minions each enemy side may field. 1 until the player can field Allies
## (BattleRealtime sets it from CombatOnboarding); adds that join later inherit it.
var enemy_minion_cap: int = MAX_ENEMY_MINIONS

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

## Momentum (GID-139) — player only. The hero's melee swing is always automatic:
## every blow siphons essence (mana) out of what it hits while the veins' trickle
## slows. No player-facing toggle; tests turn it off to isolate other timers.
var auto_attack: bool = true
## Combo charges built by skill-bar hits; the next card spends them all.
var combo: int = 0
## An on-crit skill node fired: the player's next cast is instant (GID-179).
var instant_next: bool = false
## Rolls free-cast procs; tests seed it or pin the chance knobs to 0 / 1.
## This fight's own rolls (procs). Randomized on construction; the balance sim
## (GID-176) sets `rng.seed` for a repeatable fight. Deck shuffles and resolver
## picks use the global RNG, so it also calls `seed(n)`.
var rng := RandomNumberGenerator.new()

## Per-side resource and hero-swing timers.
var _mana_carry: Array[float] = []
var _draw_timer: Array[float] = []
var _hero_swing: Array[float] = []
var _offhand_swing: Array[float] = []
## Five-second rule: regen is paused this long after spending mana.
var _regen_pause: Array[float] = []
var _last_mana: Array[int] = []
var _last_hp: Array[int] = []
## Seconds left until each side's next "combat round" upkeep pulse (TID-547).
var _round_timer: Array[float] = []
## instance_id -> seconds until next swing
var _swing: Dictionary = {}
## enemy minion instance_id -> true when its next swing goes at an Ally
var _hit_ally_next: Dictionary = {}
## TID-557: sides marked via `set_passive()` never cast or swing (dummy).
var _passive_sides: Dictionary = {}
## Seconds until each side's next heavy blow (TID-579).
var _heavy_timer: Array[float] = []

## `levels` = [player character level, enemy level-equivalent].
func _init(s: GameState, levels: Array[int] = [1, 1], tuning: CombatTuning = null) -> void:
	state = s
	tune = tuning if tuning != null else CombatTuning.new()
	rng.randomize()
	state.current_player_idx = PLAYER
	for i in range(state.players.size()):
		_init_side(i, levels[i] if i < levels.size() else 1)

## Sets up per-side timers and mana for players[i] (you or an enemy).
func _init_side(i: int, level: int) -> void:
	side_levels.append(level)
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
	_offhand_swing.append(_offhand_interval())
	_hero_swing[i] = swing_speed(i)
	# Enemy swings land a beat after the player's, so the two don't hit as one.
	if i != PLAYER:
		_hero_swing[i] += tune.get_f("enemy_swing_delay")
	var p: PlayerState = state.players[i]
	p.max_units = MAX_ALLIES if i == PLAYER else enemy_minion_cap
	var h := p.hero
	h.mana_scale = MANA_SCALE
	if i == PLAYER:
		_grow_hero_hp(h, level)
	else:
		_gap_enemy_hp(h, level)
	h.max_mana = max_mana_for(level, h.bonus_mana, tune)
	h.mana = h.max_mana
	_last_mana.append(h.mana)
	_last_hp.append(h.health)
	_round_timer.append(tune.get_f("round_seconds"))
	# The first heavy blow comes a little sooner than the steady rhythm.
	_heavy_timer.append(tune.get_f("heavy_every") * 0.6)
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
## Caps the player's Allies (early-game onboarding fields fewer — CombatOnboarding).
func set_ally_cap(cap: int) -> void:
	state.players[PLAYER].max_units = cap

## Shuffles `side`'s hand back down to `n` cards (real-time fights open smaller
## than the turn-based 4-card hand). The extras go back into the deck.
func trim_hand(side: int, n: int) -> void:
	var p: PlayerState = state.players[side]
	while p.hand.size() > n:
		p.draw_deck.append(p.hand.pop_back())
	p.draw_deck.shuffle()

## Caps every enemy side's minions (current sides now, adds as they join).
func set_enemy_minion_cap(cap: int) -> void:
	enemy_minion_cap = cap
	for side: int in enemy_sides():
		state.players[side].max_units = cap

func set_passive(side: int) -> void:
	_passive_sides[side] = true
func is_passive(side: int) -> bool:
	return bool(_passive_sides.get(side, false))

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
##   {"type": "ally_ready", "card"} / {"type": "enemy_down", "side"} / {"type": "round", "side"} (TID-547)
## Swings are resolved here (damage applied, dead units removed to discard).
func advance(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if state.is_game_over():
		return events
	for side in range(state.players.size()):
		gcd[side] = maxf(0.0, gcd[side] - delta)
		if is_alive(side):
			_tick_resources(side, delta, events)
			_tick_round(side, delta, events)
	_track_enemy_hits()
	_tick_swings(delta, events)
	for side: int in enemy_sides():
		if state.is_game_over():
			break
		if is_alive(side) and not is_passive(side):
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
		_mana_carry[side] += delta * tune.get_f("mana_regen") * _regen_mult(side)
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
	var interval: float = tune.get_f("draw_interval") * (player_draw_mult if side == PLAYER else 1.0)
	if _draw_timer[side] >= interval:
		_draw_timer[side] -= interval
		if p.hand.size() < tune.get_i("hand_cap") + (player_hand_bonus if side == PLAYER else 0):
			p.draw_card(false)
			events.append({"type": "draw", "side": side})

## Player regen scales with the auto-attack stance (GID-139); enemies regen flat.
func _regen_mult(side: int) -> float:
	if side != PLAYER:
		return 1.0
	return tune.get_f("fighting_regen_mult") if auto_attack else 1.0

## Per-side "combat round" pulse (TID-547): runs the turn-based upkeep real time
## doesn't already own via a continuous clock (status-effect decay, first-card
## discount, summoning sickness/attack-count reset, desert-biome scorch) on a
## periodic timer, `tune.round_seconds` (default 6 s), independently per side.
## Mirrors, in order: CardInstance.start_turn() (attack_count/summoning_sick
## reset, stun/out_of_play decay), BattleFx.process_start_of_turn_statuses()
## (poison/freeze decay on cards + hero poison), PlayerState.start_turn()'s
## grasslands_card_played reset, and BattleModifiers._apply_desert_scorch().
## Turn-based fights are unaffected — they still run that upkeep from
## GameState.end_turn()/BattleScene._on_turn_ended().
func _tick_round(side: int, delta: float, events: Array[Dictionary]) -> void:
	_round_timer[side] -= delta
	if _round_timer[side] > 0.0:
		return
	_round_timer[side] += tune.get_f("round_seconds")
	_run_round_upkeep(side)
	events.append({"type": "round", "side": side})

func _run_round_upkeep(side: int) -> void:
	var p: PlayerState = state.players[side]
	p.grasslands_card_played = false
	for c: CardInstance in p.board.get_cards().duplicate():
		c.start_turn()
		_tick_card_status(p, c)
	_tick_hero_status(p)
	if state.battlefield_biome == BattlefieldRules.BIOME_DESERT and not state.is_night:
		_scorch_leftmost(p)

## Poison damage-then-decay and freeze decay, mirroring BattleFx._tick_statuses_on_card.
## Unlike the turn-based original, a card poisoned to 0 HP is swept off the board —
## real time has no later turn boundary to lazily clean it up on.
func _tick_card_status(p: PlayerState, c: CardInstance) -> void:
	if c.has_status("poison"):
		var dmg: int = c.get_status_value("poison")
		DamageResolver.deal(p, c, dmg, DamageSchools.PHYSICAL, tune)
		var nv: int = dmg - 1
		if nv <= 0:
			c.clear_status("poison")
		else:
			c.apply_status("poison", nv)
		if not c.is_alive():
			p.board.remove_card(c)
			p.discard.append(c)
			if focus_target == c:
				focus_target = null
			return
	if c.has_status("freeze"):
		var dur: int = c.get_status_value("freeze") - 1
		if dur <= 0:
			c.clear_status("freeze")
		else:
			c.apply_status("freeze", dur)

## Hero poison damage-then-decay, mirroring BattleFx._tick_statuses_on_hero.
func _tick_hero_status(p: PlayerState) -> void:
	var hero: HeroState = p.hero
	if hero.has_status("poison"):
		var dmg: int = hero.get_status_value("poison")
		DamageResolver.deal(p, hero, dmg, DamageSchools.PHYSICAL, tune)
		var nv: int = dmg - 1
		if nv <= 0:
			hero.clear_status("poison")
		else:
			hero.apply_status("poison", nv)

## Desert biome rule: damage `p`'s own leftmost minion, mirroring
## BattleModifiers._apply_desert_scorch() for this side only (each side pulses on
## its own round timer in real time, rather than both boards on every turn end).
func _scorch_leftmost(p: PlayerState) -> void:
	for si in range(5):
		var c: CardInstance = p.board.slots[si]
		if c != null:
			DamageResolver.deal(p, c, 1, DamageSchools.PHYSICAL, tune)
			if not c.is_alive():
				p.board.remove_card(c)
				p.discard.append(c)
				if focus_target == c:
					focus_target = null
			return

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
		if not is_alive(side) or is_passive(side):
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
			var crit: bool = _resolve_swing(c, c.attack, target, PLAYER, side)
			events.append({"type": "swing", "side": side, "attacker": c, "target": target, "target_side": PLAYER,
				"crit": crit})
		_tick_hero(side, delta, events)

## Allies auto-attack: every `ally_ready` seconds an Ally swings at whatever
## your hero is hitting (Ward first, else your focus, else the targeted enemy
## hero). No command needed — tapping an enemy just moves the shared focus.
func _tick_ally(c: CardInstance, delta: float, events: Array[Dictionary]) -> void:
	var left: float = float(_swing[c.instance_id]) - delta
	if left > 0.0:
		_swing[c.instance_id] = left
		return
	_swing[c.instance_id] = tune.get_f("ally_ready") + left
	c.summoning_sick = false
	if c.attack <= 0:
		return
	var target: CardInstance = pick_target(PLAYER)
	var target_side: int = owner_of(target) if target != null else target_enemy()
	var crit: bool = _resolve_swing(c, c.attack, target, target_side, PLAYER)
	events.append({"type": "swing", "side": PLAYER, "attacker": c, "target": target, "target_side": target_side,
		"crit": crit})

## Main-hand swing interval for `side` (s): the weapon's speed, else unarmed,
## scaled by `swing_mult`.
func swing_speed(side: int) -> float:
	return _raw_swing(side) * tune.get_f("swing_mult")

func _raw_swing(side: int) -> float:
	return weapon_speed[side] if weapon_speed[side] > 0.0 else tune.get_f("hero_swing")

func _offhand_interval() -> float:
	return tune.get_f("offhand_swing") * tune.get_f("swing_mult")

## Average main-hand damage per swing for `side` (0 = this hero doesn't auto-attack).
## Scaled by swing speed ÷ unarmed speed, so a slow two-hander hits harder per
## swing and a dagger lighter, at roughly the same damage per second.
func _main_hand_avg(side: int) -> float:
	if state.players[side].hero.leaderless:  # BID-077: no leader to swing
		return 0.0
	var base: int = state.players[side].hero.attack + unarmed[side]
	if base <= 0:
		return 0.0
	return float(base) * _raw_swing(side) / tune.get_f("hero_swing") * tune.get_f("swing_damage")

## Typical main-hand hit for `side`, rounded (0 = no auto-attack).
func main_hand_damage(side: int) -> int:
	var avg: float = _main_hand_avg(side)
	return maxi(1, roundi(avg)) if avg > 0.0 else 0

## One hit around `avg`: for the player a value in avg × (1 ± swing_spread), rounded
## up or down by chance so the average holds (damage per second doesn't drift), at
## least 1. Enemy hits don't spread (a spread enemy wins more close fights).
func _roll_swing(avg: float, side: int) -> int:
	var s: float = tune.get_f("swing_spread") if side == PLAYER else 0.0
	var x: float = avg * rng.randf_range(1.0 - s, 1.0 + s)
	var whole: int = floori(x)
	return maxi(1, whole + (1 if rng.randf() < x - float(whole) else 0))

## Progress 0..1 of `side`'s main-hand swing (1 = about to swing).
func hero_swing_fraction(side: int) -> float:
	return clampf(1.0 - _hero_swing[side] / swing_speed(side), 0.0, 1.0)

func _tick_hero(side: int, delta: float, events: Array[Dictionary]) -> void:
	var hero := state.players[side].hero
	if not hero.is_alive() or hero.has_status("freeze") or hero.has_status("stun"):
		return
	if side == PLAYER and not auto_attack:
		return
	var main: float = _main_hand_avg(side)
	if main > 0.0:
		_hero_swing[side] -= delta
		if _hero_swing[side] <= 0.0:
			_hero_swing[side] += swing_speed(side)
			_hero_hit(side, _roll_swing(main, side), "main", events)
	if offhand_damage[side] > 0 and not state.is_game_over():
		_offhand_swing[side] -= delta
		if _offhand_swing[side] <= 0.0:
			_offhand_swing[side] += _offhand_interval()
			_hero_hit(side, _roll_swing(float(offhand_damage[side]) * tune.get_f("swing_damage"), side), "off",
					events)

func _hero_hit(side: int, dmg: int, hand: String, events: Array[Dictionary]) -> void:
	var target: CardInstance = pick_target(side)
	var target_side: int = owner_of(target) if target != null else (target_enemy() if side == PLAYER else PLAYER)
	var crit: bool = _resolve_swing(null, dmg, target, target_side, side)
	events.append({"type": "swing", "side": side, "attacker": null, "hand": hand, "target": target,
		"target_side": target_side, "crit": crit})
	if side == PLAYER and on_player_hit(dmg, false):
		events.append({"type": "proc", "side": PLAYER})

# ---------------------------------------------------------------------------
# Momentum (GID-139): siphon, combo charges, free-cast procs
# ---------------------------------------------------------------------------

## The player's hero or skill dealt `dmg`: siphon essence back as mana, and —
## for a skill-bar hit (`builder`) — add a combo charge. Rolls the free-cast
## proc; returns true when it newly fires.
func on_player_hit(dmg: int, builder: bool) -> bool:
	var h := state.players[PLAYER].hero
	var gain: int = maxi(0, dmg) * tune.get_i("siphon_per_damage")
	h.mana = mini(h.max_mana, h.mana + gain)
	if builder:
		combo = mini(tune.get_i("combo_max"), combo + 1)
	var p: PlayerState = state.players[PLAYER]
	if p.next_card_free:
		return false
	var chance: float = tune.get_f("proc_chance") if builder else tune.get_f("auto_proc_chance")
	if rng.randf() < chance:
		p.next_card_free = true
		return true
	return false

func combo_full() -> bool:
	return combo >= tune.get_i("combo_max")

## True while the next card is empowered: free (proc) or instant (full combo).
func next_card_instant() -> bool:
	return state.players[PLAYER].next_card_free or combo_full()
## A card resolved: it spends every combo charge for a mana refund. Returns
## the charges spent (0 = none).
func spend_combo() -> int:
	var n: int = combo
	combo = 0
	if n > 0:
		var h := state.players[PLAYER].hero
		h.mana = mini(h.max_mana, h.mana + n * tune.get_i("combo_refund"))
	return n

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
	if not wards.is_empty():
		return wards[0]
	return _weakest_pack_member(opp) if state.players[opp].hero.leaderless else null

## A leaderless pack's hero can't be hit (BID-077), so swings go at its weakest unit.
func _weakest_pack_member(side: int) -> CardInstance:
	var best: CardInstance = null
	for c: CardInstance in state.players[side].board.get_cards():
		if c.is_alive() and (best == null or c.health < best.health):
			best = c
	return best

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
## Returns true when the swing was a critical hit (GID-178 / TID-728): a seeded
## roll on `crit_chance` (your side) / `enemy_crit_chance`, × `crit_mult`.
func _resolve_swing(attacker: CardInstance, dmg: int, target: CardInstance, target_side: int,
		from_side: int) -> bool:
	var opp: PlayerState = state.players[target_side]
	var d: int = BattlefieldRules.modify_damage(dmg, state.battlefield_biome)
	if from_side != PLAYER:
		d = _gap_scaled(d, from_side)
	var crit: bool = d > 0 and rng.randf() < tune.get_f("crit_chance" if from_side == PLAYER else "enemy_crit_chance")
	if crit:
		d = maxi(d + 1, roundi(float(d) * tune.get_f("crit_mult")))
	var school: String = DamageSchools.school_of(attacker)
	var src: PlayerState = state.players[from_side]  # the attacking side: its school power (TID-754)
	if attacker == null:
		# A hero swing: an enemy hero's swing hits as its school (TID-751), the player's as the
		# weapon's school (a convert affix, TID-754; physical otherwise).
		school = enemy_attack_school if from_side == ENEMY else src.weapon_school()
	if target == null:
		DamageResolver.deal(opp, opp.hero, d, school, tune, src)
		return crit
	DamageResolver.deal(opp, target, d, school, tune, src)
	if not target.is_alive():
		if attacker != null:
			attacker.battle_kills += 1
		opp.board.remove_card(target)
		opp.discard.append(target)
		if focus_target == target:
			focus_target = null
	return crit

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
	if heavy_enabled:
		_heavy_timer[side] -= delta
	if casting[side] != null:
		cast_remaining[side] -= delta
		if cast_remaining[side] > 0.0:
			return
		var card: CardInstance = casting[side] as CardInstance
		casting[side] = null
		pushbacks[side] = 0
		if is_heavy(card):
			_land_heavy(side, events)
		elif ai.hand.has(card) and ai.can_play(card) and ai.play_card(card):
			events.append({"type": "enemy_cast", "side": side, "card": card})
		start_gcd(side)
		return
	if not gcd_ready(side):
		return
	if heavy_enabled and _heavy_timer[side] <= 0.0 and not state.players[side].hero.leaderless \
			and _level_of(side) >= tune.get_i("heavy_min_level"):
		_heavy_timer[side] = tune.get_f("heavy_every")
		casting[side] = make_heavy_card()
		pushbacks[side] = 0
		cast_remaining[side] = tune.get_f("heavy_windup")
		events.append({"type": "enemy_heavy_start", "side": side, "card": casting[side]})
		return
	var pick: CardInstance = choose_enemy_card(side)
	if pick == null:
		return
	casting[side] = pick
	pushbacks[side] = 0
	cast_remaining[side] = tune.get_f("enemy_cast")
	events.append({"type": "enemy_cast_start", "side": side, "card": pick})

## The heavy blow's cast-bar card (not in any hand; interrupting it just drops it).
static func make_heavy_card() -> CardInstance:
	return CardInstance.new({"id": "heavy_blow", "name": "Heavy Blow", "card_class": HEAVY_CLASS, "cost": 0,
		"attack": 0, "health": 1, "description": "A wound-up blow: Kick it, or Guard against it."})

static func is_heavy(card: CardInstance) -> bool:
	return card != null and card.card_class == HEAVY_CLASS

## Damage a landed heavy blow deals (a share of your max HP; armor soaks it).
## Heavy blows from a low-level enemy land softer (CombatTuning.level_scale, TID-720).
func heavy_damage(side: int = ENEMY) -> int:
	return maxi(1, roundi(float(state.players[PLAYER].hero.max_health) * tune.get_f("heavy_frac")
			* tune.level_scale(_level_of(side)) * tune.gap_mult(_level_of(side), _level_of(PLAYER))))

## An enemy side's swing damage after the level gap: the fractional part lands
## as a seeded chance, so small integer hits still feel the gap (TID-718).
func _gap_scaled(dmg: int, side: int) -> int:
	if dmg <= 0:
		return dmg
	var x: float = float(dmg) * tune.gap_mult(_level_of(side), _level_of(PLAYER))
	var whole: int = floori(x)
	return whole + (1 if rng.randf() < x - float(whole) else 0)

## The player's hero gains `hp_per_level` max HP per level above 1 (GID-176 /
## TID-718); current HP keeps its fraction, so a wounded hero stays wounded.
func _grow_hero_hp(h: HeroState, level: int) -> void:
	var extra: int = roundi(tune.get_f("hp_per_level") * float(maxi(0, level - 1)))
	if extra <= 0 or h.max_health <= 0:
		return
	var frac: float = float(h.health) / float(h.max_health)
	h.max_health += extra
	h.health = clampi(roundi(frac * float(h.max_health)), 1 if h.health > 0 else 0, h.max_health)

## An enemy's hero gains `enemy_hp_per_level` × max HP per level above 1 (on top
## of the zone scaling), and `gap_hp` × more per level it is above the player
## (less below, never under half). Its pack units already on the board scale the
## same way, so a pack keeps pace with its leader (BID-095). Health keeps its fraction.
func _gap_enemy_hp(h: HeroState, level: int) -> void:
	var gap: int = level - _level_of(PLAYER)
	var mult: float = maxf(0.5, 1.0 + tune.get_f("gap_hp") * float(gap)) \
			* (1.0 + tune.get_f("enemy_hp_per_level") * float(maxi(0, level - 1)))
	if is_equal_approx(mult, 1.0):
		return
	if h.max_health > 0:
		var frac: float = float(h.health) / float(h.max_health)
		h.max_health = maxi(1, roundi(float(h.max_health) * mult))
		h.health = clampi(roundi(frac * float(h.max_health)), 1 if h.health > 0 else 0, h.max_health)
	for p: PlayerState in state.players:
		if p.hero != h:
			continue
		for c: CardInstance in p.board.get_cards():
			var hp: int = maxi(1, roundi(float(c.max_health) * mult))
			c.health = clampi(c.health + hp - c.max_health, 1, hp)
			c.max_health = hp

## A side's level (1 if unknown).
func _level_of(side: int) -> int:
	return side_levels[side] if side >= 0 and side < side_levels.size() else 1

func _land_heavy(side: int, events: Array[Dictionary]) -> void:
	var hero := state.players[PLAYER].hero
	var school: String = enemy_attack_school if side == ENEMY else DamageSchools.PHYSICAL
	var res: Dictionary = DamageResolver.deal(state.players[PLAYER], hero, heavy_damage(side), school, tune)
	events.append({"type": "enemy_heavy_hit", "side": side, "damage": int(res["dealt"]),
			"outcome": str(res["outcome"])})

## An enemy picks the most expensive card it can afford — units or spells (spells
## resolve at the player in BattleRealtime._after_enemy_play, BID-078). Heuristic
## only — AI personas apply in TID-541.
func choose_enemy_card(side: int = ENEMY) -> CardInstance:
	var ai: PlayerState = state.players[side]
	var best: CardInstance = null
	# Spells are castable too (BID-078): BattleRealtime resolves them on enemy_cast.
	for c: CardInstance in ai.hand:
		if not ai.can_play(c):
			continue
		if best == null or ai.effective_cost(c) > ai.effective_cost(best):
			best = c
	return best
