## Headless smoke test for the co-op PvE boss AI turn index bug (BID-027).
##
## Not part of the auto-discovered unit suite (tests/runner.gd) — it instantiates a
## real BattleScene.tscn and drives async AI-turn coroutines across several real
## seconds of wall-clock delay, the same reasoning net_pvp_smoke.gd/world_scene_smoke.gd
## give for staying standalone. Run on demand:
##
##   godot --headless --path . -s tests/coop_pve_ai_turn_smoke.gd
##
## Exit code 0 = pass, 1 = fail.
##
## What it proves: `BattleScene._execute_ai_actions` used to hardcode
## `_state.players[1]` for the AI's own board-diff/emergence-effect bookkeeping.
## In co-op PvE with >= 2 allies the boss sits at `players.size() - 1` (index 2 for
## a 2-ally battle), never index 1 — so the boss's own emergence-effect minions had
## their effect silently dropped (the diff was computed against ally-1's untouched
## board, which never shows a "new card"). The fix resolves the AI's own index via
## `_opp_idx()` (correct for both solo AI battles and co-op-PvE boss turns, since
## `_run_ai_turn` only ever runs on the host with `_local_player_idx == 0`).
##
## Setup: a 2-ally co-op battle whose boss deck is entirely "dusk_seer" (cost 3,
## emergence_effect = emergence_draw, power 1). The boss can't afford to play one
## until its own 3rd turn (mana == its own turn number, capped at 10). Once it does,
## a correctly-resolved emergence effect draws the card straight back out of the
## discard pile it just paid to leave — net hand size unchanged. Under the bug the
## draw never happens, so hand size drops by exactly 1. Ally-1's hand/board are also
## asserted untouched throughout every boss turn (the module-owned-state guardrail
## this bug's class of index confusion threatens generally).
extends SceneTree

# Loaded at runtime (not top-level preload) — BattleScene.gd references autoload
# singletons (SceneManager, etc.) at parse time, which aren't registered as global
# identifiers yet while this script itself is still being compiled. Mirrors
# world_scene_smoke.gd's `load(_WorldScenePath)` inside `_run()` for the same reason.
const _BattleScenePath: String = "res://scenes/battle/BattleScene.tscn"

const _ALLY_DECK: Array[String] = ["ghost", "skeleton", "zombie", "ghoul",
	"ghost", "skeleton", "zombie", "ghoul", "ghost", "skeleton", "zombie", "ghoul"]

const _BOSS_DECK: Array[String] = ["dusk_seer", "dusk_seer", "dusk_seer", "dusk_seer",
	"dusk_seer", "dusk_seer", "dusk_seer", "dusk_seer", "dusk_seer", "dusk_seer",
	"dusk_seer", "dusk_seer"]

const _MAX_ROTATIONS: int = 4
const _MAX_WAIT_FRAMES: int = 600


func _initialize() -> void:
	_go()

