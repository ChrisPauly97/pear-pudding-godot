## Consumable quick slots (GID-136 / TID-542): two assignable potion slots with
## one shared cooldown, replacing "one potion per battle".
##
## Pure: slot contents live in `SaveManager.quick_slots` (potion ids), counts in
## `SaveManager.potions`. Turn-based battles gate on the drinker's own turn
## number (`COOLDOWN_TURNS` of their turns after a drink, so nothing needs a
## tick); real-time battles count seconds down via `tick()` (the
## `potion_cooldown` CombatTuning knob).
extends RefCounted

const GardenDefs = preload("res://game_logic/GardenDefs.gd")

const SLOTS: int = 2
const COOLDOWN_TURNS: int = 3
## Key per slot, shown on the buttons.
const KEYS: Array[Key] = [KEY_Q, KEY_E]
const KEY_LABELS: Array[String] = ["Q", "E"]

var _ready_turn: int = 0
var _seconds_left: float = 0.0


## True when a drink is allowed: on the drinker's own `turn` (turn-based) or
## once the seconds have run out (`realtime`). The mode is asked per call
## because a battle turns real-time after its buttons are built.
func is_ready(turn: int, realtime: bool) -> bool:
	return _seconds_left <= 0.0 if realtime else turn >= _ready_turn


## Starts the shared cooldown after a drink on `turn` (`seconds` for real time).
func start(turn: int, seconds: float) -> void:
	_ready_turn = turn + COOLDOWN_TURNS
	_seconds_left = seconds


func tick(delta: float) -> void:
	_seconds_left = maxf(0.0, _seconds_left - delta)


## Turns (turn-based) or whole seconds (real time) until ready; 0 when ready.
func remaining(turn: int, realtime: bool) -> int:
	return ceili(_seconds_left) if realtime else maxi(0, _ready_turn - turn)


## Slot contents with empty or exhausted slots topped up from owned potions not
## already slotted (in `GardenDefs.POTIONS` order), so a player who never assigns
## anything still gets their potions on Q / E. Always `SLOTS` long.
static func resolve(slots: Array, potions: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for i: int in SLOTS:
		var id: String = str(slots[i]) if i < slots.size() else ""
		out.append(id if GardenDefs.POTIONS.has(id) and int(potions.get(id, 0)) > 0 else "")
	for i: int in SLOTS:
		if out[i] != "":
			continue
		for id: String in GardenDefs.POTIONS:
			if int(potions.get(id, 0)) > 0 and not out.has(id):
				out[i] = id
				break
	return out


## `slots` with `potion_id` placed in slot `index` (and removed from any other).
static func assign(slots: Array, index: int, potion_id: String) -> Array[String]:
	var out: Array[String] = []
	for i: int in SLOTS:
		var id: String = str(slots[i]) if i < slots.size() else ""
		out.append("" if id == potion_id else id)
	if index >= 0 and index < SLOTS:
		out[index] = potion_id
	return out
