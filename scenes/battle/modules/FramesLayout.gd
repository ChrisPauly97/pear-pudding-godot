## Frames layout for real-time battles (GID-189): an opt-in alternative to the
## diagonal arena (Settings › Battle › Battle Layout = "Frames").
##
##   * Your hero token becomes a unit frame top-left (portrait beside name / HP /
##     mana / swing bar); the enemy's becomes the target frame top-right, its cast
##     bar under the HP. Warnings (toasts) show on a plate in the top-centre lane.
##   * Allies sit as small frames in a row under yours, enemy minions under the
##     target: the board rows are scaled down, so every tap target still works.
##   * Frames never lunge; the fight happens in the world. When the battle is fought
##     in place (GID-135), swings nudge the real sprites, hits and floating numbers
##     land on them, other characters are dimmed and world name tags hidden — all
##     restored when the battle closes. Off-world (detached) fights use the frames.
##   * Pause / Effects move to the bottom-left corner; the hand stays the bottom bar.
##
## Owned by `RealtimeVisuals` (built only when `enabled()`); the classic layout is
## untouched. Pure placement lives in `frames_layout` (tested).
extends RefCounted

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

const SETTING: String = "battle_layout"
const CLASSIC: String = "classic"
const FRAMES: String = "frames"
## Settings › Battle Layout options, in order.
const MODES: Array[String] = [CLASSIC, FRAMES]
const MODE_LABELS: Array[String] = ["Classic", "Frames (new)"]

## Frame width and portrait size (fractions of viewport height).
const FRAME_W: float = 0.5
const PORTRAIT: float = 0.11
## Ally / enemy-minion frames: board cards scaled to this.
const UNIT_SCALE: float = 0.6
## Non-combatant characters in the world while you fight.
const DIM := Color(0.42, 0.42, 0.48, 0.55)
## How far a world sprite steps toward its target on a swing (fraction of the gap).
const LUNGE_FRAC: float = 0.35

var _battle: _BattleScene
var _root: Control
## side -> PanelContainer frame (the reparented hero token).
var _frames: Dictionary = {}
var _warn: PanelContainer = null
var _warn_lbl: Label = null
var _warn_tween: Tween = null
## Top-centre point the warning plate hangs from (set by `apply`).
var _warn_anchor: Vector2 = Vector2.ZERO
## The enemy side your hero is attacking (from `update`), for world lunges.
var _target_side: int = RealtimeCombat.ENEMY
var _ring: Panel = null
## World focus: the frozen world, combatant nodes by side, and what we changed.
var _world: _WorldScene = null
var _fighters: Dictionary = {}
var _dimmed: Array[Dictionary] = []
var _hidden_tags: Array[Label3D] = []

static func enabled() -> bool:
	return str(SaveManager.get_setting(SETTING, CLASSIC)) == FRAMES

func _init(battle: _BattleScene, root: Control) -> void:
	_battle = battle
	_root = root
	_root.tree_exiting.connect(_release_world)

# ---------------------------------------------------------------- frames

