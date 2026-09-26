## Real-time battle presentation (GID-135 / TID-546, adds TID-551), owned by
## `BattleRealtime`: hero tokens (a box with the hero / enemy sprite, its hero
## strip, swing bar and — for enemies — cast bar) that lunge on auto-attack,
## per-unit readiness / wind-up bars, unit lunges on enemy swings, the player
## cast bar, and a token + diagonal row for each enemy that joins mid-fight.
##
## Everything is parented under one full-rect Control added to the battle scene
## (mouse-transparent), never to a module node.
extends RefCounted

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")
const _PLAYER_TEX := preload("res://assets/textures/characters/player_hero.png")
const _DiagonalBoard = preload("res://scenes/battle/modules/DiagonalBoard.gd")

const READY_COLOR := Color(0.35, 1.0, 0.45)
const CHARGING_COLOR := Color(0.45, 0.75, 1.0)
const ENEMY_BAR_COLOR := Color(1.0, 0.6, 0.3)
## Enemy units past this swing fraction visibly wind up (grow + redden).
const WIND_UP_FROM: float = 0.7
## Gap between a hero token and its own front line, as a fraction of card width.
const ROW_GAP: float = 0.12

## Joined enemies (adds): side -> their board row (HBoxContainer + DiagonalBoard)
## and hero strip (PanelContainer refreshed by CardViewBuilder).
var add_rows: Dictionary = {}
var add_hero_views: Dictionary = {}
var _battle: _BattleScene
var _root: Control
## side -> PanelContainer token / Vector2 home (global) / ProgressBar swing bar /
## {"box", "label", "bar"} enemy cast readout inside the token.
var _tokens: Dictionary = {}
var _token_home: Dictionary = {}
var _token_bars: Dictionary = {}
var _token_casts: Dictionary = {}
var _cast_panel: PanelContainer
var _cast_lbl: Label
var _cast_bar: ProgressBar
## BattleRealtime's cooldown / auto-attack / target box, placed bottom-right.
var _strip: Control = null
## Ring around your current target (focused minion, else the targeted enemy token).
var _focus_ring: Panel = null

func _init(battle: _BattleScene) -> void:
	_battle = battle

func build(enemy_type: String, is_boss: bool) -> void:
	_root = Control.new()
	_root.name = "RealtimeVisuals"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle.add_child(_root)
	_tokens[RealtimeCombat.PLAYER] = _make_token(_PLAYER_TEX, _battle._player_hero_view, RealtimeCombat.PLAYER)
	_tokens[RealtimeCombat.ENEMY] = _make_token(
			_SpriteRegistry.enemy_texture(enemy_type, false, is_boss), _battle._enemy_hero_view, RealtimeCombat.ENEMY)
	var cast := _make_cast_panel(CHARGING_COLOR)
	_cast_panel = cast["panel"]
	_cast_lbl = cast["label"]
	_cast_bar = cast["bar"]
	_setup_arena()
	_battle.get_viewport().size_changed.connect(apply_layout)
	apply_layout.call_deferred()

## Diagonal arena: the hero strips move into the tokens, both boards leave the
## stacked VBoxes and become free-placed diagonal rows over the arena, and the
## hand drops to the bottom of the player area.
func _setup_arena() -> void:
	for board: HBoxContainer in [_battle._enemy_board_view, _battle._player_board_view]:
		board.reparent(_battle, false)
		board.set_script(_DiagonalBoard)
		board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle.move_child(_root, -1)
	var divider: Control = _battle.get_node_or_null("Divider") as Control
	if divider != null:
		divider.visible = false
	var player_area: BoxContainer = _battle.get_node_or_null("PlayerArea") as BoxContainer
	if player_area != null:
		player_area.alignment = BoxContainer.ALIGNMENT_END
	# No side column any more: the hand (and the enemy area) centre on the full width.
	for area_name: String in ["PlayerArea", "EnemyArea"]:
		var area: Control = _battle.get_node_or_null(area_name) as Control
		if area != null:
			area.anchor_right = 1.0
	_battle._mana_label.visible = false  # mana lives on your hero token

