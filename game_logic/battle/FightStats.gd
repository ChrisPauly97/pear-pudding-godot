## Per-fight real-time combat stats + the pure tip rule that reads them
## (GID-135 / TID-559).
##
## `BattleRealtime.gd` creates one per fight and feeds it from
## `RealtimeCombat.advance()` events (via `record_frame`), `BattleSkillBar`
## skill presses (real `Kick` interrupts included) and a couple of GameBus
## signals (`card_played`, `potion_used`). Nothing here touches a Node, a
## scene or an autoload; `record_frame` reads a live `RealtimeCombat` (not
## unit-tested directly) but every `record_*` and `pick_tip` are pure and
## tested on plain values.
extends RefCounted

const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")

var duration: float = 0.0
## Player skill uses this fight: deck cards (spells + Allies) + skill-bar presses.
var skill_uses: int = 0
## Enemy telegraphs ("cast bar") that finished uninterrupted.
var enemy_casts_completed: int = 0
## Successful `Kick`-style interrupts landed (SkillBar "interrupt" effect).
var interrupts_landed: int = 0
## Seconds spent at max mana (nothing left to spend it on) / at zero mana.
var time_at_full_mana: float = 0.0
var time_at_empty_mana: float = 0.0
## Damage dealt by the hero's own weapon swings + Ally auto-attacks vs. by
## actively-cast damage (Strike, spells) — the split the tip rule cares about
## is "auto vs. everything you actively cast", not unit-vs-hero.
var autoattack_damage: int = 0
var card_damage: int = 0
## Times a potion/food was used while hero HP was at or below 30% of max.
var potions_used_low_hp: int = 0
## Lowest hero HP fraction (0..1) seen this fight; 1.0 if never damaged.
var lowest_hp_fraction: float = 1.0

func record_tick(delta: float, mana: int, max_mana: int) -> void:
	duration += delta
	if max_mana > 0 and mana >= max_mana:
		time_at_full_mana += delta
	elif mana <= 0:
		time_at_empty_mana += delta

func record_hp_fraction(fraction: float) -> void:
	lowest_hp_fraction = minf(lowest_hp_fraction, clampf(fraction, 0.0, 1.0))

func record_skill_use() -> void:
	skill_uses += 1

func record_enemy_cast_completed() -> void:
	enemy_casts_completed += 1

func record_interrupt() -> void:
	interrupts_landed += 1

func record_autoattack_damage(amount: int) -> void:
	autoattack_damage += maxi(0, amount)

func record_card_damage(amount: int) -> void:
	card_damage += maxi(0, amount)

func record_potion_used(hp_fraction: float) -> void:
	if hp_fraction <= 0.3:
		potions_used_low_hp += 1

## Feeds this fight's stats from one real-time tick (GID-135 / TID-559):
## pulls the hero's mana/HP off `rt` and folds in `events` from
## `RealtimeCombat.advance()`. Called from `BattleRealtime._process`.
func record_frame(dt: float, rt: RealtimeCombat, events: Array[Dictionary]) -> void:
	var hero := rt.state.players[RealtimeCombat.PLAYER].hero
	record_tick(dt, hero.mana, hero.max_mana)
	if hero.max_health > 0:
		record_hp_fraction(float(hero.health) / float(hero.max_health))
	for ev: Dictionary in events:
		match str(ev.get("type", "")):
			"enemy_cast":
				record_enemy_cast_completed()
			"swing":
				if int(ev.get("side", -1)) == RealtimeCombat.PLAYER:
					record_autoattack_damage(_swing_damage(ev, rt))

## Total health on every enemy side (heroes + board units). A cast's damage is
## the drop in this across its resolution (`BattleRealtime._tick_cast`).
static func enemy_health(rt: RealtimeCombat) -> int:
	var total: int = 0
	for side: int in rt.enemy_sides():
		var p := rt.state.players[side]
		total += maxi(0, p.hero.health)
		for c: CardInstance in p.board.get_cards():
			total += maxi(0, c.health)
	return total

## Best-effort damage estimate for a player-side swing event (pre-armor/biome
## modifiers, which `RealtimeCombat` applies internally and doesn't report) —
## good enough for the coaching-tip heuristic, not for exact combat logs.
func _swing_damage(ev: Dictionary, rt: RealtimeCombat) -> int:
	var attacker: Variant = ev.get("attacker")
	if attacker is CardInstance:
		return (attacker as CardInstance).attack
	if str(ev.get("hand", "main")) == "off":
		return rt.offhand_damage[RealtimeCombat.PLAYER]
	return rt.main_hand_damage(RealtimeCombat.PLAYER)

## Plain-dict snapshot `pick_tip` (and tests) read — keeps the rule pure.
func to_dict() -> Dictionary:
	return {
		"duration": duration,
		"skill_uses": skill_uses,
		"enemy_casts_completed": enemy_casts_completed,
		"interrupts_landed": interrupts_landed,
		"time_at_full_mana": time_at_full_mana,
		"time_at_empty_mana": time_at_empty_mana,
		"autoattack_damage": autoattack_damage,
		"card_damage": card_damage,
		"potions_used_low_hp": potions_used_low_hp,
		"lowest_hp_fraction": lowest_hp_fraction,
	}

## The single most useful post-fight line, or "" if nothing stood out. Checked
## in priority order — first match wins, so ordering here IS the design.
static func pick_tip(data: Dictionary) -> String:
	var enemy_casts: int = int(data.get("enemy_casts_completed", 0))
	var interrupts: int = int(data.get("interrupts_landed", 0))
	if enemy_casts >= 2 and interrupts == 0:
		return "Enemies finished %d casts uncontested — try Kick while their cast bar fills." % enemy_casts
	var full_mana_s: float = float(data.get("time_at_full_mana", 0.0))
	if full_mana_s >= 30.0:
		return "You sat at full mana for %ds — spend it, it stops helping once it caps." % int(full_mana_s)
	var lowest_hp: float = float(data.get("lowest_hp_fraction", 1.0))
	if lowest_hp <= 0.25 and int(data.get("potions_used_low_hp", 0)) == 0:
		return "You dropped to %d%% health without healing — Mend or a potion buys room to fight." % (
				int(lowest_hp * 100.0))
	var duration: float = float(data.get("duration", 0.0))
	var skill_uses: int = int(data.get("skill_uses", 0))
	if duration >= 20.0 and skill_uses <= 2:
		return "You mostly auto-attacked — Strike and your hand have more damage between swings."
	var auto_dmg: int = int(data.get("autoattack_damage", 0))
	var card_dmg: int = int(data.get("card_damage", 0))
	if auto_dmg > 0 and card_dmg > auto_dmg * 3:
		return "Your weapon barely landed a hit — its auto-attack is free damage, don't ignore it."
	return ""
