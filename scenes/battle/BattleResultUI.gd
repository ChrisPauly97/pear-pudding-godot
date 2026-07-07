extends RefCounted

const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const WeaponData = preload("res://data/WeaponData.gd")
const UiUtil = preload("res://scenes/ui/UiUtil.gd")
const UiFx = preload("res://scenes/ui/UiFx.gd")

const _BOSS_BANNER_DURATION: float = 2.5
const _COUNT_UP_DURATION: float = 0.5
const _COUNT_UP_MAX_STEPS: int = 8

var _parent: Node
var _vh: float = 0.0
var _float_layer: CanvasLayer = null
var _collect_veterancy_fn: Callable  # () -> Dictionary
var _boss_banner: Control = null

func setup(parent: Node, vh: float, float_layer: CanvasLayer, collect_veterancy_fn: Callable) -> void:
	_parent = parent
	_vh = vh
	_float_layer = float_layer
	_collect_veterancy_fn = collect_veterancy_fn

# -------------------------------------------------------------------------
# Boss banners
# -------------------------------------------------------------------------

func show_boss_banner(enemy_data: Dictionary) -> void:
	var vp: Vector2 = _parent.get_viewport().get_visible_rect().size
	var font_size: int = int(_vh * 0.045)
	var enemy_type: String = str(enemy_data.get("enemy_type", ""))
	var lbl := Label.new()
	lbl.text = "* %s *" % EnemyRegistry.get_display_name(enemy_type)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(vp.x, font_size * 2)
	lbl.position = Vector2(0.0, _vh * 0.08)
	_parent.add_child(lbl)
	_parent.move_child(lbl, _parent.get_child_count() - 1)
	if _boss_banner != null and is_instance_valid(_boss_banner):
		_boss_banner.queue_free()
	_boss_banner = lbl
	start_banner_fade(lbl)

func show_phase2_banner() -> void:
	var vp: Vector2 = _parent.get_viewport().get_visible_rect().size
	var font_size: int = int(_vh * 0.04)
	var lbl := Label.new()
	lbl.text = "- PHASE 2 -"
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(vp.x, font_size * 2)
	lbl.position = Vector2(0.0, _vh * 0.4)
	_parent.add_child(lbl)
	_parent.move_child(lbl, _parent.get_child_count() - 1)
	if _boss_banner != null and is_instance_valid(_boss_banner):
		_boss_banner.queue_free()
	_boss_banner = lbl
	start_banner_fade(lbl)

# -------------------------------------------------------------------------
# Reward count-up (TID-429)
# -------------------------------------------------------------------------

## Pure: the intermediate values a reward counter ticks through on its way to
## `target` (at most `max_steps`, always ending exactly on `target`). Kept
## static/pure so it's unit-testable without an overlay/label/tween.
static func count_up_steps(target: int, max_steps: int = _COUNT_UP_MAX_STEPS) -> Array[int]:
	var steps: Array[int] = []
	if target <= 0:
		steps.append(0)
		return steps
	var n: int = mini(max_steps, target)
	for i in range(1, n + 1):
		steps.append(int(round(float(target) * float(i) / float(n))))
	steps[steps.size() - 1] = target
	return steps

## Ticks `lbl.text` from 0 to `target` over `duration`, formatting each step
## with `fmt % value` (e.g. "+ %d Coins"), with a click tick per step.
func _animate_count_up(lbl: Label, target: int, fmt: String, duration: float = _COUNT_UP_DURATION) -> void:
	var steps: Array[int] = count_up_steps(target)
	lbl.text = fmt % 0
	var tw: Tween = lbl.create_tween()
	var step_dur: float = duration / float(steps.size())
	for v: int in steps:
		var captured_v: int = v
		tw.tween_interval(step_dur)
		tw.tween_callback(func() -> void:
			if is_instance_valid(lbl):
				lbl.text = fmt % captured_v
				AudioManager.play_sfx("ui_click")
		)