## Turns a hero token (PanelContainer > VBox[pic, hero view, pips, swing bar, cast])
## into a horizontal frame: portrait beside the rest, portrait outermost.
func adopt_token(side: int, tok: PanelContainer) -> void:
	var vh: float = _battle._vh
	var vbox := tok.get_child(0) as VBoxContainer
	var pic := vbox.get_child(0) as TextureRect
	var row := _UiUtil.make_hbox(int(vh * 0.012))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tok.remove_child(vbox)
	tok.add_child(row)
	vbox.remove_child(pic)
	pic.custom_minimum_size = Vector2(vh * PORTRAIT, vh * PORTRAIT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if side == RealtimeCombat.PLAYER:
		row.add_child(pic)
		row.add_child(vbox)
	else:
		row.add_child(vbox)
		row.add_child(pic)
	tok.custom_minimum_size = Vector2(vh * FRAME_W, 0.0)
	_frames[side] = tok

## Pure: where everything goes for viewport `vp`. `frames` = side → frame size
## (stacked down the right for adds), `unit` = one scaled unit frame.
static func frames_layout(vp: Vector2, player_frame: Vector2, enemy_frames: Array[Vector2], unit: Vector2,
		margin: float) -> Dictionary:
	var out: Dictionary = {}
	out["player"] = Vector2(margin, margin)
	out["allies"] = Vector2(margin, margin + player_frame.y + margin)
	var enemies: Array[Vector2] = []
	var minions: Array[Vector2] = []
	var y: float = margin
	for sz: Vector2 in enemy_frames:
		var pos := Vector2(vp.x - sz.x - margin, y)
		enemies.append(pos)
		minions.append(Vector2(vp.x - margin - unit.x * float(RealtimeCombat.MAX_ENEMY_MINIONS)
				- margin * 0.5 * float(RealtimeCombat.MAX_ENEMY_MINIONS - 1), y + sz.y + margin))
		y += sz.y + margin + unit.y + margin
	out["enemies"] = enemies
	out["minions"] = minions
	return out

## Places frames, unit rows, the warning lane and the corner panel.
func apply(tokens: Dictionary, add_rows: Dictionary, homes: Dictionary) -> void:
	var vp: Vector2 = _battle.get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var margin: float = vh * 0.02
	var card: Vector2 = _battle._view.card_size()
	var unit: Vector2 = card * UNIT_SCALE
	var enemy_sides: Array[int] = []
	var enemy_sizes: Array[Vector2] = []
	for side: Variant in tokens.keys():
		var t: PanelContainer = tokens[side]
		t.size = t.get_combined_minimum_size()
		if int(side) != RealtimeCombat.PLAYER:
			enemy_sides.append(int(side))
			enemy_sizes.append(t.size)
	var p_tok: PanelContainer = tokens[RealtimeCombat.PLAYER]
	var lay: Dictionary = frames_layout(vp, p_tok.size, enemy_sizes, unit, margin)
	homes[RealtimeCombat.PLAYER] = lay["player"]
	var e_pos: Array[Vector2] = lay["enemies"]
	var m_pos: Array[Vector2] = lay["minions"]
	for i: int in enemy_sides.size():
		homes[enemy_sides[i]] = e_pos[i]
		var row: HBoxContainer = _battle._enemy_board_view if enemy_sides[i] == RealtimeCombat.ENEMY \
				else add_rows.get(enemy_sides[i]) as HBoxContainer
		if row != null:
			_place_row(row, m_pos[i], card, margin)
	_place_row(_battle._player_board_view, lay["allies"], card, margin)
	for side: Variant in tokens.keys():
		(tokens[side] as Control).global_position = homes[side]
	# Warnings take the free top-centre lane between the two frames.
	_warn_anchor = Vector2(vp.x * 0.5, margin)
	_place_warn()
	var side_panel: Control = _battle.get_node_or_null("SidePanel") as Control
	if side_panel != null:
		side_panel.size = side_panel.get_combined_minimum_size()
		side_panel.position = Vector2(margin, vp.y - side_panel.size.y - margin)

## A board row as a scaled, left-to-right row of small unit frames at `origin`.
func _place_row(row: HBoxContainer, origin: Vector2, card: Vector2, margin: float) -> void:
	row.scale = Vector2(UNIT_SCALE, UNIT_SCALE)
	row.position = origin
	row.size = Vector2(card.x * 4.0, card.y)
	row.set("origin", Vector2.ZERO)
	row.set("step", Vector2(card.x + margin, 0.0))
	row.queue_sort()

## Per frame: the warning lane follows, Ally frames hide while minions are locked,
## and the world target ring sits under the current target's sprite.
func update(rt: RealtimeCombat, allies_locked: bool, tokens: Dictionary, add_rows: Dictionary,
		homes: Dictionary) -> void:
	apply(tokens, add_rows, homes)  # frames grow as cast bars / pips appear: re-place every frame
	_battle._player_board_view.visible = not allies_locked
	_target_side = rt.target_enemy()
	_update_ring(rt)

# ---------------------------------------------------------------- warning lane

## Shows `text` on the warning plate under the target frame, then fades it.
func toast(text: String) -> void:
	if _warn == null:
		var vh: float = _battle._vh
		_warn = PanelContainer.new()
		_warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := _UiUtil.make_style(Color(0.06, 0.06, 0.1, 0.92), int(vh * 0.012), Color(1.0, 0.75, 0.3), 2)
		sb.set_content_margin_all(vh * 0.01)
		_warn.add_theme_stylebox_override("panel", sb)
		_warn_lbl = _UiUtil.make_label("", int(_battle._font(0.024)), Color(1.0, 0.85, 0.45),
				HORIZONTAL_ALIGNMENT_CENTER, _warn)
		_root.add_child(_warn)
	_warn_lbl.text = text
	_warn.modulate.a = 1.0
	_warn.visible = true
	_warn.reset_size()
	if _warn_tween != null and _warn_tween.is_valid():
		_warn_tween.kill()
	_warn_tween = _warn.create_tween()
	_warn_tween.tween_property(_warn, "modulate:a", 0.0, 0.5).set_delay(2.2)
	_place_warn()

func _place_warn() -> void:
	if _warn == null:
		return
	_warn.size = _warn.get_combined_minimum_size()
	_warn.global_position = Vector2(_warn_anchor.x - _warn.size.x * 0.5, _warn_anchor.y)

# ---------------------------------------------------------------- world focus

## Finds the frozen world and the fighters; dims everyone else and hides name tags.
## No-op for detached (off-world) fights.
func focus_world() -> void:
	_world = SceneManager.held_world() as _WorldScene
	if _world == null or not _world.is_inside_tree():
		_world = null
		return
	_fighters[RealtimeCombat.PLAYER] = _world._player
	var ids: Array[String] = SceneManager.battle_enemy_ids()
	for i: int in ids.size():
		var n: Node3D = _world._valid_node3d(_world._enemy_nodes.get(ids[i]))
		if n != null:
			_fighters[RealtimeCombat.ENEMY + i] = n
	# Hits on the heroes (BattleFx damage numbers) land on the fighters too.
	_battle._fx.hero_point_fn = func(is_enemy: bool, fallback: Vector2) -> Vector2:
		return hero_point(_target_side if is_enemy else RealtimeCombat.PLAYER, fallback)
	_frame_fight()
	for eid: Variant in _world._enemy_nodes.keys():
		var n: Node3D = _world._valid_node3d(_world._enemy_nodes[eid])
		if n != null and not _fighters.values().has(n):
			_dim(n)
	for l: Node in _world.find_children("*", "Label3D", true, false):
		var tag := l as Label3D
		if tag.visible:
			tag.visible = false
			_hidden_tags.append(tag)

## Slides the frozen camera so the fight (midpoint of you and the enemy) sits in the
## open middle of the screen, clear of the frames. The world camera follows the
## player again by itself once the battle ends and the world thaws.
func _frame_fight() -> void:
	var me: Node3D = _fighter(RealtimeCombat.PLAYER)
	var foe: Node3D = _fighter(RealtimeCombat.ENEMY)
	var cam: Camera3D = _world._camera
	if me == null or foe == null or cam == null:
		return
	var shift: Vector3 = (foe.global_position - me.global_position) * 0.5
	shift.y = 0.0
	_battle.get_tree().create_tween().tween_property(cam, "position", cam.position + shift, 0.35) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _dim(n: Node3D) -> void:
	for s: Node in n.find_children("*", "SpriteBase3D", true, false):
		var sp := s as SpriteBase3D
		_dimmed.append({"sprite": sp, "was": sp.modulate})
		sp.modulate = DIM

func _release_world() -> void:
	for d: Dictionary in _dimmed:
		var sp: Variant = d["sprite"]
		if is_instance_valid(sp):
			(sp as SpriteBase3D).modulate = d["was"] as Color
	_dimmed.clear()
	for tag: Label3D in _hidden_tags:
		if is_instance_valid(tag):
			tag.visible = true
	_hidden_tags.clear()

## Screen point of `side`'s fighter in the world, or its frame centre off-world.
func hero_point(side: int, fallback: Vector2) -> Vector2:
	var n: Node3D = _fighter(side)
	var cam: Camera3D = _battle.get_viewport().get_camera_3d()
	if n == null or cam == null:
		return fallback
	return cam.unproject_position(n.global_position + Vector3(0.0, 1.2, 0.0))

func _fighter(side: int) -> Node3D:
	if _world == null:
		return null
	var v: Variant = _fighters.get(side)
	return v as Node3D if is_instance_valid(v) else null

## A swing: `side`'s world sprite steps toward its target (your hero → your
## target enemy, an enemy → your hero) and back. Frames stay put. The sprite child
## moves, not the body: a frozen physics body keeps drawing at its last physics tick.
func lunge(side: int) -> void:
	var n: Node3D = _fighter(side)
	var t: Node3D = _fighter(_target_side if side == RealtimeCombat.PLAYER else RealtimeCombat.PLAYER)
	if n == null or t == null:
		return
	var sprites: Array[Node] = n.find_children("*", "SpriteBase3D", true, false)
	if sprites.is_empty() or sprites[0].has_meta("frames_lunging"):
		return
	var sp := sprites[0] as Node3D
	sp.set_meta("frames_lunging", true)
	var home: Vector3 = sp.position
	var reach: Vector3 = (t.global_position - n.global_position) * LUNGE_FRAC
	reach.y = 0.0
	var out: Vector3 = home + (sp.get_parent() as Node3D).global_transform.basis.inverse() * reach
	var tw: Tween = _root.create_tween()
	tw.tween_property(sp, "position", out, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sp, "position", home, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		if is_instance_valid(sp):
			sp.remove_meta("frames_lunging"))

## Red ellipse under the targeted enemy's sprite (in-world fights only).
func _update_ring(rt: RealtimeCombat) -> void:
	var n: Node3D = _fighter(rt.target_enemy())
	var cam: Camera3D = _battle.get_viewport().get_camera_3d()
	if _ring == null:
		_ring = Panel.new()
		_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.3, 0.25, 0.12)
		sb.border_color = Color(1.0, 0.4, 0.35, 0.95)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(int(_battle._vh * 0.07))
		_ring.add_theme_stylebox_override("panel", sb)
		_root.add_child(_ring)
		_root.move_child(_ring, 0)
	_ring.visible = n != null and cam != null and rt.is_alive(rt.target_enemy())
	if _ring.visible:
		var w: float = _battle._vh * 0.13
		_ring.size = Vector2(w, w * 0.44)
		_ring.position = cam.unproject_position(n.global_position) - Vector2(w * 0.5, w * 0.22)