## Places both board rows and tokens for the current viewport: you bottom-left,
## the enemy top-right, each side's slots stepping top-left → bottom-right.
func apply_layout() -> void:
	if _root == null:
		return
	var vp: Vector2 = _battle.get_viewport().get_visible_rect().size
	var vh: float = vp.y
	# The arena spans the whole width (centred in the scene); the hand sits below it.
	var arena := Vector2(vp.x, vh - _battle._player_hand_view.get_combined_minimum_size().y - vh * 0.03)
	var card: Vector2 = _battle._view.card_size()
	var step := Vector2(card.x * 0.95, card.y * 0.30)
	for side: Variant in _tokens.keys():
		var tok: PanelContainer = _tokens[side]
		tok.size = tok.get_combined_minimum_size()
	var p_tok: Vector2 = (_tokens[RealtimeCombat.PLAYER] as PanelContainer).size
	var e_tok: Vector2 = (_tokens[RealtimeCombat.ENEMY] as PanelContainer).size
	var margin: float = vh * 0.015
	var lay: Dictionary = arena_layout(arena, card, step, p_tok, e_tok, margin)
	_place_board(_battle._enemy_board_view, lay["enemy"], step, arena)
	_place_board(_battle._player_board_view, lay["player"], step, arena)
	_token_home[RealtimeCombat.PLAYER] = lay["player_token"]
	_token_home[RealtimeCombat.ENEMY] = lay["enemy_token"]
	# Each add stacks under the previous enemy token (room left for its cast bar),
	# its front line attached to its left like the first enemy's.
	var above: Rect2 = Rect2(lay["enemy_token"], e_tok)
	for side: Variant in add_rows.keys():
		var tok: PanelContainer = _tokens[side]
		var home := Vector2(arena.x - tok.size.x - margin, above.end.y + vh * 0.07)
		_token_home[side] = home
		var row_origin := Vector2(home.x - card.x * ROW_GAP - card.x - step.x * float(RealtimeCombat.MAX_ENEMY_MINIONS - 1),
				home.y)
		_place_board(add_rows[side] as HBoxContainer, row_origin, step, arena)
		above = Rect2(home, tok.size)
	for side: Variant in _tokens.keys():
		var t: PanelContainer = _tokens[side]
		if not t.has_meta("lunging"):
			t.global_position = _token_home[side]
	_place_corner_panels(vp, margin)

## Pure: tokens in opposite corners (you bottom-left, the enemy top-right) and
## each side's front line attached to its own hero — yours just right of your
## token, bottom-aligned with it; theirs just left of theirs, top-aligned — so
## the open middle of the arena is the gap the two lines face across.
static func arena_layout(arena: Vector2, card: Vector2, step: Vector2, p_tok: Vector2, e_tok: Vector2,
		margin: float) -> Dictionary:
	var gap_x: float = card.x * ROW_GAP
	var p_home := Vector2(margin, arena.y - p_tok.y)
	var e_home := Vector2(arena.x - e_tok.x - margin, margin)
	var p_rows: int = RealtimeCombat.MAX_ALLIES
	var e_rows: int = RealtimeCombat.MAX_ENEMY_MINIONS
	var player := Vector2(p_home.x + p_tok.x + gap_x, arena.y - card.y - step.y * float(p_rows - 1))
	var enemy := Vector2(e_home.x - gap_x - card.x - step.x * float(e_rows - 1), margin)
	return {"player": player, "enemy": enemy, "player_token": p_home, "enemy_token": e_home}

## Utility controls fill the two empty corners, level with a hero each: the
## side panel (pause, Effects, battlefield info) top-left beside the enemy's
## band, your cooldown / auto-attack / target box in the screen's bottom-right corner.
func _place_corner_panels(vp: Vector2, margin: float) -> void:
	var side: Control = _battle.get_node_or_null("SidePanel") as Control
	if side != null:
		side.set_anchors_preset(Control.PRESET_TOP_LEFT)
		side.size = side.get_combined_minimum_size()
		side.position = Vector2(margin, margin)
	_place_strip(vp, margin)