func start_banner_fade(banner: Control) -> void:
	var tween := _parent.create_tween()
	tween.tween_interval(_BOSS_BANNER_DURATION - 0.5)
	tween.tween_property(banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void:
		if is_instance_valid(banner):
			banner.queue_free()
		if _boss_banner == banner:
			_boss_banner = null
	)

# -------------------------------------------------------------------------
# Victory / defeat overlays
# -------------------------------------------------------------------------

func show_victory(reward_card_id: String, weapon_reward_id: String = "",
		sig_card_id: String = "", condition_text_arg: String = "", condition_met: bool = false,
		reward_rarity: String = "", reward_stats: Dictionary = {},
		coins_earned: int = 0, xp_earned: int = 0, hero_hp: int = 0,
		dawn_played: int = 0, dusk_played: int = 0) -> void:
	if _float_layer:
		_float_layer.hide()
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.92)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.03))

	var title_lbl := Label.new()
	title_lbl.text = "Victory!"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.06))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(1.0, 0.85, 0.2)
	vbox.add_child(title_lbl)

	var reward_lbl := Label.new()
	if reward_card_id != "":
		var tmpl: Dictionary = CardRegistry.get_template(reward_card_id)
		var card_name: String = str(tmpl.get("name", reward_card_id))
		var rarity_suffix: String = " [%s]" % reward_rarity.capitalize() if reward_rarity != "" else ""
		reward_lbl.text = "You earned: " + card_name + rarity_suffix
		if reward_rarity != "":
			reward_lbl.modulate = UiUtil.rarity_color(reward_rarity)
	else:
		reward_lbl.text = "No card dropped."
	reward_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(reward_lbl)

	if coins_earned > 0:
		var coins_lbl := Label.new()
		coins_lbl.add_theme_font_size_override("font_size", int(_vh * 0.026))
		coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coins_lbl.modulate = Color(1.0, 0.85, 0.3)
		vbox.add_child(coins_lbl)
		_animate_count_up(coins_lbl, coins_earned, "+ %d Coins")

	if xp_earned > 0:
		var xp_lbl := Label.new()
		xp_lbl.add_theme_font_size_override("font_size", int(_vh * 0.026))
		xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		xp_lbl.modulate = Color(0.5, 1.0, 0.7)
		vbox.add_child(xp_lbl)
		_animate_count_up(xp_lbl, xp_earned, "+ %d XP")

	if weapon_reward_id != "":
		var weapon: WeaponData = WeaponRegistry.get_weapon(weapon_reward_id)
		var weapon_lbl := Label.new()
		var wname: String = weapon.display_name if weapon != null else weapon_reward_id
		weapon_lbl.text = "Weapon found: " + wname
		weapon_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
		weapon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_lbl.modulate = Color(0.8, 1.0, 0.5)
		vbox.add_child(weapon_lbl)

	if sig_card_id != "" and condition_text_arg != "":
		var hunt_lbl := Label.new()
		hunt_lbl.text = "Soulbind: %s — %s" % [condition_text_arg, "MET" if condition_met else "not met"]
		hunt_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
		hunt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hunt_lbl.modulate = Color(0.7, 0.5, 1.0)
		hunt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(hunt_lbl)

	var btn := Button.new()
	btn.text = "Collect" if (reward_card_id != "" or weapon_reward_id != "") else "Continue"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	var final_card: String = reward_card_id
	var final_weapon: String = weapon_reward_id
	var final_rarity: String = reward_rarity
	var final_stats: Dictionary = reward_stats
	var veterancy_data: Dictionary = _collect_veterancy_fn.call() if _collect_veterancy_fn.is_valid() else {}
	var final_hp: int = hero_hp
	var final_dawn: int = dawn_played
	var final_dusk: int = dusk_played
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		GameBus.battle_won.emit({
			"card_reward": final_card,
			"weapon_reward": final_weapon,
			"hero_hp": final_hp,
			"veterancy": veterancy_data,
			"reward_rarity": final_rarity,
			"reward_stats": final_stats,
			"dawn_played": final_dawn,
			"dusk_played": final_dusk,
		})
	)
	vbox.add_child(btn)
	UiFx.attach(btn)

	overlay.add_child(vbox)
	_parent.add_child(overlay)

