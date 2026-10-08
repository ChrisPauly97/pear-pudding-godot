## GID-176 / TID-712: a seeded real-time fight replays exactly — the base the
## balance simulator (tools/balance_sim.gd) relies on.
extends "res://tests/framework/test_case.gd"

const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const SpellEffectResolver = preload("res://scenes/battle/SpellEffectResolver.gd")

const DT: float = 0.05
const TICKS: int = 1200  # 60 s of fight
var _deck: Array[String] = ["ghost", "skeleton", "zombie", "ghoul", "spark", "mend",
	"ghost", "skeleton", "zombie", "ghoul", "spark", "mend"]

## Runs one fight from `s` and returns a trace of everything observable per tick.
func _trace(s: int) -> Array[String]:
	seed(s)
	var gs := GameState.new()
	for p: PlayerState in gs.players:
		p.build_deck(_deck, 1)
		p.draw_opening_hand(4)
	var rt := RealtimeCombat.new(gs, [5, 5])
	rt.rng.seed = s
	rt.tune.set_value("proc_chance", 0.5)  # make the rng matter
	var out: Array[String] = []
	for _i: int in TICKS:
		var types: PackedStringArray = []
		for ev: Dictionary in rt.advance(DT):
			types.append(str(ev.get("type", "")))
		var line: String = ",".join(types)
		for p: PlayerState in gs.players:
			line += "|%d/%d/%d/%d/%d" % [p.hero.health, p.hero.mana, p.hand.size(), p.board.get_cards().size(),
				p.draw_deck.size()]
		for c: Variant in gs.players[0].hand:
			line += ":" + str((c as Object).get("template_id"))
		line += "#%d/%s" % [rt.combo, str(gs.players[0].next_card_free)]
		out.append(line)
		if rt.on_player_hit(1, true):
			out.append("proc")
		if gs.is_game_over():
			break
	return out

func test_same_seed_same_fight() -> void:
	SpellEffectResolver.silent = true
	var a: Array[String] = _trace(42)
	var b: Array[String] = _trace(42)
	assert_eq(a.size(), b.size(), "same fight length")
	assert_eq(_first_diff(a, b), -1, "traces identical (first differing tick)")
	SpellEffectResolver.silent = false

func test_different_seed_diverges() -> void:
	assert_ne(_first_diff(_trace(1), _trace(2)), -1)

## Index of the first differing line, or -1 when identical.
func _first_diff(a: Array[String], b: Array[String]) -> int:
	for i: int in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return i
	return -1 if a.size() == b.size() else mini(a.size(), b.size())
