## Battle-start and per-turn modifiers from outside the card game: equipment, passive
## skills, companions, weather, ambush, gambit handicaps and desert scorch.
##
## A child of BattleScene (`BattleScene.modifiers`), created by `_ensure_battle_modules()`.
## Battle state stays on the scene. Reach it as `_battle.<name>`, and use
## `_battle.add_child` rather than a bare `add_child`.
extends Node

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const WeaponData = preload("res://data/WeaponData.gd")
const SkillRegistry = preload("res://autoloads/SkillRegistry.gd")
const SkillData = preload("res://data/SkillData.gd")
const CompanionRegistry = preload("res://autoloads/CompanionRegistry.gd")
const CompanionData = preload("res://data/CompanionData.gd")
const UpgradeDefs = preload("res://game_logic/UpgradeDefs.gd")
const Gambits = preload("res://game_logic/battle/Gambits.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

var _battle: _BattleScene


func _init(battle: _BattleScene) -> void:
	_battle = battle


func _apply_equipment_effects(player: PlayerState) -> void:
	var sm := SceneManager.save_manager
	var slot_ids: Array[String] = [
		sm.equipped_weapon,
		sm.equipped_armor,
		sm.equipped_ring,
		sm.equipped_trinket,
	]
	var injected_any: bool = false
	for item_id in slot_ids:
		if item_id == "":
			continue
		var weapon: WeaponData = WeaponRegistry.get_weapon(item_id)
		if weapon == null:
			continue
		var level: int = 0
		if weapon.slot == "weapon":
			var inst: Dictionary = sm.get_owned_weapon_by_id(item_id)
			level = int(inst.get("upgrade_level", 0))
		match weapon.battle_effect_type:
			"deck_inject":
				var count: int = UpgradeDefs.effective_inject_count(weapon, level)
				for i in count:
					var tmpl: Dictionary = CardRegistry.get_template(weapon.injected_card_id)
					if tmpl.is_empty():
						continue
					player.draw_deck.append(CardInstance.new(tmpl))
				injected_any = true
			"starting_mana":
				player.hero.bonus_mana += UpgradeDefs.effective_stat(weapon, level)
			"starting_hp":
				var hp_bonus: int = UpgradeDefs.effective_stat(weapon, level)
				player.hero.health += hp_bonus
				player.hero.max_health += hp_bonus
			"passive_atk":
				player.hero.attack += UpgradeDefs.effective_stat(weapon, level)
	if injected_any:
		player.draw_deck.shuffle()

func _apply_passive_skills(player: PlayerState) -> void:
	for skill_id: String in SceneManager.save_manager.unlocked_skills:
		var skill: SkillData = SkillRegistry.get_skill(skill_id)
		if skill == null or skill.skill_type != "passive":
			continue
		match skill.effect_type:
			"passive_hp":
				player.hero.health += skill.effect_value
				player.hero.max_health += skill.effect_value
			"passive_mana":
				player.hero.bonus_mana += skill.effect_value
			"passive_atk":
				player.hero.attack += skill.effect_value
			"passive_draw":
				player.bonus_draw += skill.effect_value

## Apply once-per-battle companion passives (extra_mana, hero_armor).
## Call after start_turn(1) so the base mana is already established.
## Excluded in puzzle_mode and friendly_duel.
func _apply_companion_battle_start(player: PlayerState) -> void:
	if _battle._state.puzzle_mode or _battle._state.friendly_duel:
		return
	var companion_id: String = SceneManager.save_manager.active_companion
	if companion_id == "" or not CompanionRegistry.is_unlocked(companion_id):
		return
	var companion: CompanionData = CompanionRegistry.get_companion(companion_id)
	if companion == null:
		return
	match companion.passive_type:
		"extra_mana":
			player.hero.mana = mini(player.hero.mana + companion.passive_value, 10)
		"hero_armor":
			player.hero.apply_status("armor", companion.passive_value)

## Draw extra card(s) from the companion's draw_card passive.
## Called at the start of every player turn (initial setup + each subsequent player turn).
## No-op in puzzle_mode, friendly_duel, scripted_battle, or when no draw_card companion is active.
func _apply_companion_turn_start() -> void:
	if _battle._state.puzzle_mode or _battle._state.friendly_duel or _battle._state.scripted_battle:
		return
	var companion_id: String = SceneManager.save_manager.active_companion
	if companion_id == "" or not CompanionRegistry.is_unlocked(companion_id):
		return
	var companion: CompanionData = CompanionRegistry.get_companion(companion_id)
	if companion == null or companion.passive_type != "draw_card":
		return
	for _i in range(companion.passive_value):
		_battle._state.players[0].draw_card()

## Add a compact companion display to SidePanel (name + passive description).
## No-op if no companion is equipped or the companion is not unlocked.
func _add_companion_hud() -> void:
	if _battle._state.puzzle_mode or _battle._state.scripted_battle:
		return
	var companion_id: String = SceneManager.save_manager.active_companion
	if companion_id == "" or not CompanionRegistry.is_unlocked(companion_id):
		return
	var companion: CompanionData = CompanionRegistry.get_companion(companion_id)
	if companion == null:
		return
	var vbox := _UiUtil.make_vbox(int(_battle._vh * 0.003))
	_battle.get_node("SidePanel").add_child(vbox)
	_battle._companion_hud = vbox

	var portrait_row := _UiUtil.make_hbox(int(_battle._vh * 0.005), vbox)

	if companion.portrait != null:
		var tex := TextureRect.new()
		tex.texture = companion.portrait
		tex.custom_minimum_size = Vector2(_battle._vh * 0.045, _battle._vh * 0.045)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_row.add_child(tex)
	else:
		var placeholder := ColorRect.new()
		placeholder.color = Color(0.4, 0.6, 0.8)
		placeholder.custom_minimum_size = Vector2(_battle._vh * 0.045, _battle._vh * 0.045)
		portrait_row.add_child(placeholder)

	var name_lbl := _UiUtil.make_label(companion.display_name, int(_battle._font(0.02)), Color.WHITE,
			HORIZONTAL_ALIGNMENT_LEFT,
			portrait_row)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var passive_lbl := _UiUtil.make_label(companion.description, int(_battle._font(0.017)), Color(0.85, 1.0, 0.85),
			HORIZONTAL_ALIGNMENT_LEFT, vbox)
	passive_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

## Apply init-time weather modifiers (ash_fall poison) and reset snow discount tracking.
func _apply_weather_battle_init() -> void:
	_battle._snow_discount_used = [false, false]
	match _battle._battle_weather:
		"ash_fall", "volcanic":
			_battle._state.players[1].hero.apply_status("poison", 2)

## Apply weather modifier to a newly summoned card (rain ghost bonus, sandstorm debuff).
func _apply_weather_to_summoned(card: CardInstance, _player_idx: int) -> void:
	match _battle._battle_weather:
		"rain":
			if card.template_id == "ghost":
				card.health += 1
				card.max_health += 1
		"heavy_rain":
			if card.template_id == "ghost":
				card.health += 2
				card.max_health += 2
		"sandstorm", "dust_devil":
			if _battle._state.turn_number <= 2:
				card.attack = maxi(0, card.attack - 1)

func _apply_ambush_modifiers(edata: Dictionary) -> void:
	if bool(edata.get("player_ambush", false)):
		var enemy_hero: HeroState = _battle._state.players[1].hero
		var new_hp: int = maxi(_battle._AMBUSH_HP_MIN,
				int(round(enemy_hero.max_health * (1.0 - _battle._AMBUSH_HP_PCT))))
		enemy_hero.health = new_hp
		enemy_hero.max_health = new_hp
		_battle._result_ui.show_ambush_banner(true)
	elif bool(edata.get("enemy_ambush", false)):
		var player_hero: HeroState = _battle._state.players[0].hero
		var new_hp: int = maxi(_battle._AMBUSH_HP_MIN,
				int(round(player_hero.max_health * (1.0 - _battle._AMBUSH_HP_PCT))))
		player_hero.health = new_hp
		player_hero.max_health = new_hp
		_battle._result_ui.show_ambush_banner(false)

func _apply_gambit_handicaps(gambit_id: String) -> void:
	if gambit_id.is_empty():
		return
	match gambit_id:
		"wounded_pride":
			_battle._state.players[0].hero.health = 25
			_battle._state.players[0].hero.max_health = 25
		"slow_start":
			_battle._state.players[0].skip_next_draw = true
		"iron_veil":
			_battle._state.players[1].hero.apply_status("armor", 5)
		# "emboldened_foe" is handled before build_deck via minion_attack_bonus.

func _add_gambit_badge() -> void:
	var gambit_id: String = str(_battle.enemy_data.get("gambit_id", ""))
	if gambit_id.is_empty():
		return
	var gdata: Dictionary = Gambits.get_gambit(gambit_id)
	if gdata.is_empty():
		return
	_battle._gambit_badge = PanelContainer.new()
	var badge_lbl := _UiUtil.make_label("Gambit: %s" % str(gdata.get("name", gambit_id)), int(_battle._font(0.018)))
	badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_battle._gambit_badge.add_child(badge_lbl)
	_battle._gambit_badge.tooltip_text = str(gdata.get("desc", ""))
	_battle.get_node("SidePanel").add_child(_battle._gambit_badge)
	_battle.arena.make_opens_effects(_battle._gambit_badge)

## Desert biome rule: damage the leftmost minion on each board at turn start.
## Does NOT use the Scorched modifier — this is a separate status tick.
func _apply_desert_scorch() -> void:
	for pid in range(2):
		for si in range(5):
			var c: CardInstance = _battle._state.players[pid].board.slots[si]
			if c != null:
				c.take_damage(1)
				if not c.is_alive():
					_battle._state.players[pid].board.remove_card(c)
					_battle._state.players[pid].discard.append(c)
				break
