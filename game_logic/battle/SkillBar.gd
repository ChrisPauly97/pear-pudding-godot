## Fixed ability bar for real-time fights (GID-135 / TID-550): a few reliable
## skills that are always available on their own cooldowns, while deck cards
## stay single-use (the hand is their cooldown). Hearthstone's hero power
## stretched to a small WoW-style bar — the deck is still the main engine.
##
## Pure logic: owns each slot's cooldown and applies an ability to the battle
## state. `BattleSkillBar` draws the buttons and routes casts through
## `BattleRealtime.run_cast`. The slots come from `SaveManager.skill_bar`
## (trainers fill it later — TID-537).
extends RefCounted

const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")

const SLOTS: int = 3
const DEFAULT_BAR: Array[String] = ["strike", "mend", "kick"]
## id → {name, cost (mana points), cooldown (s), cast (s, 0 = instant),
## effect, value, off_gcd, desc}. Kept weaker than deck spells: reliable, not big.
const ABILITIES: Dictionary = {
	"strike": {"name": "Strike", "cost": 60, "cooldown": 6.0, "cast": 0.0, "effect": "damage", "value": 3,
		"off_gcd": false, "desc": "Hit your target for 3."},
	"mend": {"name": "Mend", "cost": 120, "cooldown": 20.0, "cast": 1.5, "effect": "heal", "value": 6,
		"off_gcd": false, "desc": "Heal yourself for 6 (1.5 s cast)."},
	"kick": {"name": "Kick", "cost": 30, "cooldown": 12.0, "cast": 0.0, "effect": "interrupt", "value": 0,
		"off_gcd": true, "desc": "Interrupt an enemy's cast. Off the global cooldown."},
}

var ids: Array[String] = []
var _cd_left: Array[float] = []
var _cd_total: Array[float] = []

## `bar` = saved ability ids; unknown ids are dropped, empty falls back to the default.
func _init(bar: Array = []) -> void:
	for v: Variant in bar:
		var id: String = str(v)
		if ABILITIES.has(id) and not ids.has(id) and ids.size() < SLOTS:
			ids.append(id)
	if ids.is_empty():
		ids.assign(DEFAULT_BAR)
	for _i: int in ids.size():
		_cd_left.append(0.0)
		_cd_total.append(1.0)

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
	me.hero.mana = maxi(0, me.hero.mana - int(d.get("cost", 0)))
	return out

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
