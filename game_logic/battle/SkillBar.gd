## Fixed ability bar for real-time fights (GID-135 / TID-550): a few reliable
## skills that are always available on their own cooldowns, while deck cards
## stay single-use (the hand is their cooldown). Hearthstone's hero power
## stretched to a small WoW-style bar — the deck is still the main engine.
##
## Pure logic: owns each slot's cooldown and applies an ability to the battle
## state. `BattleSkillBar` draws the buttons and routes casts through
## `BattleRealtime.run_cast`. The slots come from `SaveManager.skill_bar`,
## filtered to `SaveManager.learned_abilities` (trainers fill it — TID-537);
## strike/mend/kick are always known.
extends RefCounted

const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")

const SLOTS: int = 3
const DEFAULT_BAR: Array[String] = ["strike", "mend", "kick"]
## Ids that need no trainer/coins — every save knows them from the start.
const ALWAYS_KNOWN: Array[String] = ["strike", "mend", "kick"]
## Trainer-taught ids (TID-537), in trainer-panel display order.
const LEARNABLE_ORDER: Array[String] = ["guard", "ember_lance", "mana_tap", "sweep", "daze"]

## id → {name, cost (mana points), cooldown (s), cast (s, 0 = instant),
## effect, value, off_gcd, desc, level_req, learn_cost}. Kept weaker than deck
## spells: reliable, not big — every learnable ability's `value` stays ≤ 9
## (test_skill_bar.gd checks this). `level_req`/`learn_cost` are 0 for the
## always-known three (never offered by a trainer — see `learnable_ids()`).
const ABILITIES: Dictionary = {
	"strike": {"name": "Strike", "cost": 60, "cooldown": 6.0, "cast": 0.0, "effect": "damage", "value": 3,
		"off_gcd": false, "desc": "Hit your target for 3.", "level_req": 0, "learn_cost": 0},
	"mend": {"name": "Mend", "cost": 120, "cooldown": 20.0, "cast": 1.5, "effect": "heal", "value": 6,
		"off_gcd": false, "desc": "Heal yourself for 6 (1.5 s cast).", "level_req": 0, "learn_cost": 0},
	"kick": {"name": "Kick", "cost": 30, "cooldown": 12.0, "cast": 0.0, "effect": "interrupt", "value": 0,
		"off_gcd": true, "desc": "Interrupt an enemy's cast. Off the global cooldown.",
		"level_req": 0, "learn_cost": 0},
	"guard": {"name": "Guard", "cost": 80, "cooldown": 16.0, "cast": 0.0, "effect": "shield", "value": 6,
		"off_gcd": false, "desc": "Raise your guard, absorbing the next 6 damage.",
		"level_req": 3, "learn_cost": 40},
	"ember_lance": {"name": "Ember Lance", "cost": 90, "cooldown": 9.0, "cast": 1.0, "effect": "damage", "value": 9,
		"off_gcd": false, "desc": "A slower, heavier strike for 9 (1 s cast).",
		"level_req": 5, "learn_cost": 60},
	"mana_tap": {"name": "Mana Tap", "cost": 20, "cooldown": 14.0, "cast": 0.0, "effect": "manatap", "value": 2,
		"off_gcd": false, "desc": "A light hit for 2 that siphons back a little mana.",
		"level_req": 4, "learn_cost": 50, "mana_value": 1},
	"sweep": {"name": "Sweep", "cost": 100, "cooldown": 18.0, "cast": 0.0, "effect": "sweep", "value": 3,
		"off_gcd": false, "desc": "A wide strike that clips every enemy minion for 3.",
		"level_req": 6, "learn_cost": 70},
	"daze": {"name": "Daze", "cost": 40, "cooldown": 20.0, "cast": 0.0, "effect": "stun", "value": 0,
		"off_gcd": true, "desc": "A weak stun — briefly delays the enemy. Off the global cooldown.",
		"level_req": 7, "learn_cost": 80},
}

