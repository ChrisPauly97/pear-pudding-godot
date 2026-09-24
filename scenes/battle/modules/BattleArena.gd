## Arena presentation: backdrop, battlefield info label and banner, slot highlights, and
## the co-op ally panels.
##
## A child of BattleScene (`BattleScene.arena`), created by `_ensure_battle_modules()`.
## Battle state stays on the scene. Reach it as `_battle.<name>`, and use
## `_battle.add_child` rather than a bare `add_child`.
extends Node

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const BattleBackdrop = preload("res://scenes/battle/BattleBackdrop.gd")

var _battle: _BattleScene


func _init(battle: _BattleScene) -> void:
	_battle = battle


## Paints the Background rect with the biome-aware battle backdrop (GID-126).
## Reads the same biome + day/night pair Battlefield Resonance stamped into
## GameState, so the scenery always matches the ground the encounter began on.
## The rect keeps its flat colour underneath as the fallback, so a missing
## shader degrades to the pre-GID-126 look rather than to nothing.
func _setup_backdrop() -> void:
	var bg := _battle.get_node_or_null("Background") as ColorRect
	if bg == null:
		return
	var biome: int = _battle._state.battlefield_biome if _battle._state != null else BattleBackdrop.NEUTRAL
	var night: bool = _battle._state.is_night if _battle._state != null else false
	BattleBackdrop.apply(bg, biome, night)

## Adds a persistent compact label in SidePanel showing biome name and day/night indicator.
func _add_battlefield_info_label() -> void:
	var biome: int = _battle._state.battlefield_biome
	if biome == -1:
		return
	var night: bool = _battle._state.is_night
	var sun_moon: String = "☽" if night else "☀"
	var info_lbl := _UiUtil.make_label("%s %s" % [BattlefieldRules.get_biome_name(biome), sun_moon],
			int(_battle._font(0.02)))
	info_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_battle.get_node("SidePanel").add_child(info_lbl)
	_battle._battlefield_info_label = info_lbl

## Adds coloured overlay panels on affected board slots (Forest 0/4, Mountains 2).
func _add_slot_highlights() -> void:
	var highlights: Array[int] = BattlefieldRules.get_slot_highlights(_battle._state.battlefield_biome)
	if highlights.is_empty():
		return
	var tint: Color = Color(0.4, 0.9, 1.0, 0.18)  # distinct from cyan spell-target and yellow attack
	for board_view in [_battle._player_board_view, _battle._enemy_board_view]:
		for si in highlights:
			var overlay := ColorRect.new()
			overlay.color = tint
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var slot_lbl := _UiUtil.make_label("★", int(_battle._font(0.018)))
			slot_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 0.7))
			slot_lbl.set_meta("bf_slot_idx", si)
			board_view.add_child(overlay)
			board_view.add_child(slot_lbl)
			_battle._slot_highlight_panels.append(overlay)
			_battle._slot_highlight_panels.append(slot_lbl)

## Shows a transient banner at battle start with the biome rule text.
## Deferred so the scene is fully set up before showing.
func _show_battlefield_banner() -> void:
	var biome: int = _battle._state.battlefield_biome
	if biome == -1:
		return
	var night: bool = _battle._state.is_night
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var panel := PanelContainer.new()
	var style := _UiUtil.make_style(Color(0.08, 0.08, 0.16, 0.88), 8, Color(0.4, 0.9, 1.0, 0.6), 2)
	panel.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var title_lbl := Label.new()
	var time_str: String = "Night" if night else "Day"
	title_lbl.text = "%s — %s" % [BattlefieldRules.get_biome_name(biome), time_str]
	title_lbl.add_theme_font_size_override("font_size", _battle._font(0.028))
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rule_lbl := _UiUtil.make_label(BattlefieldRules.get_rule_text(biome), int(_battle._font(0.021)))
	rule_lbl.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	rule_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_lbl)
	vbox.add_child(rule_lbl)
	panel.add_child(vbox)
	panel.custom_minimum_size = Vector2(vp.x * 0.55, _battle._vh * 0.12)
	panel.position = Vector2((vp.x - panel.custom_minimum_size.x) * 0.5, _battle._vh * 0.3)
	if _battle._float_layer != null:
		_battle._float_layer.add_child(panel)
	else:
		_battle.add_child(panel)
	_battle._battlefield_banner = panel
	var tw: Tween = panel.create_tween()
	tw.tween_interval(_battle._BATTLEFIELD_BANNER_DURATION)
	tw.tween_callback(panel.queue_free)
	tw.tween_callback(func() -> void: _battle._battlefield_banner = null)

# Builds (or rebuilds) the top ally bar showing compact hero panels for each
# non-boss player. Tapping a panel during ally targeting resolves the spell.
func _build_coop_arena_layout() -> void:
	if not _battle._coop_pve or _battle._state == null:
		return
	# Remove stale panels
	for p in _battle._coop_ally_panels:
		if is_instance_valid(p):
			p.queue_free()
	_battle._coop_ally_panels.clear()

	var boss_idx: int = _battle._state.players.size() - 1
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = _battle._vh * 0.08
	_battle.add_child(bar)
	_battle._coop_ally_panels.append(bar)

	for pidx in range(_battle._state.players.size()):
		if pidx == boss_idx:
			continue
		var ps: PlayerState = _battle._state.players[pidx]
		var btn := _UiUtil.make_button(
				"P%d  HP:%d/%d  Mana:%d" % [pidx + 1, ps.hero.health, ps.hero.max_health, ps.hero.mana],
				Vector2(_battle._vh * 0.20, _battle._vh * 0.06))
		if _battle._ally_targeting_active:
			var cap_pidx: int = pidx  # capture for lambda
			btn.pressed.connect(func() -> void:
				if _battle._ally_targeting_spell != null:
					_battle.targeting._resolve_ally_spell(_battle._ally_targeting_spell, cap_pidx)
			)
		bar.add_child(btn)
	_battle._coop_arena_built = true

func _refresh_coop_ally_panels() -> void:
	if not _battle._coop_pve or _battle._state == null:
		return
	if not _battle._coop_arena_built:
		_build_coop_arena_layout()
		return
	var boss_idx: int = _battle._state.players.size() - 1
	var btn_idx: int = 0
	# bar is the first (and only) element in _coop_ally_panels
	if _battle._coop_ally_panels.is_empty():
		return
	var bar: HBoxContainer = _battle._coop_ally_panels[0] as HBoxContainer
	if bar == null or not is_instance_valid(bar):
		return
	for pidx in range(_battle._state.players.size()):
		if pidx == boss_idx:
			continue
		var ps: PlayerState = _battle._state.players[pidx]
		var btn: Button = bar.get_child(btn_idx) as Button
		if btn != null:
			btn.text = "P%d  HP:%d/%d  Mana:%d" % [pidx + 1, ps.hero.health, ps.hero.max_health, ps.hero.mana]
		btn_idx += 1