func show_soulbind(reward_card_id: String, sig_card_id: String, condition_text_arg: String, hero_hp: int = 0,
		dawn_played: int = 0, dusk_played: int = 0,
		reward_rarity: String = "", reward_stats: Dictionary = {}) -> void:
	if _float_layer:
		_float_layer.hide()
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.02, 0.12, 0.95)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.028))

	var title_lbl := Label.new()
	title_lbl.text = "Victory!"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.06))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(1.0, 0.85, 0.2)
	vbox.add_child(title_lbl)

	var soul_lbl := Label.new()
	soul_lbl.text = "Soulbind Achieved!"
	soul_lbl.add_theme_font_size_override("font_size", int(_vh * 0.04))
	soul_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soul_lbl.modulate = Color(0.8, 0.4, 1.0)
	vbox.add_child(soul_lbl)

	var cond_lbl := Label.new()
	cond_lbl.text = condition_text_arg
	cond_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	cond_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cond_lbl.modulate = Color(0.75, 0.6, 1.0)
	cond_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(cond_lbl)

	if reward_card_id != "":
		var rtmpl: Dictionary = CardRegistry.get_template(reward_card_id)
		var reward_lbl := Label.new()
		reward_lbl.text = "You earned: " + str(rtmpl.get("name", reward_card_id))
		reward_lbl.add_theme_font_size_override("font_size", int(_vh * 0.028))
		reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(reward_lbl)

	var stmpl: Dictionary = CardRegistry.get_template(sig_card_id)
	var sig_lbl := Label.new()
	sig_lbl.text = "Signature captured: " + str(stmpl.get("name", sig_card_id))
	sig_lbl.add_theme_font_size_override("font_size", int(_vh * 0.032))
	sig_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sig_lbl.modulate = Color(0.9, 0.5, 1.0)
	vbox.add_child(sig_lbl)

	var btn := Button.new()
	btn.text = "Collect All"
	btn.custom_minimum_size = Vector2(_vh * 0.22, _vh * 0.065)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.028))
	var fc: String = reward_card_id
	var sc: String = sig_card_id
	var sb_hp: int = hero_hp
	var sb_dawn: int = dawn_played
	var sb_dusk: int = dusk_played
	var sb_rarity: String = reward_rarity
	var sb_stats: Dictionary = reward_stats
	var sb_veterancy: Dictionary = _collect_veterancy_fn.call() if _collect_veterancy_fn.is_valid() else {}
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		GameBus.battle_won.emit({
			"card_reward": fc,
			"weapon_reward": "",
			"hero_hp": sb_hp,
			"signature_capture": sc,
			"dawn_played": sb_dawn,
			"dusk_played": sb_dusk,
			"reward_rarity": sb_rarity,
			"reward_stats": sb_stats,
			"veterancy": sb_veterancy,
		})
	)
	vbox.add_child(btn)
	UiFx.attach(btn)

	overlay.add_child(vbox)
	_parent.add_child(overlay)