var ids: Array[String] = []
var _cd_left: Array[float] = []
var _cd_total: Array[float] = []

## `bar` = saved ability ids; `learned` = `SaveManager.learned_abilities`.
## Unknown ids, and learnable ids not in `learned`, are dropped; empty falls
## back to the default (always-known) bar.
func _init(bar: Array = [], learned: Array = []) -> void:
	var known: Dictionary = {}
	for id: String in ALWAYS_KNOWN:
		known[id] = true
	for v: Variant in learned:
		known[str(v)] = true
	for v: Variant in bar:
		var id: String = str(v)
		if ABILITIES.has(id) and known.has(id) and not ids.has(id) and ids.size() < SLOTS:
			ids.append(id)
	if ids.is_empty():
		ids.assign(DEFAULT_BAR)
	for _i: int in ids.size():
		_cd_left.append(0.0)
		_cd_total.append(1.0)

static func is_always_known(id: String) -> bool:
	return ALWAYS_KNOWN.has(id)

## Every ability a trainer can teach, in display order.
static func learnable_ids() -> Array[String]:
	return LEARNABLE_ORDER.duplicate()

static func can_learn(id: String, player_level: int, coins: int, already_learned: Array) -> bool:
	if not ABILITIES.has(id) or is_always_known(id) or already_learned.has(id):
		return false
	var a: Dictionary = ABILITIES[id]
	return player_level >= int(a.get("level_req", 0)) and coins >= int(a.get("learn_cost", 0))

## Every ability the player can currently slot: the always-known trio plus
## whatever they've learned from a trainer.
static func known_ids(learned: Array) -> Array[String]:
	var out: Array[String] = ALWAYS_KNOWN.duplicate()
	for v: Variant in learned:
		var id: String = str(v)
		if ABILITIES.has(id) and not out.has(id):
			out.append(id)
	return out

## TID-556: the loadout picker's editing state — always exactly `SLOTS`
## entries. `bar`'s ids are kept in order where they're known; any remaining
## slots are padded with unused known ids (default bar first, so a fresh save
## still starts at strike/mend/kick).
static func resolved_bar(bar: Array, learned: Array) -> Array[String]:
	var known: Array[String] = known_ids(learned)
	var out: Array[String] = []
	for v: Variant in bar:
		var id: String = str(v)
		if known.has(id) and not out.has(id) and out.size() < SLOTS:
			out.append(id)
	for id: String in (DEFAULT_BAR + known):
		if out.size() >= SLOTS:
			break
		if not out.has(id):
			out.append(id)
	return out

static func def(id: String) -> Dictionary:
	return ABILITIES.get(id, {}) as Dictionary

func def_at(slot: int) -> Dictionary:
	return def(ids[slot]) if slot >= 0 and slot < ids.size() else {}

func advance(dt: float) -> void:
	for i: int in _cd_left.size():
		_cd_left[i] = maxf(0.0, _cd_left[i] - dt)

func ready(slot: int) -> bool:
	return slot >= 0 and slot < ids.size() and _cd_left[slot] <= 0.0

func cooldown_left(slot: int) -> float:
	return _cd_left[slot]

## Progress 0..1 until the slot is ready again (1 = ready).
func fraction(slot: int) -> float:
	return clampf(1.0 - _cd_left[slot] / _cd_total[slot], 0.0, 1.0)

## Starts the slot's cooldown, scaled by the "skill_cooldown" tuning knob.
func start_cooldown(slot: int, mult: float = 1.0) -> void:
	var t: float = float(def_at(slot).get("cooldown", 0.0)) * mult
	_cd_total[slot] = maxf(t, 0.01)
	_cd_left[slot] = t