## The action strip sits at the bottom, just left of the hand, so what you press
## and what you cast from stay in one band.
func _place_strip(vp: Vector2, margin: float) -> void:
	if _strip == null:
		return
	_strip.size = _strip.get_combined_minimum_size()
	# The hand row spans the width with its cards centred: hug the leftmost card.
	var left: float = _battle._player_hand_view.get_global_rect().get_center().x
	for c: Node in _battle._player_hand_view.get_children():
		var ctl := c as Control
		if ctl != null and ctl.visible:
			left = minf(left, ctl.get_global_rect().position.x)
	var x: float = maxf(margin, left - _strip.size.x - margin)
	_strip.position = Vector2(x, vp.y - _strip.size.y - margin)

func _place_board(board: HBoxContainer, origin: Vector2, step: Vector2, arena: Vector2) -> void:
	board.position = Vector2.ZERO
	board.size = arena
	board.set("origin", origin)
	board.set("step", step)
	board.queue_sort()

## A hero token: sprite on top, the scene's hero view (name, HP bar, mana /
## hand count — still refreshed by CardViewBuilder, still the hero tap target)
## reparented under it, and the auto-attack swing bar.
func _make_token(tex: Texture2D, hero_view: PanelContainer, side: int) -> PanelContainer:
	var vh: float = _battle._vh
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(vh * 0.24, 0.0)
	var edge: Color = Color(0.4, 0.6, 1.0) if side == RealtimeCombat.PLAYER else Color(1.0, 0.4, 0.35)
	panel.add_theme_stylebox_override("panel", _UiUtil.make_style(Color(0.08, 0.08, 0.12, 0.92), 6, edge, 2))
	var vbox := _UiUtil.make_vbox(int(vh * 0.004), panel)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.texture = tex
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(0.0, vh * 0.13)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if side != RealtimeCombat.PLAYER:
		pic.flip_h = true
	vbox.add_child(pic)
	hero_view.reparent(vbox, false)
	hero_view.custom_minimum_size = Vector2(0.0, vh * 0.09)
	var bar := _make_bar(vh * 0.012, ENEMY_BAR_COLOR if side != RealtimeCombat.PLAYER else Color(1.0, 0.75, 0.45))
	vbox.add_child(bar)
	_token_bars[side] = bar
	if side != RealtimeCombat.PLAYER:
		# The enemy's cast bar lives in its own token, so several enemies never collide.
		var cast_box := _UiUtil.make_vbox(0, vbox)
		cast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cl := _UiUtil.make_label("", int(_battle._font(0.022)), Color(1.0, 0.85, 0.6),
				HORIZONTAL_ALIGNMENT_CENTER, cast_box)
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var cb := _make_bar(vh * 0.026, ENEMY_BAR_COLOR)
		cast_box.add_child(cb)
		cast_box.visible = false
		_token_casts[side] = {"box": cast_box, "label": cl, "bar": cb}
	_tokens[side] = panel
	_root.add_child(panel)
	return panel

func _make_bar(h: float, tint: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, h)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.modulate = tint
	return bar

