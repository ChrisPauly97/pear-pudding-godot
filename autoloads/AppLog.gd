extends Node

const MAX_ENTRIES: int = 200

var _entries: Array[Dictionary] = []

func _ready() -> void:
	GameBus.enemy_engaged.connect(func(d: Dictionary) -> void:
		info("Battle started: %s" % str(d.get("enemy_type", "?"))))
	GameBus.battle_won.connect(func(_r: Dictionary) -> void:
		info("Battle won"))
	GameBus.battle_lost.connect(func() -> void:
		info("Battle lost"))
	GameBus.hud_message_requested.connect(func(msg: String) -> void:
		info("HUD: %s" % msg))
	GameBus.achievement_unlocked.connect(func(id: String) -> void:
		info("Achievement: %s" % id))
	GameBus.level_up.connect(func(lvl: int) -> void:
		info("Level up: %d" % lvl))
	GameBus.story_flag_set.connect(func(flag: String) -> void:
		info("Flag: %s" % flag))
	GameBus.story_scroll_collected.connect(func(sid: String) -> void:
		info("Scroll: %s" % sid))
	GameBus.entered_named_map.connect(func(map_name: String) -> void:
		info("Map: %s" % map_name))
	GameBus.world_event_started.connect(func(eid: String) -> void:
		info("Event started: %s" % eid))
	GameBus.world_event_ended.connect(func(eid: String) -> void:
		info("Event ended: %s" % eid))
	GameBus.bounty_completed.connect(func(bid: String) -> void:
		info("Bounty done: %s" % bid))
	GameBus.siege_victory.connect(func() -> void:
		info("Siege victory"))
	GameBus.siege_defeated.connect(func(coins_lost: int) -> void:
		warn("Siege defeated: lost %d coins" % coins_lost))
	GameBus.rival_encounter_won.connect(func(n: int) -> void:
		info("Rival win #%d" % n))
	GameBus.weather_changed.connect(func(wid: String, _dur: float) -> void:
		info("Weather: %s" % wid))
	info("AppLog ready")

func info(msg: String) -> void:
	_push("INFO", msg)
	print(msg)

func warn(msg: String) -> void:
	_push("WARN", msg)
	push_warning(msg)

func error(msg: String) -> void:
	_push("ERROR", msg)
	push_error(msg)

func get_entries() -> Array[Dictionary]:
	return _entries.duplicate()

func clear() -> void:
	_entries.clear()

func _push(level: String, msg: String) -> void:
	var ts: float = Time.get_ticks_msec() / 1000.0
	_entries.push_back({"ts": ts, "level": level, "msg": msg})
	if _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
