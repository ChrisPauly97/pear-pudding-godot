## Battle-start and per-turn modifiers from outside the card game: equipment, passive
## skills, companions, weather, ambush, gambit handicaps and desert scorch.
##
## A child of BattleScene (`BattleScene.modifiers`), created by `_ensure_battle_modules()`.
## Battle state stays on the scene. Reach it as `_battle.<name>`, and use
## `_battle.add_child` rather than a bare `add_child`.
extends Node

const _TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")
const _RiftDefs = preload("res://game_logic/spire/RiftDefs.gd")
const _CombatOnboarding = preload("res://game_logic/battle/CombatOnboarding.gd")
const _UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const _ZoneLevels = preload("res://game_logic/world/ZoneLevels.gd")
const _HeroVitality = preload("res://game_logic/HeroVitality.gd")
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
const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _EnemyTraits = preload("res://game_logic/battle/EnemyTraits.gd")

var _battle: _BattleScene
## Enemy type + tier the fight traits apply for (set with the pack).
var _trait_type: String = ""
var _trait_tier: int = 1


func _init(battle: _BattleScene) -> void:
	_battle = battle


func _apply_equipment_effects(player: PlayerState) -> void:
	var sm := SceneManager.save_manager
	var slot_ids: Array[String] = [
		sm.equipped_weapon,
		sm.equipped_armor,
		sm.equipped_ring,
		sm.equipped_trinket,
		sm.equipped_offhand,
		sm.equipped_shoulders,
		sm.equipped_helmet,
		sm.equipped_boots,
	]
	# Off-hand attack gear swings on its own timer in real time (TID-545,
	# RealtimeCombat.offhand_damage — set from the same equipped item by
	# BattleRealtime.maybe_start()). Turn-based has no off-hand swing, so it
	# gets a smaller always-on attack bonus instead (documented in
	# docs/agent/combat-model.md).
	var realtime_mode: bool = sm.battle_mode().begins_with("realtime")
	var injected_any: bool = false
	for item_id in slot_ids:
		if item_id == "":
			continue
		var weapon: WeaponData = WeaponRegistry.get_weapon(item_id)
		if weapon == null:
			continue
		var level: int = 0
		var gm: float = sm.gear.mult(item_id)  # rarity / item level roll (TID-538)
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
				player.hero.bonus_mana += UpgradeDefs.effective_stat(weapon, level, gm)
			"starting_hp":
				var hp_bonus: int = UpgradeDefs.effective_stat(weapon, level, gm)
				player.hero.health += hp_bonus
				player.hero.max_health += hp_bonus
			"passive_atk":
				player.hero.attack += UpgradeDefs.effective_stat(weapon, level, gm)
			"starting_armor":
				player.hero.add_armor(UpgradeDefs.effective_stat(weapon, level, gm))
			"offhand_atk":
				if not realtime_mode:
					var offhand_val: int = UpgradeDefs.effective_stat(weapon, level, gm)
					player.hero.attack += UpgradeDefs.offhand_turnbased_bonus(offhand_val)
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
	var companion_id: String = _active_companion()
	if companion_id == "" or not CompanionRegistry.is_unlocked(companion_id):
		return
	var companion: CompanionData = CompanionRegistry.get_companion(companion_id)
	if companion == null:
		return
	match companion.passive_type:
		"extra_mana":
			player.hero.gain_mana(companion.passive_value, true)
		"hero_armor":
			player.hero.add_armor(companion.passive_value)

## Draw extra card(s) from the companion's draw_card passive.
## Called at the start of every player turn (initial setup + each subsequent player turn).
## No-op in puzzle_mode, friendly_duel, scripted_battle, or when no draw_card companion is active.
func _apply_companion_turn_start() -> void:
	if _battle._state.puzzle_mode or _battle._state.friendly_duel or _battle._state.scripted_battle:
		return
	var companion_id: String = _active_companion()
	if companion_id == "" or not CompanionRegistry.is_unlocked(companion_id):
		return
	var companion: CompanionData = CompanionRegistry.get_companion(companion_id)
	if companion == null or companion.passive_type != "draw_card":
		return
	for _i in range(companion.passive_value):
		_battle._state.players[0].draw_card(false)

## Add a compact companion display to SidePanel (name + passive description).
## No-op if no companion is equipped or the companion is not unlocked.
func _add_companion_hud() -> void:
	if _battle._state.puzzle_mode or _battle._state.scripted_battle:
		return
	var companion_id: String = _active_companion()
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

## GID-142 / TID-598: a rift run fights with the player's own deck (collection
## instances, ranks and all) plus the run's temporary picks, and applies its
## buff boons. Returns template ids for BattleScene to build instead — the
## legacy / co-op starter deck — or [] when the deck is already built here.
func _build_rift_deck(player: PlayerState) -> Array[String]:
	var spire := SceneManager.save_manager.spire
	if not spire.uses_own_deck():
		return spire.run_deck()
	var boons: Array = spire.boons()
	player.build_deck_from_instances(SceneManager.save_manager.get_deck_instances())
	var face: String = "dark" if CardRegistry.is_dark_aligned() else "light"
	for id: String in spire.drafted_cards():
		var tmpl: Dictionary = CardRegistry.get_template_for_face(id, face)
		if not tmpl.is_empty():
			player.draw_deck.append(CardInstance.new(tmpl))
	player.draw_deck.shuffle()
	var edge: int = _RiftDefs.boon_total(boons, "minion_attack")
	if edge > 0:
		for c: CardInstance in player.draw_deck:
			if c.card_class == "minion":
				c.attack += edge
	var extra_hp: int = _RiftDefs.boon_total(boons, "max_hp")
	player.hero.max_health += extra_hp
	player.hero.health += extra_hp
	var armor: int = _RiftDefs.boon_total(boons, "armor")
	if armor > 0:
		player.hero.add_armor(armor)
	return []

