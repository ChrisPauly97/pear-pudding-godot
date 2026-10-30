## Playtest metrics (GID-188 / TID-799): listens to GameBus and records the slice's
## fun signals into `SaveManager.playtest` through `PlaytestMetrics`. Play time
## ticks once a second while a game is running (any state but the main menu).
##
## Owned by SaveManager (`SaveManager.playtest_log`), created in its `_init`; `start()`
## wires the signals and the clock once SaveManager is in the tree. The field stays
## on SaveManager because PERSISTED_FIELDS walks its properties.
extends RefCounted

const _SaveManager = preload("res://autoloads/SaveManager.gd")
const _PlaytestMetrics = preload("res://game_logic/PlaytestMetrics.gd")
const _SceneFlow = preload("res://game_logic/SceneFlow.gd")
const _SliceRules = preload("res://game_logic/SliceRules.gd")

const TICK_S: float = 1.0

var _save: _SaveManager


func _init(save_manager: _SaveManager) -> void:
	_save = save_manager

## Connects the GameBus signals and starts the play clock (SaveManager._ready).
func start() -> void:
	GameBus.enemy_engaged.connect(func(_d: Dictionary) -> void: note(_PlaytestMetrics.FIGHT))
	GameBus.battle_won.connect(_on_won)
	GameBus.battle_lost.connect(func() -> void: note(_PlaytestMetrics.LOSS))
	GameBus.level_up.connect(func(_l: int) -> void: note(_PlaytestMetrics.LEVEL))
	GameBus.feature_learned.connect(func(_id: String) -> void: note(_PlaytestMetrics.LEARN))
	GameBus.quest_turned_in.connect(func(_id: String) -> void: note(_PlaytestMetrics.QUEST))
	GameBus.story_flag_set.connect(_on_flag)
	var timer := Timer.new()
	timer.wait_time = TICK_S
	timer.autostart = true
	timer.timeout.connect(_tick)
	_save.add_child(timer)

func note(event: String) -> void:
	_PlaytestMetrics.note(_save.playtest, event)
	_save.mark_dirty()

## A new game or Continue (SaveManager.new_game / SceneManager continue).
func note_session() -> void:
	note(_PlaytestMetrics.SESSION)

func report() -> Array[String]:
	return _PlaytestMetrics.summary(_save.playtest)

func _on_won(result: Dictionary) -> void:
	note(_PlaytestMetrics.WIN)
	if str(result.get("signature_capture", "")) != "":
		note(_PlaytestMetrics.CAPTURE)

func _on_flag(flag: String) -> void:
	if flag == _SliceRules.COMPLETE_FLAG:
		note(_PlaytestMetrics.SLICE_COMPLETE)

func _tick() -> void:
	if SceneManager.current_state() != _SceneFlow.State.MENU:
		_PlaytestMetrics.tick(_save.playtest, TICK_S)