func show_victory_boss(reward_cards: Array[String], weapon_reward_id: String = "",
		rarities: Array[String] = [], stats_list: Array[Dictionary] = [],
		coins_earned: int = 0, xp_earned: int = 0, hero_hp: int = 0,
		dawn_played: int = 0, dusk_played: int = 0) -> void:
	if _float_layer:
		_float_layer.hide()
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.92)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.025))

	var title_lbl := Label.new()
	title_lbl.text = "Boss Defeated!"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.06))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(1.0, 0.75, 0.0)
	vbox.add_child(title_lbl)

	if reward_cards.is_empty():
		var no_drop_lbl := Label.new()
		no_drop_lbl.text = "No cards dropped."
		no_drop_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
		no_drop_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(no_drop_lbl)
	else:
		for ri in range(reward_cards.size()):
			var cid: String = reward_cards[ri]
			var tmpl: Dictionary = CardRegistry.get_template(cid)
			var card_name: String = str(tmpl.get("name", cid))
			var rarity: String = rarities[ri] if ri < rarities.size() else ""
			var rlbl := Label.new()
			rlbl.text = card_name + (" [%s]" % rarity.capitalize() if rarity != "" else "")
			if rarity != "":
				rlbl.modulate = UiUtil.rarity_color(rarity)
			rlbl.add_theme_font_size_override("font_size", int(_vh * 0.028))
			rlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(rlbl)

	if coins_earned > 0:
		var coins_lbl := Label.new()
		coins_lbl.add_theme_font_size_override("font_size", int(_vh * 0.026))
		coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coins_lbl.modulate = Color(1.0, 0.85, 0.3)
		vbox.add_child(coins_lbl)
		_animate_count_up(coins_lbl, coins_earned, "+ %d Coins")

	if xp_earned > 0:
		var xp_lbl := Label.new()
		xp_lbl.add_theme_font_size_override("font_size", int(_vh * 0.026))
		xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		xp_lbl.modulate = Color(0.5, 1.0, 0.7)
		vbox.add_child(xp_lbl)
		_animate_count_up(xp_lbl, xp_earned, "+ %d XP")

	if weapon_reward_id != "":
		var weapon: WeaponData = WeaponRegistry.get_weapon(weapon_reward_id)
		var weapon_lbl := Label.new()
		var wname: String = weapon.display_name if weapon != null else weapon_reward_id
		weapon_lbl.text = "Weapon found: " + wname
		weapon_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
		weapon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_lbl.modulate = Color(0.8, 1.0, 0.5)
		vbox.add_child(weapon_lbl)

	var btn := Button.new()
	btn.text = "Collect" if (not reward_cards.is_empty() or weapon_reward_id != "") else "Continue"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	var final_rewards: Array[String] = []
	final_rewards.assign(reward_cards)
	var final_weapon: String = weapon_reward_id
	var final_rarities: Array[String] = []
	final_rarities.assign(rarities)
	var final_stats_list: Array[Dictionary] = stats_list.duplicate()
	var veterancy_data_boss: Dictionary = _collect_veterancy_fn.call() if _collect_veterancy_fn.is_valid() else {}
	var boss_hp: int = hero_hp
	var boss_dawn: int = dawn_played
	var boss_dusk: int = dusk_played
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		GameBus.battle_won.emit({
			"card_rewards": final_rewards,
			"weapon_reward": final_weapon,
			"hero_hp": boss_hp,
			"veterancy": veterancy_data_boss,
			"reward_rarities": final_rarities,
			"reward_stats_list": final_stats_list,
			"dawn_played": boss_dawn,
			"dusk_played": boss_dusk,
		})
	)
	vbox.add_child(btn)
	UiFx.attach(btn)

	overlay.add_child(vbox)
	_parent.add_child(overlay)

func show_duel_victory(wager: int) -> void:
	if _float_layer:
		_float_layer.hide()
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.1, 0.05, 0.92)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.03))

	var title_lbl := Label.new()
	title_lbl.text = "Duel Won!"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.06))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(0.4, 1.0, 0.4)
	vbox.add_child(title_lbl)

	var coins_lbl := Label.new()
	coins_lbl.text = "+%d coins" % wager if wager > 0 else "Wager was free!"
	coins_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
	coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_lbl.modulate = Color(1.0, 0.85, 0.2)
	vbox.add_child(coins_lbl)

	var btn := Button.new()
	btn.text = "Collect"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		if wager > 0:
			SceneManager.save_manager.add_coins(wager)
		GameBus.duel_won.emit()
	)
	vbox.add_child(btn)
	UiFx.attach(btn)

	overlay.add_child(vbox)
	_parent.add_child(overlay)