func _make_cast_panel(tint: Color) -> Dictionary:
	var vh: float = _battle._vh
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(vh * 0.5, 0.0)
	panel.add_theme_stylebox_override("panel", _UiUtil.make_style(Color(0.05, 0.05, 0.09, 0.9), 6, tint, 2))
	var vbox := _UiUtil.make_vbox(int(vh * 0.004), panel)
	var lbl := _UiUtil.make_label("", int(_battle._font(0.022)), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	var bar := _make_bar(vh * 0.02, tint)
	vbox.add_child(bar)
	panel.visible = false
	_root.add_child(panel)
	return {"panel": panel, "label": lbl, "bar": bar}

## Per-frame: token placement + bars, unit readiness / wind-up, cast bars.
func update(rt: RealtimeCombat, player_cast: Dictionary) -> void:
	if _root == null:
		return
	for side: Variant in _tokens.keys():
		var tok: PanelContainer = _tokens[side]
		if not tok.has_meta("lunging"):
			tok.global_position = _token_home.get(side, tok.global_position)
		(_token_bars[side] as ProgressBar).value = rt.hero_swing_fraction(int(side))
		# A fallen enemy's token greys out.
		if int(side) != RealtimeCombat.PLAYER:
			tok.modulate = Color.WHITE if rt.is_alive(int(side)) else Color(0.45, 0.45, 0.45, 0.8)
			_update_enemy_cast(rt, int(side))
	_update_units(rt, RealtimeCombat.PLAYER, _battle._player_board_view)
	_update_units(rt, RealtimeCombat.ENEMY, _battle._enemy_board_view)
	for side: Variant in add_rows.keys():
		_update_units(rt, int(side), add_rows[side] as Control)
	_update_player_cast(player_cast)
	_place_strip(_battle.get_viewport().get_visible_rect().size, _battle._vh * 0.015)
	_update_focus_ring(rt)

func _update_focus_ring(rt: RealtimeCombat) -> void:
	if _focus_ring == null:
		_focus_ring = Panel.new()
		_focus_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_focus_ring.add_theme_stylebox_override("panel", _UiUtil.make_style(Color(0, 0, 0, 0), 8,
				Color(1.0, 0.85, 0.3), 3))
		_focus_ring.z_index = 15
		_root.add_child(_focus_ring)
	var target: Control = null
	if rt.focus_target != null:
		target = unit_panel(rt.focus_target, rt.owner_of(rt.focus_target))
	if target == null:
		target = _tokens.get(rt.target_enemy()) as Control
	_focus_ring.visible = target != null and rt.is_alive(rt.target_enemy())
	if target != null:
		var pad: float = _battle._vh * 0.008
		var r: Rect2 = target.get_global_rect().grow(pad)
		_focus_ring.global_position = r.position
		_focus_ring.size = r.size

func token_center(side: int) -> Vector2:
	var tok: PanelContainer = _tokens.get(side) as PanelContainer
	return tok.get_global_rect().get_center() if tok != null else _battle._fx.pos_of_hero(side != RealtimeCombat.PLAYER)

func _update_units(rt: RealtimeCombat, side: int, board_view: Control) -> void:
	var board_slots: Array = _battle._state.players[side].board.slots
	for child in board_view.get_children():
		if not (child is PanelContainer):
			continue
		var panel := child as PanelContainer
		var idx: int = int(panel.get_meta("slot_idx", -1))
		if idx < 0 or idx >= board_slots.size():
			continue
		if board_slots[idx] == null:
			# Empty slots past the real-time unit cap would only mislead.
			panel.visible = idx < _battle._state.players[side].max_units
			continue
		var card: CardInstance = board_slots[idx] as CardInstance
		var vbox: VBoxContainer = panel.get_child(0) as VBoxContainer if panel.get_child_count() > 0 else null
		if vbox == null:
			continue
		var bar: ProgressBar = vbox.get_node_or_null("SwingBar") as ProgressBar
		if bar == null:
			bar = _make_bar(_battle._vh * 0.012, CHARGING_COLOR)
			bar.name = "SwingBar"
			vbox.add_child(bar)
		var frac: float = rt.swing_fraction(card)
		if side == RealtimeCombat.PLAYER:
			var ready: bool = card.can_attack()
			bar.value = 1.0 if ready else frac
			bar.modulate = READY_COLOR if ready else CHARGING_COLOR
			var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
			panel.modulate = Color.WHITE.lerp(Color(0.8, 1.2, 0.8), pulse) if ready else Color.WHITE
		else:
			bar.value = frac
			bar.modulate = ENEMY_BAR_COLOR
			_wind_up(panel, frac)

## Enemy wind-up: grow and redden over the last part of the swing timer.
func _wind_up(panel: Control, frac: float) -> void:
	if panel.has_meta("lunge_home") and panel.position != panel.get_meta("lunge_home"):
		return  # mid-lunge
	var w: float = clampf((frac - WIND_UP_FROM) / (1.0 - WIND_UP_FROM), 0.0, 1.0)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * (1.0 + 0.08 * w)
	panel.modulate = Color.WHITE.lerp(Color(1.3, 0.6, 0.55), w)

func _update_player_cast(cast: Dictionary) -> void:
	if cast.is_empty():
		_cast_panel.visible = false
		return
	_cast_panel.visible = true
	_cast_lbl.text = "Casting %s  (%d mana)" % [str(cast["name"]), int(cast["cost"])]
	_cast_bar.value = float(cast["fraction"])
	var hand_r: Rect2 = _battle._player_hand_view.get_global_rect()
	var sz: Vector2 = _cast_panel.get_combined_minimum_size()
	_cast_panel.size = sz
	_cast_panel.global_position = Vector2(hand_r.get_center().x - sz.x * 0.5,
			hand_r.position.y - sz.y - _battle._vh * 0.01)

func _update_enemy_cast(rt: RealtimeCombat, side: int) -> void:
	var ui: Dictionary = _token_casts.get(side, {})
	if ui.is_empty():
		return
	var c: CardInstance = rt.casting[side] as CardInstance
	var box: Control = ui["box"]
	box.visible = c != null
	if c == null:
		return
	var cost: int = _battle._state.players[side].effective_cost(c)
	(ui["label"] as Label).text = "Casting %s (%d)" % [c.name, cost]
	(ui["bar"] as ProgressBar).value = clampf(1.0 - rt.cast_remaining[side] / rt.tune.get_f("enemy_cast"), 0.0, 1.0)

## Lunge a hero token toward `target_pos` and back.
func lunge_token(side: int, target_pos: Vector2) -> void:
	var tok: PanelContainer = _tokens.get(side) as PanelContainer
	if tok == null or tok.has_meta("lunging"):
		return
	tok.set_meta("lunging", true)
	var home: Vector2 = tok.global_position
	var out: Vector2 = home + (target_pos - tok.get_global_rect().get_center()) * 0.45
	tok.z_index = 20
	var tw: Tween = tok.create_tween()
	tw.tween_property(tok, "global_position", out, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(tok, "global_position", home, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		if is_instance_valid(tok):
			tok.z_index = 0
			tok.remove_meta("lunging"))

## Screen position of a swing's target: a unit panel, or the target side's token.
func target_pos(target: CardInstance, target_side: int) -> Vector2:
	if target != null:
		var p: Control = unit_panel(target, target_side)
		if p != null:
			return p.get_global_rect().get_center()
	return token_center(target_side)

## Short floating message above the hand (fizzles, etc.).
func toast(text: String) -> void:
	var lbl := _UiUtil.make_label(text, int(_battle._font(0.026)), Color(1.0, 0.7, 0.4), HORIZONTAL_ALIGNMENT_CENTER,
			_root)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	var hand_r: Rect2 = _battle._player_hand_view.get_global_rect()
	lbl.size = lbl.get_combined_minimum_size()
	lbl.global_position = Vector2(hand_r.get_center().x - lbl.size.x * 0.5, hand_r.position.y - _battle._vh * 0.12)
	var tw: Tween = lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.6)
	tw.finished.connect(lbl.queue_free)

func set_action_strip(box: Control) -> void:
	_strip = box
	box.reparent(_root, false)

## The on-screen panel of `card` on `side`'s board (main rows via BattleFx,
## an add's row by slot), or null.
func unit_panel(card: CardInstance, side: int) -> Control:
	if not add_rows.has(side):
		return _battle._fx.get_card_panel(card, side != RealtimeCombat.PLAYER)
	var slot: int = _battle._state.players[side].board.slots.find(card)
	for child in (add_rows[side] as Node).get_children():
		if child is Control and int((child as Control).get_meta("slot_idx", -1)) == slot:
			return child as Control
	return null

## Builds the token, hero strip and diagonal row for an enemy that joined the
## fight. `hero_input` is bound to the strip so taps target this enemy.
func add_enemy_view(side: int, enemy_type: String, is_boss: bool, hero_input: Callable) -> void:
	var hero_view := PanelContainer.new()
	hero_view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hero_view.gui_input.connect(hero_input)
	_root.add_child(hero_view)
	add_hero_views[side] = hero_view
	_make_token(_SpriteRegistry.enemy_texture(enemy_type, false, is_boss), hero_view, side)
	var row := HBoxContainer.new()
	row.name = "AddBoardView%d" % side
	_battle.add_child(row)
	row.set_script(_DiagonalBoard)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle.move_child(_root, -1)
	add_rows[side] = row
	apply_layout()
