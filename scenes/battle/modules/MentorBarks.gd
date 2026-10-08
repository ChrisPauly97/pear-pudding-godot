## Maiteln's real-time coaching barks (GID-135 / TID-558): short, non-blocking
## speech-bubble tips shown during a new player's early real-time fights.
##
## Owned by `BattleRealtime` (`BattleRealtime.mentor_barks`), created by
## `maybe_start()` only when `BarkRules.is_eligible()` — inert (never created)
## outside the `CombatOnboarding` ramp or without Maiteln equipped as Mentor.
## Rate limiting and line selection are pure (`BarkRules`); this module only
## watches the fight for a moment worth narrating and renders the bubble.
## Reach the scene as `_battle.<name>`.
extends RefCounted

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const _BattleRealtime = preload("res://scenes/battle/modules/BattleRealtime.gd")
const _BarkRules = preload("res://game_logic/battle/BarkRules.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const _TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")

const _PORTRAIT := preload("res://assets/textures/characters/npc_maiteln.png")
const _BUBBLE_DURATION: float = 3.0

var _battle: _BattleScene
var _realtime: _BattleRealtime
var _elapsed: float = 0.0
var _last_bark_at: float = -1.0
var _seen_counts: Dictionary = {}
## One-shot moments a caller (the Kick technique card) reports out of band —
## consumed (and cleared) the next `on_frame`.
var _queued: Array[String] = []
## Technique cards in hand last frame (a rise = one came back round, GID-175).
var _prev_techniques: int = 0
var _bubble: CanvasLayer = null


func _init(battle: _BattleScene, realtime: _BattleRealtime) -> void:
	_battle = battle
	_realtime = realtime

## Reported by `BattleRealtime.note_skill_used` right after a successful `Kick`.
func queue(id: String) -> void:
	if not _queued.has(id):
		_queued.append(id)

## Called every real-time tick from `BattleRealtime._process`, after
## `RealtimeCombat.advance()`.
func on_frame(delta: float, events: Array[Dictionary]) -> void:
	_elapsed += delta
	var candidates: Array[String] = _candidates(events)
	var id: String = _BarkRules.next_bark(candidates, _elapsed, _last_bark_at, _seen_counts)
	if id == "":
		return
	_last_bark_at = _elapsed
	_seen_counts[id] = int(_seen_counts.get(id, 0)) + 1
	_show_bubble(_BarkRules.text_for(id))

## Priority order: an interrupt just landed or a fresh cast telegraph are the
## most teachable moments, then a skill coming off cooldown or an ally ready,
## then the player's own state.
func _candidates(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	out.append_array(_queued)
	_queued.clear()
	for ev: Dictionary in events:
		match str(ev.get("type", "")):
			"enemy_cast_start", "enemy_heavy_start":
				out.append("cast_bar")
			"ally_ready":
				out.append("ally_ready")
	out.append_array(_cooldown_candidates())
	var rt: RealtimeCombat = _realtime.rt
	var hero := rt.state.players[RealtimeCombat.PLAYER].hero
	if hero.is_alive() and hero.max_health > 0 and float(hero.health) / float(hero.max_health) <= 0.3:
		out.append("low_hp")
	if hero.mana <= 0:
		out.append("mana_empty")
	return out

## A technique card came back into the hand since last frame (GID-175: deck
## cycling is the cooldown now).
func _cooldown_candidates() -> Array[String]:
	var out: Array[String] = []
	var n: int = 0
	for c: CardInstance in _realtime.rt.state.players[RealtimeCombat.PLAYER].hand:
		if _TechniqueDefs.is_technique(c.template_id):
			n += 1
	if n > _prev_techniques:
		out.append("cooldown_ready")
	_prev_techniques = n
	return out

func _show_bubble(text: String) -> void:
	if text == "":
		return
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.queue_free()
	var vh: float = _battle._vh
	var vw: float = _battle.get_viewport().get_visible_rect().size.x
	var layer := CanvasLayer.new()
	layer.layer = 140  # above the board, below the intent banner / battle overlays
	_battle.add_child(layer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _UiUtil.make_style(Color(0.1, 0.08, 0.16, 0.92), 8))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(vh * 0.34, 0.0)
	layer.add_child(panel)
	var row := _UiUtil.make_hbox(int(vh * 0.015), panel)
	var portrait := TextureRect.new()
	portrait.texture = _PORTRAIT
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(vh * 0.07, vh * 0.07)
	row.add_child(portrait)
	var lbl := _UiUtil.make_label(text, int(vh * 0.02), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, row)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(vh * 0.24, 0.0)
	# Top-center: clear of the SidePanel (top-left), the enemy hero token
	# (top-right) and the bottom action strip / hand / onboarding spotlight.
	panel.size = panel.get_combined_minimum_size()
	panel.position = Vector2((vw - panel.size.x) * 0.5, vh * 0.02)
	_bubble = layer
	var tween: Tween = layer.create_tween()
	tween.tween_interval(_BUBBLE_DURATION - 0.4)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
		if _bubble == layer:
			_bubble = null
	)