func show_duel_loss(wager: int) -> void:
	if _float_layer:
		_float_layer.hide()
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.05, 0.05, 0.92)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.03))

	var title_lbl := Label.new()
	title_lbl.text = "Duel Lost"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.06))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(1.0, 0.4, 0.4)
	vbox.add_child(title_lbl)

	var coins_lbl := Label.new()
	coins_lbl.text = "-%d coins" % wager if wager > 0 else "No wager."
	coins_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
	coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_lbl.modulate = Color(1.0, 0.6, 0.6)
	vbox.add_child(coins_lbl)

	var btn := Button.new()
	btn.text = "Continue"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		if wager > 0:
			SceneManager.save_manager.coins = maxi(0, SceneManager.save_manager.coins - wager)
			SceneManager.save_manager.save()
		GameBus.duel_lost.emit()
	)
	vbox.add_child(btn)
	UiFx.attach(btn)

	overlay.add_child(vbox)
	_parent.add_child(overlay)

## Ghost duel result (GID-102 / TID-377): a local, single-player battle against an
## AI-piloted snapshot of another (possibly offline) session member's deck — zero
## live networking. Unlike show_duel_victory/show_duel_loss, no coin amount is
## ever deducted here on a loss (nothing was staked against an offline AI
## opponent) — coin_reward is shown only on a win, and the actual grant happens
## exactly once in SceneManager._on_ghost_duel_ended (not on this button press,
## so mashing Continue can't double-award). The Continue button emits
## ghost_duel_ended; SceneManager restores the world exactly like an NPC duel.
func show_ghost_duel_result(did_win: bool, coin_reward: int) -> void:
	if _float_layer:
		_float_layer.hide()
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.1, 0.05, 0.92) if did_win else Color(0.1, 0.05, 0.05, 0.92)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.03))

	var title_lbl := Label.new()
	title_lbl.text = "Ghost Duel Won!" if did_win else "Ghost Duel Lost"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.06))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(0.4, 1.0, 0.4) if did_win else Color(1.0, 0.4, 0.4)
	vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "You bested their stored deck." if did_win else "Their stored deck bested you."
	sub_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_lbl)

	if did_win and coin_reward > 0:
		var coins_lbl := Label.new()
		coins_lbl.text = "+%d coins" % coin_reward
		coins_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
		coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coins_lbl.modulate = Color(1.0, 0.85, 0.2)
		vbox.add_child(coins_lbl)

	var btn := Button.new()
	btn.text = "Continue"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		GameBus.ghost_duel_ended.emit(did_win)
	)
	vbox.add_child(btn)
	UiFx.attach(btn)

	overlay.add_child(vbox)
	_parent.add_child(overlay)

## Scripted story battle result (GID-108) — fixed-deck tutorial battles like the
## rabbit hunt. battle_id is passed straight through to scripted_battle_ended so
## SceneManager can look up the completion flag / reward without BattleResultUI
## needing to know about ScriptedBattleData.
func show_scripted_result(did_win: bool, battle_id: String) -> void:
	if _float_layer:
		_float_layer.hide()
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.1, 0.05, 0.92) if did_win else Color(0.1, 0.05, 0.05, 0.92)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.03))

	var title_lbl := Label.new()
	title_lbl.text = "Victory!" if did_win else "Defeated"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.06))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(0.4, 1.0, 0.4) if did_win else Color(1.0, 0.4, 0.4)
	vbox.add_child(title_lbl)

	var btn := Button.new()
	btn.text = "Continue"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		GameBus.scripted_battle_ended.emit(battle_id, did_win)
	)
	vbox.add_child(btn)
	UiFx.attach(btn)

	overlay.add_child(vbox)
	_parent.add_child(overlay)