func _go() -> void:
	await process_frame
	var ok: bool = await _run()
	print("\ncoop_pve_ai_turn_smoke: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _run() -> bool:
	# Reached via get_node_or_null(), not the bare "SceneManager" identifier —
	# referencing an autoload by name at parse time races its registration when
	# this script is itself the SceneTree's main script (mirrors
	# world_scene_smoke.gd's identical workaround).
	var scene_manager: Node = root.get_node_or_null("SceneManager")
	if scene_manager == null:
		print("  [FAIL] SceneManager autoload not found under /root")
		return false
	var save_manager: Object = scene_manager.get("save_manager")
	if save_manager == null:
		print("  [FAIL] SceneManager.save_manager not found")
		return false
	save_manager.call("set_setting", "battle_speed", "fast")

	var packed: PackedScene = load(_BattleScenePath)
	var battle: Node = packed.instantiate()
	battle.name = "BattleScene"
	battle.set("_coop_pve", true)
	battle.set("_local_player_idx", 0)
	battle.set("_coop_ally_decks", [_ALLY_DECK.duplicate(), _ALLY_DECK.duplicate()])
	battle.enemy_data = {
		"enemy_type": "undead_basic",
		"is_boss": false,
		"boss_hp": 30,
		"enemy_deck": _BOSS_DECK,
	}
	root.add_child(battle)
	await process_frame
	await process_frame

	var state = battle.get("_state")
	if state == null:
		print("  [FAIL] co-op battle state did not initialize")
		return false
	var boss_idx: int = state.players.size() - 1
	if boss_idx < 2:
		print("  [FAIL] expected boss index >= 2 for a 2-ally co-op battle, got %d" % boss_idx)
		return false
	print("  [PASS] boss sits at index %d (never the hardcoded 1)" % boss_idx)

	var saw_boss_play_a_card: bool = false
	var emergence_draw_confirmed: bool = false

	for _rotation in range(_MAX_ROTATIONS):
		if state.is_game_over():
			break
		# Drive ally 0's and ally 1's turns manually (no local UI in this test —
		# mirrors what _on_end_turn() does on the host: state.end_turn() directly).
		# Ally 1's own start_turn() legitimately draws a card here — that's normal
		# play, not the bug this test guards against — so the "must not change"
		# watermark below is taken AFTER this, isolating just the boss's turn.
		state.end_turn()
		if state.current_player_idx != boss_idx:
			state.end_turn()
		if state.current_player_idx != boss_idx:
			print("  [FAIL] expected boss's turn after 2 end_turn() calls, got idx %d" \
				% state.current_player_idx)
			return false

		# _on_turn_ended already ran synchronously off the signal above and kicked
		# off _run_ai_turn()'s synchronous prefix (persona/action decision); the
		# board-diff/emergence bookkeeping this test targets only happens after its
		# first `await`, so it's safe to snapshot both players' hand/board right now.
		var ally1_hand_watermark: int = state.players[1].hand.size()
		var ally1_board_watermark: int = state.players[1].board.get_cards().size()
		var boss_hand_before: int = state.players[boss_idx].hand.size()
		var boss_board_before: int = state.players[boss_idx].board.get_cards().size()

		var settled := false
		for _i in range(_MAX_WAIT_FRAMES):
			await process_frame
			if state.current_player_idx != boss_idx or state.is_game_over():
				settled = true
				break
		if not settled:
			print("  [FAIL] boss AI turn never completed (timed out)")
			return false

		if state.players[1].hand.size() != ally1_hand_watermark \
				or state.players[1].board.get_cards().size() != ally1_board_watermark:
			print("  [FAIL] ally-1's hand/board changed during the boss's turn — " +
				"boss AI bookkeeping touched the wrong player index")
			return false

		var boss_hand_after: int = state.players[boss_idx].hand.size()
		var boss_board_after: int = state.players[boss_idx].board.get_cards().size()
		if boss_board_after > boss_board_before:
			saw_boss_play_a_card = true
			# Played (-1 hand) + a correctly-resolved emergence_draw (+1 hand) nets to 0.
			# Under the bug the emergence effect is silently dropped: net -1.
			if boss_hand_after - boss_hand_before == 0:
				emergence_draw_confirmed = true
			print("  [INFO] boss played dusk_seer: hand %d -> %d (delta %d)" \
				% [boss_hand_before, boss_hand_after, boss_hand_after - boss_hand_before])

	print("  [PASS] ally-1's hand/board were never touched during any boss turn")

	if not saw_boss_play_a_card:
		print("  [FAIL] boss never played a dusk_seer within %d rotations (test setup issue, " \
			% _MAX_ROTATIONS + "not a pass/fail signal for the bug itself)")
		return false
	if not emergence_draw_confirmed:
		print("  [FAIL] boss played dusk_seer but its emergence_draw effect never resolved — " +
			"board-diff bookkeeping is reading/writing the wrong player index")
		return false
	print("  [PASS] boss's own emergence_draw effect resolved against its own hand/board")
	return true