## GID-141 / TID-588: Ally (minion) cards stay out of the battle deck until the
## player has learned minions, spell cards until spells. Technique cards (GID-175)
## are always in — before minions they are the whole hand.
func _apply_combat_unlocks(player: PlayerState) -> void:
	if _battle._state.puzzle_mode or _battle._state.scripted_battle:
		return
	var learned: Array[String] = SceneManager.save_manager.learned_abilities
	var minions: bool = _CombatOnboarding.shows_hand(learned)
	var spells: bool = _CombatOnboarding.allows_spells(learned)
	if minions and spells:
		return
	var kept: Array[CardInstance] = []
	for c: CardInstance in player.draw_deck:
		if _TechniqueDefs.is_technique(c.template_id):
			kept.append(c)
		elif c.card_class == "spell" and spells:
			kept.append(c)
		elif c.card_class != "spell" and minions:
			kept.append(c)
	player.draw_deck = kept

## The active companion, or "" until the player has learned to fight beside one
## (UnlockLadder feat_companion).
func _active_companion() -> String:
	var sm := SceneManager.save_manager
	return sm.active_companion if sm.has_learned(_UnlockLadder.FEAT_COMPANION) else ""

## Zone level (TID-536): the enemy hero gains +6% HP per level above 1 (its card
## tier is raised in BattleScene before the deck is built).
func _apply_zone_level(level: int) -> void:
	if level <= 1:
		return
	var hero_hp: int = _ZoneLevels.scaled_hero_hp(_battle._state.players[1].hero.max_health, level)
	_battle._state.players[1].hero.health = hero_hp
	_battle._state.players[1].hero.max_health = hero_hp

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


# ── Persistent hero HP (GID-136 / TID-543) ──────────────────────────────────

## Whether this fight reads and writes `SaveManager.hero_hp_frac`.
func _hp_carries() -> bool:
	var sm := SceneManager.save_manager
	return not _battle._ghost_duel and _HeroVitality.carries_over(_battle.enemy_data, sm.spire.is_spire_active(),
			not sm.town_siege.get_active_siege().is_empty(), _battle._state.friendly_duel)


## Solo setup, after every max-HP modifier: start at the saved fraction.
func _apply_persistent_hp() -> void:
	if not _hp_carries():
		return
	var hero: HeroState = _battle._state.players[0].hero
	hero.health = mini(hero.health, _HeroVitality.battle_start_hp(hero.max_health,
			SceneManager.save_manager.hero_hp_frac))


## Game over of an ordinary solo fight: remember what's left (a loss → RESPAWN_FRAC).
func record_persistent_hp(won: bool) -> void:
	if not _hp_carries():
		return
	var hero: HeroState = _battle._state.players[0].hero
	var sm := SceneManager.save_manager
	sm.hero_hp_frac = _HeroVitality.frac_after(hero.health, hero.max_health, won)
	sm.mark_dirty()


# ── Pack encounters (GID-135 / TID-541) ─────────────────────────────────────

## Puts `enemy_type`'s pack (EnemyRegistry.get_pack) on the enemy board, scaled to
## `tier` like its deck and ready to act — what you saw beside it in the world.
## A leaderless pack (BID-077) has no hero to hit: the fight is won by clearing its board.
func _place_enemy_pack(enemy_type: String, tier: int) -> void:
	var enemy: PlayerState = _battle._state.players[1]
	_trait_type = enemy_type
	_trait_tier = tier
	for cid: String in EnemyRegistry.get_pack(enemy_type):
		if not _EnemyTraits.place(enemy, _EnemyTraits.make_unit(cid, tier, enemy.minion_attack_bonus)):
			break
	enemy.hero.leaderless = EnemyRegistry.is_leaderless(enemy_type) and not enemy.board.get_cards().is_empty()

# ── Fight traits (GID-149 / TID-621) ────────────────────────────────────────

## Enemy deck for `enemy_type` after deck-shaping traits (mirror: the player's own spells).
func trait_deck(enemy_type: String, deck: Array[String]) -> Array[String]:
	if not EnemyRegistry.get_traits(enemy_type).has("mirror"):
		return deck
	var spells: Array[String] = []
	var p: PlayerState = _battle._state.players[0]
	for c: CardInstance in p.draw_deck + p.hand:
		if c.card_class == "spell" and not spells.has(c.template_id):
			spells.append(c.template_id)
	return _EnemyTraits.mirror_deck(deck, spells)

## Start of enemy round `round_n`: howl / brood / frenzy (see EnemyTraits).
func apply_enemy_traits(round_n: int) -> void:
	var traits: Array[String] = EnemyRegistry.get_traits(_trait_type)
	if traits.is_empty() or _battle._state.players.size() < 2:
		return
	for line: String in _EnemyTraits.on_enemy_round(_battle._state, 1, traits, round_n, _trait_tier):
		if _battle.realtime != null and _battle.realtime.is_active():
			_battle.realtime.toast(line)
		else:
			_battle._fx.spawn_float_label(_battle._fx.pos_of_hero(true), line, Color(1.0, 0.75, 0.35))
