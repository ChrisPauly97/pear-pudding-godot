class_name BasicAI
extends RefCounted

const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const Keywords = preload("res://game_logic/battle/Keywords.gd")
const BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")

## AI personas (GID-112). Assigned per enemy type via
## `EnemyRegistry.get_ai_persona()` and threaded in by BattleScene.
const PERSONA_BASIC := "basic"
const PERSONA_AGGRO := "aggro"
const PERSONA_CONTROL := "control"

## Returns a list of actions the AI wants to take (as Callables to execute on game state).
## Decisions are deferred to execution time so plays and attacks use current state,
## preventing double-discard corruption and stale-plan silent failures.
##
## `persona` selects the decision heuristic once the shared lethal check (see
## `_has_lethal`) finds no lethal line available:
##   - "basic"   — cheapest-card-first play order (raw hand order), attacks the
##                 first available target (board-slot order). Reproduces the
##                 original single-strategy AI exactly; tutorial-tier default.
##   - "aggro"   — play order favors highest-attack affordable card; always
##                 attacks the hero directly over trading with a minion, unless
##                 a Ward minion forces the engagement.
##   - "control" — play order favors board development (minions before spells,
##                 "holding" removal/spell-like cards); only trades with a
##                 minion when the trade is favorable (kills the target and
##                 either survives or removes a bigger threat), otherwise
##                 attacks the hero.
## Any persona takes a lethal sequence over its normal heuristic when one is
## available this turn (see `_has_lethal`).
static func decide_turn(state: GameState, persona: String = PERSONA_BASIC) -> Array[Callable]:
	var actions: Array[Callable] = []
	var ai := state.current_player()

	# One Callable per hand slot — each re-checks can_play at execution time so
	# earlier plays that spent mana don't silently try to over-spend.
	var hand_snapshot := _ordered_hand(ai, persona)
	for card in hand_snapshot:
		var c := card as CardInstance
		actions.append(func():
			if c in ai.hand and ai.can_play(c):
				if ai.play_card(c):
					# Mirrors BattleScene._do_play_card()/_do_play_card_at_slot(),
					# which emit card_played for the human player's own plays
					# (BID-006) — the AI opponent's plays need the same signal.
					if c.card_class == "spell":
						GameBus.card_played.emit(c.template_id, "spell", -1)
					else:
						GameBus.card_played.emit(c.template_id, "board", ai.board.slots.find(c))
		)

	# One Callable per board slot — targets are resolved at execution time so a
	# minion killed by a previous attack isn't targeted again (double-discard fix).
	# This also re-evaluates the lethal check per-attacker, in case an earlier
	# attack in this same turn changed the board (e.g. killed a blocking Ward
	# minion), consistent with the deferred-Callable philosophy above.
	for my_card in ai.board.get_cards():
		var mc := my_card as CardInstance
		actions.append(func():
			if not mc.can_attack():
				return
			var target: CardInstance = _pick_attack_target(mc, state, persona)
			if target == null:
				# Attack hero — take retaliation (passive_atk symmetry fix)
				state.opponent().hero.take_damage(BattlefieldRules.modify_damage(mc.attack, state.battlefield_biome))
				mc.take_damage(BattlefieldRules.modify_damage(state.opponent().hero.attack, state.battlefield_biome))
				mc.attack_count -= 1
				# Mirrors BattleScene._execute_attack()/_resolve_remote_attack(),
				# which emit card_attacked for player-initiated attacks (BID-006) —
				# the AI opponent's attacks need the same signal.
				GameBus.card_attacked.emit(mc.template_id, "hero")
				if not mc.is_alive():
					ai.board.remove_card(mc)
					ai.discard.append(mc)
			else:
				var tgt := target
				tgt.take_damage(BattlefieldRules.modify_damage(mc.attack, state.battlefield_biome))
				mc.take_damage(BattlefieldRules.modify_damage(tgt.attack, state.battlefield_biome))
				mc.attack_count -= 1
				GameBus.card_attacked.emit(mc.template_id, tgt.template_id)
				if not tgt.is_alive():
					state.opponent().board.remove_card(tgt)
					state.opponent().discard.append(tgt)
				if not mc.is_alive():
					tgt.battle_kills += 1  # player card killed ai card via counterattack
					ai.board.remove_card(mc)
					ai.discard.append(mc)
		)

	return actions

## Returns a human-readable description of the AI's first planned action.
## `difficulty_tier` gates specificity (GID-112 / TID-418): tier 1 keeps the
## exact card/target wording (tutorial teaching value); tier >= 2 shows a
## vaguer, persona-flavored line that never names the exact card or target,
## so higher-tier fights regain some tension now that personas make the AI's
## choices meaningful. The described action always mirrors what `decide_turn`
## would actually do first for the same state/persona — the banner never lies,
## it is just less specific at higher tiers.
static func describe_turn(state: GameState, persona: String = PERSONA_BASIC, difficulty_tier: int = 1) -> String:
	var ai := state.current_player()

	# Check if any card can be played
	var hand_order := _ordered_hand(ai, persona)
	for card in hand_order:
		var c := card as CardInstance
		if ai.can_play(c):
			if difficulty_tier <= 1:
				return "Enemy will play " + c.name
			return _vague_action_text(persona)

	# Check if any minion can attack
	for my_card in ai.board.get_cards():
		var mc := my_card as CardInstance
		if not mc.can_attack():
			continue
		var target: CardInstance = _pick_attack_target(mc, state, persona)
		if difficulty_tier <= 1:
			if target == null:
				return "Enemy will attack your hero with " + mc.name
			return "Enemy attacks " + target.name + " with " + mc.name
		return _vague_action_text(persona)

	return "Enemy is thinking..."