## "" when the ability can be used now, else why not (shown as a toast).
func blocker(slot: int, rt: RealtimeCombat) -> String:
	if not ready(slot):
		return "Not ready yet"
	var d: Dictionary = def_at(slot)
	var me: PlayerState = rt.state.players[RealtimeCombat.PLAYER]
	if me.hero.mana < int(d.get("cost", 0)):
		return "Not enough mana"
	if str(d.get("effect", "")) == "interrupt" and _casting_enemy(rt) < 0:
		return "Nothing to interrupt"
	return ""

## Applies the ability: spends its mana and returns what happened —
## {"text", "side", "target"} for the scene's feedback ({} = nothing).
func apply(slot: int, rt: RealtimeCombat) -> Dictionary:
	var d: Dictionary = def_at(slot)
	var me: PlayerState = rt.state.players[RealtimeCombat.PLAYER]
	var value: int = int(d.get("value", 0))
	var out: Dictionary = {}
	match str(d.get("effect", "")):
		"damage":
			out = _damage(rt, value)
		"heal":
			me.hero.heal(value)
			out = {"text": "+%d HP" % value, "side": RealtimeCombat.PLAYER}
		"interrupt":
			var side: int = _casting_enemy(rt)
			var cut: CardInstance = rt.interrupt_enemy_cast(side) if side >= 0 else null
			if cut == null:
				return {}
			out = {"text": "Interrupted %s!" % cut.name, "side": side}
		"shield":
			var cur: int = me.hero.get_status_value("armor")
			me.hero.apply_status("armor", cur + value)
			out = {"text": "+%d Armor" % value, "side": RealtimeCombat.PLAYER}
		"manatap":
			out = _damage(rt, value)
			me.hero.gain_mana(int(d.get("mana_value", 1)))
		"sweep":
			out = _sweep(rt, value)
		"stun":
			var side: int = _casting_enemy(rt)
			if side < 0:
				side = rt.target_enemy()
			rt.state.players[side].hero.apply_status("stun", 1)
			rt.interrupt_enemy_cast(side)
			out = {"text": "Dazed!", "side": side}
	me.hero.mana = maxi(0, me.hero.mana - int(d.get("cost", 0)))
	return out

## Hits every live minion on the targeted enemy's board for `value`.
func _sweep(rt: RealtimeCombat, value: int) -> Dictionary:
	var side: int = rt.target_enemy()
	var opp: PlayerState = rt.state.players[side]
	var dmg: int = BattlefieldRules.modify_damage(value, rt.state.battlefield_biome)
	var hit: int = 0
	for c: CardInstance in opp.board.get_cards().duplicate():
		c.take_damage(dmg)
		hit += 1
		if not c.is_alive():
			opp.board.remove_card(c)
			opp.discard.append(c)
			if rt.focus_target == c:
				rt.focus_target = null
	return {"text": "Sweep! -%d ×%d" % [dmg, hit], "side": side}

## Hits the focused minion, else the targeted enemy hero (no retaliation).
func _damage(rt: RealtimeCombat, value: int) -> Dictionary:
	var target: CardInstance = rt.focus_target
	var side: int = rt.owner_of(target) if target != null else -1
	if side < 0:
		target = null
		side = rt.target_enemy()
	var opp: PlayerState = rt.state.players[side]
	var dmg: int = BattlefieldRules.modify_damage(value, rt.state.battlefield_biome)
	if target == null:
		opp.hero.take_damage(dmg)
	else:
		target.take_damage(dmg)
		if not target.is_alive():
			opp.board.remove_card(target)
			opp.discard.append(target)
			rt.focus_target = null
	return {"text": "-%d" % dmg, "side": side, "target": target}

## The enemy to interrupt: your target if it is casting, else any caster (-1 = none).
func _casting_enemy(rt: RealtimeCombat) -> int:
	var first: int = rt.target_enemy()
	if first < rt.casting.size() and rt.casting[first] != null:
		return first
	for side: int in rt.enemy_sides():
		if rt.casting[side] != null:
			return side
	return -1
