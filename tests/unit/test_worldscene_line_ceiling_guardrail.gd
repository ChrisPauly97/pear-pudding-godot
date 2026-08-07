## Anti-regrowth regression guard (BID-055).
##
## WorldScene.gd was once 9154 lines / 401 functions — 13% of all GDScript in
## the repo in a single file, 9x the project's own `max-file-lines: 500` limit.
## GID-072 decomposed it once (ChunkRenderer, ChunkStreamingManager,
## DayNightCycle, Minimap, NetSync, WeatherParticles, WorldHUD,
## DungeonSessionUI, plus the four scenes/world/coop/*.gd modules) but nothing
## enforced staying decomposed, so everything shipped afterward landed straight
## back into WorldScene.gd.
##
## BID-055 slice 1 (co-op/net cluster) moved the file's residual
## `_coop_*`/`_broadcast_*`/RPC-handler network-sync functions (guildhall
## garden sync + co-op scroll-collection sync — see CoopSession.gd's "Party
## Guildhall" and "Co-op world-object sync" sections) into
## `scenes/world/coop/CoopSession.gd`, which already owned "world-object sync"
## and "guildhall" per docs/agent/multiplayer-coop.md. Slices 2 (`_spawn_*` ->
## a WorldEntitySpawner) and 3 (`_start_*` mode routing) remain future work —
## see tasks/backlog/BID-055--worldscene-god-object.md's Progress section.
##
## This is a static line-count guard, not a function-level one: it exists so a
## future feature can't silently pile back onto WorldScene.gd the way GID-096
## through GID-122 did after GID-072. When a future slice lands, ratchet
## _CEILING down to just above the new post-extraction size — never raise it to
## accommodate growth; that defeats the guard's purpose. If a legitimate
## feature addition needs more room than the current ceiling allows, that's a
## signal to look for the next extraction opportunity, not to loosen the guard.
extends "res://tests/framework/test_case.gd"

const _WORLD_SCENE_PATH := "res://scenes/world/WorldScene.gd"

## Post-slice-1 size is 3786 lines; this leaves a little slack for small
## incidental changes without inviting a slow climb back toward the old 9154.
const _CEILING := 3850


func test_worldscene_stays_under_line_ceiling() -> void:
	var f := FileAccess.open(_WORLD_SCENE_PATH, FileAccess.READ)
	assert_true(f != null, "could not read " + _WORLD_SCENE_PATH)
	if f == null:
		return
	var text: String = f.get_as_text()
	f.close()

	var line_count: int = text.split("\n").size()
	assert_true(line_count <= _CEILING,
		"WorldScene.gd is %d lines, over the %d-line guardrail ceiling (BID-055). If this growth is intentional and reviewed, extract another coherent cluster into a coop/ module (or elsewhere) rather than raising the ceiling — see tasks/backlog/BID-055--worldscene-god-object.md." % [line_count, _CEILING])