# ---------------------------------------------------------------------------
# Shared lethal check
# ---------------------------------------------------------------------------

## True if the AI's currently-attackable board minions can drop the opponent's
## hero to <= 0 HP this turn by all attacking the hero directly. Returns false
## whenever an opponent Ward minion is alive (the hero is unreachable — Ward
## targeting is mandatory, see Keywords Game Logic in docs/agent/battle-system.md),
## since no persona can bypass that rule.
## Newly played cards never attack the turn they're played in this engine
## (decide_turn snapshots `ai.board.get_cards()` before any play executes), so
## only cards already on the board before this turn's actions run contribute.
static func _has_lethal(state: GameState) -> bool:
	var opp := state.opponent()
	if _opponent_has_ward(opp):
		return false
	var total: int = 0
	for c in state.current_player().board.get_cards():
		var mc := c as CardInstance
		if mc.can_attack():
			total += BattlefieldRules.modify_damage(mc.attack, state.battlefield_biome)
	var needed: int = opp.hero.get_status_value("armor") + opp.hero.health
	return total > 0 and total >= needed

static func _opponent_has_ward(opp: PlayerState) -> bool:
	for t in opp.board.get_cards():
		var tc := t as CardInstance
		if tc.keywords.has(Keywords.WARD):
			return true
	return false

# ---------------------------------------------------------------------------
# Attack target selection
# ---------------------------------------------------------------------------

## Returns the CardInstance `mc` should attack, or null to attack the hero
## directly. Shared by decide_turn (execution time, inside a deferred
## Callable) and describe_turn (banner text) so the two can never disagree.
static func _pick_attack_target(mc: CardInstance, state: GameState, persona: String) -> CardInstance:
	var opp := state.opponent()
	var all_targets := opp.board.get_cards()
	var ward_targets: Array[CardInstance] = []
	for t: CardInstance in all_targets:
		if t.keywords.has(Keywords.WARD):
			ward_targets.append(t)

	if not ward_targets.is_empty():
		# Ward is mandatory regardless of persona or lethal availability — the
		# hero and non-Ward minions simply aren't legal targets right now.
		if persona == PERSONA_CONTROL:
			var fav: CardInstance = _pick_favorable_trade(mc, state, ward_targets)
			if fav != null:
				return fav
		return ward_targets[0]

	if _has_lethal(state):
		return null  # go for the kill

	match persona:
		PERSONA_AGGRO:
			# Races the player's hero — ignores favorable trades entirely.
			return null
		PERSONA_CONTROL:
			# Only trades when favorable; otherwise pressures the hero.
			return _pick_favorable_trade(mc, state, all_targets)
		_:
			# "basic" (and any unrecognised persona) — original behavior:
			# attack the first target in board-slot order, or the hero if the
			# opponent's board is empty.
			return all_targets[0] if not all_targets.is_empty() else null

## Returns the first target in `targets` that `mc` can favorably trade with:
## the attack kills the target, and either `mc` survives the counterattack or
## the target hits harder than `mc` does (worth trading down for a bigger
## threat even at a loss). Returns null if no favorable trade exists.
static func _pick_favorable_trade(mc: CardInstance, state: GameState, targets: Array[CardInstance]) -> CardInstance:
	var biome: int = state.battlefield_biome
	var dmg_out: int = BattlefieldRules.modify_damage(mc.attack, biome)
	for t: CardInstance in targets:
		if dmg_out < t.health:
			continue  # doesn't kill the target — not a trade at all
		var dmg_in: int = BattlefieldRules.modify_damage(t.attack, biome)
		var survives: bool = dmg_in < mc.health
		var worth_trading_down: bool = t.attack > mc.attack
		if survives or worth_trading_down:
			return t
	return null

# ---------------------------------------------------------------------------
# Hand play ordering
# ---------------------------------------------------------------------------

## Returns a persona-ordered copy of `ai.hand`. Ordering only affects which
## subset of cards actually gets played when mana is limited (each play
## Callable re-checks can_play/mana at execution time) — later entries may
## simply not be affordable once earlier ones spend mana, which is how
## "control" holds spells back without any extra gating logic.
static func _ordered_hand(ai: PlayerState, persona: String) -> Array[CardInstance]:
	var hand: Array[CardInstance] = ai.hand.duplicate()
	match persona:
		PERSONA_AGGRO:
			# Highest-attack affordable card first — races to field more face
			# damage rather than optimizing mana efficiency.
			hand.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
				if a.attack != b.attack:
					return a.attack > b.attack
				return a.cost < b.cost
			)
		PERSONA_CONTROL:
			# Board development first (minions), spells/removal held for last —
			# on a tight mana turn this means the held card simply doesn't get
			# played, which is the "hold for the biggest threat" behavior.
			hand.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
				var a_minion: bool = a.card_class != "spell"
				var b_minion: bool = b.card_class != "spell"
				if a_minion != b_minion:
					return a_minion
				return a.cost < b.cost
			)
		_:
			pass  # "basic" — preserve raw hand order (matches pre-goal behavior)
	return hand

static func _vague_action_text(persona: String) -> String:
	match persona:
		PERSONA_AGGRO:
			return "The enemy is pressing the attack..."
		PERSONA_CONTROL:
			return "The enemy is calculating its next move..."
		_:
			return "The enemy is sizing up the battlefield..."
