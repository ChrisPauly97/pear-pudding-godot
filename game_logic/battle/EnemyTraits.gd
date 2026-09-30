## EnemyTraits — named fight rules an enemy type carries (GID-149 / TID-621),
## listed per type as `traits` in EnemyRegistry. Pure logic over a GameState:
## BattleModifiers calls `on_enemy_round` at the start of every enemy turn
## (turn-based) or enemy round (real time), and `mirror_deck` before the enemy
## deck is built.
##
##   howl   — on enemy round HOWL_ROUND the Alpha calls one more pack wolf.
##   brood  — while the enemy hero lives, each round refills one scarab up to BROOD_CAP.
##   frenzy — from round FRENZY_FROM on, every enemy minion gains +1 attack a round.
##   mirror — the enemy's spells are replaced by the player's own.
extends RefCounted

const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")

const HOWL_ROUND: int = 3
const HOWL_CARD: String = "wolf"
const BROOD_CARD: String = "scarab"
const BROOD_CAP: int = 5
const FRENZY_FROM: int = 7

## A ready-to-act enemy unit of `cid`, stats scaled to `tier` (as the enemy deck is).
static func make_unit(cid: String, tier: int, attack_bonus: int = 0) -> CardInstance:
	var tmpl: Dictionary = CardRegistry.get_template(cid)
	if tmpl.is_empty():
		return null
	tmpl = tmpl.duplicate()
	var scaled: Dictionary = CardDropUtil.enemy_card_stats(cid, tier)
	tmpl["attack"] = scaled.get("attack", tmpl.get("attack", 0))
	tmpl["health"] = scaled.get("health", tmpl.get("health", 0))
	var unit := CardInstance.new(tmpl)
	unit.attack += attack_bonus
	unit.summoning_sick = false
	return unit

## Puts `unit` in `p`'s first free board slot. False when the board is full.
static func place(p: PlayerState, unit: CardInstance) -> bool:
	if unit == null:
		return false
	for i: int in range(p.board.slots.size()):
		if p.board.slots[i] == null:
			p.board.slots[i] = unit
			return true
	return false

## Applies `traits` for enemy round `round_n` (1-based). Returns toast lines.
static func on_enemy_round(state: GameState, enemy_idx: int, traits: Array[String], round_n: int,
		tier: int) -> Array[String]:
	var out: Array[String] = []
	var p: PlayerState = state.players[enemy_idx]
	if p.hero.health <= 0:
		return out
	if traits.has("howl") and round_n == HOWL_ROUND \
			and place(p, make_unit(HOWL_CARD, tier, p.minion_attack_bonus)):
		out.append("The Alpha howls — another wolf joins the pack!")
	if traits.has("brood") and _count(p, BROOD_CARD) < BROOD_CAP \
			and place(p, make_unit(BROOD_CARD, tier, p.minion_attack_bonus)) and round_n == 2:
		out.append("The Queen lays — scarabs keep coming while she lives!")
	if traits.has("frenzy") and round_n >= FRENZY_FROM:
		for c: CardInstance in p.board.get_cards():
			c.attack += 1
		if round_n == FRENZY_FROM:
			out.append("The Wendigo frenzies — end this fast!")
	return out

## `enemy_deck` with each spell swapped for one of `player_spells` in turn.
## Unchanged when the player carries no spells.
static func mirror_deck(enemy_deck: Array[String], player_spells: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var i: int = 0
	for cid: String in enemy_deck:
		var tmpl: Dictionary = CardRegistry.get_template(cid)
		if not player_spells.is_empty() and str(tmpl.get("card_class", "")) == "spell":
			out.append(player_spells[i % player_spells.size()])
			i += 1
		else:
			out.append(cid)
	return out

static func _count(p: PlayerState, cid: String) -> int:
	var n: int = 0
	for c: CardInstance in p.board.get_cards():
		if c.template_id == cid:
			n += 1
	return n
