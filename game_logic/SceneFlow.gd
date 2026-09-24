## SceneManager's state machine: the states, which transitions between them are
## legal, and which states count as a world-hosted overlay. Pure data plus
## static predicates, with no Node dependencies, so the tests can check the
## table without a SceneTree.
##
## SceneManager aliases `State` (`SceneManager.State.WORLD` keeps working) and
## sends every state change through `SceneManager._transition_to()`, which
## checks it against `TRANSITIONS`.
extends RefCounted

enum State {
	MENU,
	WORLD,
	BATTLE,
	SHOP,
	GAME_OVER,
	ACHIEVEMENTS,
	RUN_SUMMARY,
	PACK_OPEN,
	BOUNTY_BOARD,
	MAILBOX,
	BLACKSMITH,
	MENU_HUB,
}

## Overlays hosted on top of the live WorldScene. The world keeps running
## underneath them, and closing one always returns to WORLD.
const WORLD_OVERLAYS: Array[State] = [
	State.SHOP,
	State.PACK_OPEN,
	State.BOUNTY_BOARD,
	State.MAILBOX,
	State.BLACKSMITH,
	State.MENU_HUB,
]

## from → the states it may move to. Leaving for MENU is always legal (every
## exit path ends in go_to_menu / go_to_menu_direct / slot select), so it is
## added by `can_transition` and not repeated in each row. WORLD → WORLD is a
## map change (enter_map / exit_map reload the WorldScene).
const TRANSITIONS: Dictionary = {
	State.MENU: [State.WORLD, State.ACHIEVEMENTS],
	State.ACHIEVEMENTS: [],
	State.WORLD: [
		State.WORLD, State.BATTLE, State.RUN_SUMMARY,
		State.SHOP, State.BOUNTY_BOARD, State.MAILBOX, State.BLACKSMITH, State.MENU_HUB,
	],
	# BATTLE → BATTLE: a puzzle or scripted battle requested while one is still
	# tearing down re-enters without passing through WORLD.
	State.BATTLE: [State.WORLD, State.BATTLE, State.GAME_OVER, State.RUN_SUMMARY],
	# The defeat card's Retry re-enters the world and immediately re-battles.
	State.GAME_OVER: [State.WORLD],
	State.RUN_SUMMARY: [State.WORLD],
	State.SHOP: [State.WORLD, State.PACK_OPEN],
	State.PACK_OPEN: [State.WORLD],
	State.BOUNTY_BOARD: [State.WORLD],
	State.MAILBOX: [State.WORLD],
	State.BLACKSMITH: [State.WORLD],
	State.MENU_HUB: [State.WORLD],
}


static func can_transition(from: State, to: State) -> bool:
	if to == State.MENU:
		return true
	var allowed: Array = TRANSITIONS.get(from, [])
	return allowed.has(to)


static func is_world_overlay(state: State) -> bool:
	return WORLD_OVERLAYS.has(state)


## True while a WorldScene is (or is about to be) the live scene, meaning WORLD
## or an overlay on top of it. A battle detaches the world, so it doesn't count.
static func is_world_hosted(state: State) -> bool:
	return state == State.WORLD or is_world_overlay(state)


static func state_name(state: State) -> String:
	return State.keys()[state]
