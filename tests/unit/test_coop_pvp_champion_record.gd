## Unit tests for CoopPvP._apply_champion_result (BID-025) — the win/loss/streak
## bookkeeping `_on_pvp_battle_ended_coop` applies to a duel's champion record.
##
## Calling it directly on a plain (never-added-to-tree) CoopPvP node is safe: the
## helper only touches its `st`/`token`/`won` arguments, never `_world` — it was
## deliberately factored out of `_on_pvp_battle_ended_coop` so both combatants'
## records could be updated (and unit-tested) the same way, instead of the update
## being inlined once for the host's own token only.
extends "res://tests/framework/test_case.gd"

const CoopPvP = preload("res://scenes/world/coop/CoopPvP.gd")
const SessionState = preload("res://game_logic/net/SessionState.gd")


func _mod() -> Node:
	return CoopPvP.new()


func test_apply_champion_result_win_increments_wins_and_streak() -> void:
	var st := SessionState.new()
	st.ensure_member("tok", "Ada")
	var m := _mod()
	m._apply_champion_result(st, "tok", true)
	m.free()
	var rec: Dictionary = st.get_member("tok")
	assert_eq(int(rec.get("pvp_wins", -1)), 1)
	assert_eq(int(rec.get("pvp_losses", -1)), 0)
	assert_eq(int(rec.get("pvp_streak", -1)), 1)
	assert_eq(int(rec.get("pvp_best_streak", -1)), 1)


func test_apply_champion_result_loss_increments_losses_and_resets_streak() -> void:
	var st := SessionState.new()
	st.ensure_member("tok", "Ada")
	var rec0: Dictionary = st.get_member("tok")
	rec0["pvp_streak"] = 3
	rec0["pvp_best_streak"] = 3
	st.update_member("tok", rec0)
	var m := _mod()
	m._apply_champion_result(st, "tok", false)
	m.free()
	var rec: Dictionary = st.get_member("tok")
	assert_eq(int(rec.get("pvp_losses", -1)), 1)
	assert_eq(int(rec.get("pvp_streak", -1)), 0)
	assert_eq(int(rec.get("pvp_best_streak", -1)), 3,
		"best streak is a high-water mark — a loss must not lower it")


func test_apply_champion_result_streak_updates_best_streak_high_water_mark() -> void:
	var st := SessionState.new()
	st.ensure_member("tok", "Ada")
	var m := _mod()
	m._apply_champion_result(st, "tok", true)
	m._apply_champion_result(st, "tok", true)
	m._apply_champion_result(st, "tok", false)
	m._apply_champion_result(st, "tok", true)
	m.free()
	var rec: Dictionary = st.get_member("tok")
	assert_eq(int(rec.get("pvp_wins", -1)), 3)
	assert_eq(int(rec.get("pvp_losses", -1)), 1)
	assert_eq(int(rec.get("pvp_streak", -1)), 1, "streak reset by the loss, then rebuilt by the next win")
	assert_eq(int(rec.get("pvp_best_streak", -1)), 2, "best streak keeps the pre-loss high of 2")


func test_apply_champion_result_unknown_token_is_a_no_op() -> void:
	var st := SessionState.new()
	var m := _mod()
	m._apply_champion_result(st, "nope", true)
	m.free()
	assert_false(st.has_member("nope"), "must not create a member record as a side effect")


## BID-025's core regression guard: a single duel result applied to both
## combatants must leave BOTH champion records coherent, not just the winner's
## (or, pre-fix, only whichever token happened to be the host's own).
func test_duel_updates_both_combatants_symmetrically() -> void:
	var st := SessionState.new()
	st.ensure_member("winner_tok", "Winner")
	st.ensure_member("loser_tok", "Loser")
	var m := _mod()
	var host_won := true
	m._apply_champion_result(st, "winner_tok", host_won)
	m._apply_champion_result(st, "loser_tok", not host_won)
	m.free()
	var winner_rec: Dictionary = st.get_member("winner_tok")
	var loser_rec: Dictionary = st.get_member("loser_tok")
	assert_eq(int(winner_rec.get("pvp_wins", -1)), 1)
	assert_eq(int(winner_rec.get("pvp_losses", -1)), 0)
	assert_eq(int(winner_rec.get("pvp_streak", -1)), 1)
	assert_eq(int(loser_rec.get("pvp_wins", -1)), 0)
	assert_eq(int(loser_rec.get("pvp_losses", -1)), 1)
	assert_eq(int(loser_rec.get("pvp_streak", -1)), 0)


## Same symmetric update, but from the client's (loser-this-time) perspective —
## proves the helper doesn't secretly favor whichever token is passed first.
func test_duel_updates_both_combatants_symmetrically_reversed_outcome() -> void:
	var st := SessionState.new()
	st.ensure_member("host_tok", "Host")
	st.ensure_member("client_tok", "Client")
	var m := _mod()
	var host_won := false
	m._apply_champion_result(st, "host_tok", host_won)
	m._apply_champion_result(st, "client_tok", not host_won)
	m.free()
	var host_rec: Dictionary = st.get_member("host_tok")
	var client_rec: Dictionary = st.get_member("client_tok")
	assert_eq(int(host_rec.get("pvp_losses", -1)), 1)
	assert_eq(int(client_rec.get("pvp_wins", -1)), 1)
