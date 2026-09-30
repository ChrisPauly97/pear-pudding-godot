## Enemy token frames in real-time battles (GID-152 / TID-646): the enemy's
## picture winds up and strikes on its swings, flinches when its hero loses
## health, and crumples when it falls. Frames from CombatFrames (derived by
## tools/derive_combat_frames.py); tweens swap the TextureRect's texture.
extends RefCounted

const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const _CombatFrames = preload("res://game_logic/CombatFrames.gd")

## Seconds per frame: [wind-up, strike, recover], flinch, each death step.
const ATTACK_TIMES: Array[float] = [0.05, 0.14, 0.12]
const HIT_TIME: float = 0.14
const DEATH_STEP: float = 0.12

var _pics: Dictionary = {}    # side -> TextureRect
var _idle: Dictionary = {}    # side -> idle Texture2D
var _frames: Dictionary = {}  # side -> CombatFrames.for_idle() result
var _tweens: Dictionary = {}  # side -> Tween
var _hp: Dictionary = {}      # side -> last seen hero health
var _dead: Dictionary = {}    # side -> true once the death played


## Tracks an enemy token's picture; ignored for sprites without combat frames.
func register(side: int, pic: TextureRect) -> void:
	var f: Dictionary = _CombatFrames.for_idle(pic.texture)
	if f.is_empty():
		return
	_pics[side] = pic
	_idle[side] = pic.texture
	_frames[side] = f


func attack(side: int) -> void:
	if not _frames.has(side) or _dead.has(side):
		return
	var seq: Array[Texture2D] = []
	seq.assign(_frames[side]["attack"] as Array)
	_play(side, seq, ATTACK_TIMES, true)


## Per-frame check of every tracked side's hero: flinch on damage, die once.
func observe(rt: RealtimeCombat) -> void:
	for side: Variant in _pics.keys():
		var s: int = int(side)
		if _dead.has(s) or s >= rt.state.players.size():
			continue
		var hp: int = rt.state.players[s].hero.health
		if not rt.is_alive(s):
			_dead[s] = true
			var death: Array[Texture2D] = []
			death.assign(_frames[s]["death"] as Array)
			_play(s, death, [DEATH_STEP, DEATH_STEP, DEATH_STEP], false)
		elif _hp.has(s) and hp < int(_hp[s]) and not _busy(s):
			var hit: Array[Texture2D] = [_frames[s]["hit"] as Texture2D]
			_play(s, hit, [HIT_TIME], true)
		_hp[s] = hp


func _busy(side: int) -> bool:
	var tw: Tween = _tweens.get(side) as Tween
	return tw != null and tw.is_valid() and tw.is_running()


## Shows `seq` (frame i for times[i] s); back to the idle after when `settle`.
func _play(side: int, seq: Array[Texture2D], times: Array[float], settle: bool) -> void:
	var pic: TextureRect = _pics.get(side) as TextureRect
	if pic == null or not is_instance_valid(pic):
		return
	var prev: Tween = _tweens.get(side) as Tween
	if prev != null and prev.is_valid():
		prev.kill()
	var tw: Tween = pic.create_tween()
	for i: int in seq.size():
		tw.tween_callback(func() -> void: pic.texture = seq[i])
		tw.tween_interval(times[mini(i, times.size() - 1)])
	if settle:
		var idle: Texture2D = _idle[side]
		tw.tween_callback(func() -> void: pic.texture = idle)
	_tweens[side] = tw
