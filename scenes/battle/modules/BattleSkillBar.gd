## Real-time skill bar (GID-135 / TID-550): one button per `SkillBar` slot in
## the bottom action strip beside the hand, with a cooldown sweep (its own
## cooldown or the GCD, whichever is longer) and seconds left; keys 1–3 on
## desktop. Casts go through `BattleRealtime.run_cast`, so
## they share the GCD, spell queue, cast bar and pushback with deck spells.
##
## Owned by `BattleRealtime` (`skills`); parents its widgets under the action
## strip, never a module node.
extends RefCounted

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const _BattleRealtime = preload("res://scenes/battle/modules/BattleRealtime.gd")
const SkillBar = preload("res://game_logic/battle/SkillBar.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

var bar: SkillBar
var _battle: _BattleScene
var _realtime: _BattleRealtime
var _buttons: Array[Button] = []
## Per slot: the dark overlay that shrinks as the cooldown runs out.
var _shades: Array[ColorRect] = []

func _init(battle: _BattleScene, realtime: _BattleRealtime, saved_bar: Array) -> void:
	_battle = battle
	_realtime = realtime
	bar = SkillBar.new(saved_bar)

func build(parent: Control) -> void:
	var vh: float = _battle._vh
	for i: int in bar.ids.size():
		var d: Dictionary = bar.def_at(i)
		var btn := _UiUtil.make_button("", Vector2(vh * 0.1, vh * 0.09), int(_battle._font(0.019)),
				press.bind(i), parent)
		btn.tooltip_text = "%s — %d mana, %ds cooldown. %s" % [str(d["name"]), int(d["cost"]),
			roundi(float(d["cooldown"])), str(d["desc"])]
		var shade := ColorRect.new()
		shade.color = Color(0.0, 0.0, 0.0, 0.6)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.add_child(shade)
		_buttons.append(btn)
		_shades.append(shade)

## Per-frame: ticks the cooldowns and redraws the buttons.
func update(dt: float) -> void:
	bar.advance(dt)
	var rt: RealtimeCombat = _realtime.rt
	for i: int in _buttons.size():
		var d: Dictionary = bar.def_at(i)
		var left: float = bar.cooldown_left(i)
		var label: String = "%d %s\n%d" % [i + 1, str(d["name"]), int(d["cost"])]
		if left > 0.0:
			label = "%d %s\n%.0fs" % [i + 1, str(d["name"]), ceilf(left)]
		_buttons[i].text = label
		# The shade covers the unready part, draining from the top like a sweep.
		# On-GCD skills also show the global cooldown (WoW's sweep on every button).
		var frac: float = bar.fraction(i)
		if not bool(d.get("off_gcd", false)):
			frac = minf(frac, rt.gcd_fraction(RealtimeCombat.PLAYER))
		_shades[i].anchor_top = frac
		var usable: bool = bar.blocker(i, rt) == ""
		var tint: Color = Color.WHITE if usable else Color(0.7, 0.7, 0.75)
		# An interrupt that's ready while an enemy casts pulses: react without looking up.
		if usable and str(d.get("effect", "")) == "interrupt":
			var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
			tint = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.55, 0.3), pulse)
		_buttons[i].modulate = tint

## Button / key press on `slot`.
func press(slot: int) -> void:
	var rt: RealtimeCombat = _realtime.rt
	if rt == null or _battle._state.is_game_over() or _realtime.is_blocked() or _battle._action_busy:
		return
	var why: String = bar.blocker(slot, rt)
	if why != "":
		_realtime.toast(why)
		return
	var d: Dictionary = bar.def_at(slot)
	if _realtime.is_casting():
		return
	var off_gcd: bool = bool(d.get("off_gcd", false))
	if not off_gcd and _realtime.on_cooldown():
		return
	var cast: float = float(d.get("cast", 0.0))
	if cast > 0.0:
		var card := CardInstance.new({"id": "ability_" + bar.ids[slot], "name": str(d["name"]), "cost": 0,
			"card_class": "spell"})
		card.set_meta("cost_points", int(d["cost"]))
		_realtime.run_cast(card, _resolve.bind(slot), null, cast)
		return
	if not off_gcd:
		rt.start_gcd(RealtimeCombat.PLAYER)
	_resolve(slot)

func _resolve(slot: int) -> void:
	var rt: RealtimeCombat = _realtime.rt
	if bar.blocker(slot, rt) != "":
		_realtime.toast("%s fizzled" % str(bar.def_at(slot)["name"]))
		return
	var snap: Array[Dictionary] = _battle._fx.snapshot()
	var out: Dictionary = bar.apply(slot, rt)
	if out.is_empty():
		return
	bar.start_cooldown(slot, rt.tune.get_f("skill_cooldown"))
	AudioManager.play_sfx("attack" if str(bar.def_at(slot)["effect"]) == "damage" else "spell_resolve")
	var side: int = int(out.get("side", RealtimeCombat.ENEMY))
	if side == RealtimeCombat.PLAYER:
		_battle._fx.spawn_float_label(_realtime.hero_screen_pos(RealtimeCombat.PLAYER), str(out["text"]),
				Color(0.267, 1.0, 0.533))
	elif out.has("target"):
		_realtime.lunge_at(out.get("target") as CardInstance, side)
	else:
		_realtime.toast(str(out["text"]))
	_battle._fx.trigger_fx(snap)
	_battle._animate_deaths_from_snapshot(snap)
	_battle._refresh_all()
	_battle._check_game_over()