## PvP duel-style result (GID-091 / TID-368). did_win is from the local peer's
## perspective; coins_delta is the net coin change from any wager (positive = won,
## negative = lost, 0 = unwagered). The Continue button emits pvp_battle_ended,
## which SceneManager handles by restoring the shared co-op world.
## wager_note (GID-104 / TID-387): a spectator's bet-settlement line ("Bet won!
## +N coins" / "Bet lost: -N coins" / refund). "" (default) adds nothing, so
## every existing combatant call site renders exactly as before.
func show_pvp_result(did_win: bool, coins_delta: int = 0, wager_note: String = "") -> void:
	if _float_layer:
		_float_layer.hide()
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.1, 0.05, 0.92) if did_win else Color(0.1, 0.05, 0.05, 0.92)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.03))

	var title_lbl := Label.new()
	title_lbl.text = "Victory!" if did_win else "Defeated"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.06))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(0.4, 1.0, 0.4) if did_win else Color(1.0, 0.4, 0.4)
	vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "You bested your rival!" if did_win else "Your rival prevailed."
	sub_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_lbl)

	# Show wager result if a coin ante was staked (TID-368).
	if coins_delta != 0:
		var wager_lbl := Label.new()
		if coins_delta > 0:
			wager_lbl.text = "+%d coins (wagered)" % coins_delta
			wager_lbl.modulate = Color(1.0, 0.85, 0.3)
		else:
			wager_lbl.text = "%d coins (wagered)" % coins_delta
			wager_lbl.modulate = Color(1.0, 0.5, 0.5)
		wager_lbl.add_theme_font_size_override("font_size", int(_vh * 0.028))
		wager_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(wager_lbl)

	# Spectator bet settlement (GID-104 / TID-387) — gold for a win/refund, red for a loss.
	if wager_note != "":
		var note_lbl := Label.new()
		note_lbl.text = wager_note
		note_lbl.modulate = Color(1.0, 0.5, 0.5) if wager_note.begins_with("Bet lost") else Color(1.0, 0.85, 0.3)
		note_lbl.add_theme_font_size_override("font_size", int(_vh * 0.028))
		note_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(note_lbl)

	var btn := Button.new()
	btn.text = "Continue"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		GameBus.pvp_battle_ended.emit(did_win)
	)
	vbox.add_child(btn)
	UiFx.attach(btn)

	overlay.add_child(vbox)
	_parent.add_child(overlay)

func show_puzzle_fail_overlay(hint_text: String) -> void:
	var overlay := PanelContainer.new()
	overlay.name = "PuzzleFailOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.05, 0.05, 0.88)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.03))

	var lbl := Label.new()
	lbl.text = "Not quite — try again!"
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.05))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = Color(1.0, 0.5, 0.3)
	vbox.add_child(lbl)

	var hint_lbl := Label.new()
	hint_lbl.text = hint_text
	hint_lbl.add_theme_font_size_override("font_size", int(_vh * 0.028))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.modulate = Color(0.85, 0.85, 0.85)
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.custom_minimum_size = Vector2(_vh * 0.5, 0)
	vbox.add_child(hint_lbl)

	var btn := Button.new()
	btn.text = "Try Again"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	btn.pressed.connect(func() -> void: overlay.queue_free())
	vbox.add_child(btn)
	UiFx.attach(btn)

	overlay.add_child(vbox)
	_parent.add_child(overlay)

func show_puzzle_victory_overlay() -> void:
	var overlay := PanelContainer.new()
	overlay.name = "PuzzleVictoryOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.10, 0.04, 0.92)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.03))

	var title_lbl := Label.new()
	title_lbl.text = "Puzzle Solved!"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.06))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(0.4, 1.0, 0.5)
	vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Reward delivered to your collection."
	sub_lbl.add_theme_font_size_override("font_size", int(_vh * 0.028))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.modulate = Color(0.8, 1.0, 0.8)
	vbox.add_child(sub_lbl)

	var btn := Button.new()
	btn.text = "Continue"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		SceneManager.return_from_puzzle()
	)
	vbox.add_child(btn)
	UiFx.attach(btn)

	overlay.add_child(vbox)
	_parent.add_child(overlay)
