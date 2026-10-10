## Persistent hero HP in the world (GID-136 / TID-543): slow out-of-combat
## regen, food (heal over time, interrupted by a fight), a world healing
## draught, full heals in towns and at the home bed, and the HUD HP bar.
## Rules and numbers live in game_logic/HeroVitality.gd; the fraction itself in
## `SaveManager.hero_hp_frac`.
##
## Quick use: the HUD "Eat" button (ability column, shown while hurt with
## something to eat or drink) and the Q key — the same key as the first battle
## quick slot. Food first, else a healing draught.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _HeroVitality = preload("res://game_logic/HeroVitality.gd")
const _WorldHUD = preload("res://scenes/world/WorldHUD.gd")
const _WellFed = preload("res://game_logic/professions/WellFed.gd")

## Save-dirty granularity for regen (fraction steps), so it isn't written every frame.
const _SAVE_STEP: float = 0.05

var _world: _WorldScene = null
var _meal_left: float = 0.0
var _meal_rate: float = 0.0
var _saved_at: float = -1.0
var _button_built: bool = false


func _ready() -> void:
	GameBus.enemy_engaged.connect(func(_d: Dictionary) -> void: _stop_meal())


func _process(delta: float) -> void:
	if _world == null or _world._world_hud == null or not SceneManager.is_in_world():
		return
	if not _button_built:
		_build_button()
	var sm := SceneManager.save_manager
	if sm.hero_hp_frac < 1.0:
		var rate: float = _meal_rate if _meal_left > 0.0 else 0.0
		sm.hero_hp_frac = _HeroVitality.regen(sm.hero_hp_frac, delta, rate, _HeroVitality.regen_seconds(sm.level))
		_meal_left = maxf(0.0, _meal_left - delta)
		if absf(sm.hero_hp_frac - _saved_at) >= _SAVE_STEP or sm.hero_hp_frac >= 1.0:
			_saved_at = sm.hero_hp_frac
			sm.mark_dirty()
	elif _meal_left > 0.0:
		_stop_meal()
	_world._world_hud.set_hero_hp(sm.hero_hp_frac, _meal_left > 0.0)
	_world._world_hud.set_well_fed(_WellFed.describe(sm.well_fed))
	_world._world_hud.set_action_visible("eat", _can_use())


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_Q and SceneManager.is_in_world():
		use_quick()
		get_viewport().set_input_as_handled()


## Towns and the bed: straight back to full.
func full_heal() -> void:
	var sm := SceneManager.save_manager
	if sm.hero_hp_frac < 1.0:
		sm.hero_hp_frac = 1.0
		sm.mark_dirty()
	_stop_meal()


## Eats the best food, or drinks a healing draught (Q / the HUD button).
func use_quick() -> void:
	var sm := SceneManager.save_manager
	if sm.hero_hp_frac >= 1.0:
		GameBus.hud_message_requested.emit("You're already at full health.")
		return
	if _meal_left > 0.0:
		GameBus.hud_message_requested.emit("You're still eating.")
		return
	var id: String = _HeroVitality.best_world_item(sm.foods, sm.potions)
	if id == "":
		GameBus.hud_message_requested.emit("Nothing to eat or drink — merchants sell food.")
		return
	if _HeroVitality.FOODS.has(id):
		sm.foods[id] = int(sm.foods.get(id, 0)) - 1
		var food: Dictionary = _HeroVitality.FOODS[id]
		_meal_rate = _HeroVitality.meal_rate(id)
		_meal_left = float(food.get("seconds", 0.0))
		GameBus.hud_message_requested.emit("Eating %s…" % str(food.get("display_name", id)))
		var buff: Dictionary = _WellFed.make(id)
		if not buff.is_empty():
			sm.well_fed = buff
			GameBus.hud_message_requested.emit(_WellFed.describe(buff))
	elif sm.garden.remove_potions(id, 1):
		sm.hero_hp_frac = minf(1.0, sm.hero_hp_frac + float(_HeroVitality.WORLD_POTION_HEAL[id]))
		GameBus.hud_message_requested.emit("You drink a healing draught.")
	sm.mark_dirty()


func _can_use() -> bool:
	var sm := SceneManager.save_manager
	return sm.hero_hp_frac < 1.0 and _meal_left <= 0.0 and _HeroVitality.best_world_item(sm.foods, sm.potions) != ""


func _stop_meal() -> void:
	_meal_left = 0.0
	_meal_rate = 0.0


func _build_button() -> void:
	_button_built = true
	var vh: float = _world.get_viewport().get_visible_rect().size.y
	var label: String = "Eat" if OS.has_feature("android") else "[Q] Eat"
	_world._world_hud.register_action("eat", label, _WorldHUD.ZONE_ABILITY, use_quick, _can_use,
			Vector2(vh * 0.16, vh * 0.055))
