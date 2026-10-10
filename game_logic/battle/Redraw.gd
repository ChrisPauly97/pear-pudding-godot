## The Redraw unlock (GID-185 / TID-776): one mulligan per real-time fight, in the
## first `redraw_window` seconds (CombatTuning). Pure; state lives on RealtimeCombat
## (`redraw_ready`, `fight_time`), set by `BattleSetup.apply_deck_rules`.
extends RefCounted

const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")

## True while the player may still Redraw (learned, unused, inside the window).
static func can_redraw(rt: RealtimeCombat) -> bool:
	return (rt.redraw_ready and rt.fight_time < rt.tune.get_f("redraw_window")
		and not rt.state.is_game_over())

## Every non-technique card in the player's hand goes back into the draw pile, which
## is shuffled, and as many cards are drawn. Once per fight. Returns how many cards
## were swapped (0 = refused or nothing to swap).
static func redraw(rt: RealtimeCombat) -> int:
	if not can_redraw(rt):
		return 0
	rt.redraw_ready = false
	var p: PlayerState = rt.state.players[RealtimeCombat.PLAYER]
	var kept: Array[CardInstance] = []
	var n: int = 0
	for c: CardInstance in p.hand:
		if TechniqueDefs.is_technique(c.template_id):
			kept.append(c)
		else:
			p.draw_deck.append(c)
			n += 1
	p.hand.assign(kept)
	p.draw_deck.shuffle()
	for _i: int in n:
		p.draw_card(false)
	return n
