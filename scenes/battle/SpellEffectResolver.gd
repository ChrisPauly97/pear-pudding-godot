extends RefCounted

const BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")
const GameState = preload("res://game_logic/battle/GameState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CaptureTracker = preload("res://game_logic/battle/CaptureTracker.gd")
const Keywords = preload("res://game_logic/battle/Keywords.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")

# Co-located with resolver so match arms and targeting UI stay in sync.
const ENEMY_TARGETED_EFFECTS: Array[String] = [
	"deal_damage_single", "curse_minion", "lifesteal_hit",
	"apply_poison_single", "freeze_single", "bind_minion", "stun_single",
]
const FRIENDLY_TARGETED_EFFECTS: Array[String] = [
	"heal_single", "shield_minion", "buff_attack",
	"grant_surge", "grant_ward", "grant_shroud", "double_attack",
]
const SLOT_TARGETED_EFFECTS: Array[String] = ["bless_slot", "ward_slot"]
# Effects that target an ally's board/hero in co-op PvE. The target dict carries
# {"pidx": <ally_player_idx>} set by BattleScene during ally selection.
const ALLY_TARGETED_EFFECTS: Array[String] = [
	"ally_heal_hero", "ally_grant_ward_board", "ally_buff_minion_all",
	"ally_grant_mana", "ally_revive",
]

var extra_turn_granted: bool = false
var capture_tracker: CaptureTracker

var _state: GameState

func setup(state: GameState) -> void:
	_state = state

## Finds the actual owner of `card` by board membership (GID-102 / TID-371). Used
## when removing an explicitly-targeted minion that died: in a team battle, the
## targeted card may belong to either enemy-team member, not just the auto-picked
## `opponent`. Falls back to `fallback` if the card isn't found on any board (should
## not happen for a live explicit target, but keeps this total).
func _find_card_owner(card: CardInstance, fallback: PlayerState) -> PlayerState:
	for p: PlayerState in _state.players:
		if p.board.slots.has(card):
			return p
	return fallback

## The minion the caster picked, or `owner`'s leading minion when a single-target
## spell resolves without a pick (AI casts, auto-spells). Null if the board is empty.
func _pick(explicit_target: Dictionary, owner: PlayerState) -> CardInstance:
	var t: CardInstance = explicit_target.get("card", null) as CardInstance
	if t != null:
		return t
	var cards := owner.board.get_cards()
	return cards[0] if not cards.is_empty() else null

## Moves `card` to its real owner's discard once it has died.
func _bury_if_dead(card: CardInstance, fallback: PlayerState) -> void:
	if card.is_alive():
		return
	var owner := _find_card_owner(card, fallback)
	owner.board.remove_card(card)
	owner.discard.append(card)

## Clears every dead minion off `player`'s board into their discard.
func _sweep_dead(player: PlayerState) -> void:
	for t in player.board.get_cards().duplicate():
		if not t.is_alive():
			player.board.remove_card(t)
			player.discard.append(t)

## Ally targeted by a co-op support card; falls back to the caster when the
## "pidx" hint is absent (solo / 2-player context). The last player slot is the
## shared PvE boss, so it is never a valid ally.
func _ally(explicit_target: Dictionary, caster_pid: int) -> PlayerState:
	var pidx: int = clampi(int(explicit_target.get("pidx", caster_pid)), 0, _state.players.size() - 2)
	return _state.players[pidx]

## Revives the newest minion in `player`'s discard onto their board.
func _revive_last_minion(player: PlayerState) -> void:
	for i in range(player.discard.size() - 1, -1, -1):
		var t := player.discard[i] as CardInstance
		if t.card_class == "minion" and not player.board.is_full():
			t.health = t.max_health
			t.summoning_sick = true
			player.board.add_card(t)
			player.discard.remove_at(i)
			return

## Appends `kw` to `card`'s keywords if it isn't already there.
static func _grant(card: CardInstance, kw: String) -> void:
	if not card.keywords.has(kw):
		card.keywords.append(kw)

## Fires when a minion with an emergence_effect is placed on the board.
func resolve_emergence(card: CardInstance, caster_pid: int) -> void:
	if card.emergence_effect == "":
		return
	AudioManager.play_sfx("spell_resolve")
	# Mirrors resolve_spell's generalization: caster_pid is always current_player_idx
	# at the time a just-played minion's emergence fires, so opponent() is correct.
	var opponent: PlayerState = _state.opponent()
	var caster: PlayerState = _state.players[caster_pid]
	match card.emergence_effect:
		"emergence_deal_damage":
			opponent.hero.take_damage(BattlefieldRules.modify_damage(card.emergence_power, _state.battlefield_biome))
		"emergence_heal_hero":
			caster.hero.health = mini(caster.hero.max_health, caster.hero.health + card.emergence_power)
		"emergence_draw":
			for _i in range(card.emergence_power):
				caster.draw_card()
		"emergence_buff_friendly":
			var others: Array[CardInstance] = []
			for c: CardInstance in caster.board.get_cards():
				if c != card:
					others.append(c)
			if not others.is_empty():
				others[randi() % others.size()].attack += card.emergence_power
		"emergence_apply_poison":
			var enemies := opponent.board.get_cards()
			if not enemies.is_empty():
				enemies[randi() % enemies.size()].apply_status("poison", card.emergence_power)

## Resolves the effect of a spell card played by caster_pid against the opponent.
## explicit_target: optional dict with "type" ("minion"/"hero") and "card" (CardInstance).
func resolve_spell(card: CardInstance, caster_pid: int, explicit_target: Dictionary = {}) -> void:
	AudioManager.play_sfx("spell_resolve")
	var _ct_board_before: int = _state.players[1 - caster_pid].board.get_cards().size() if caster_pid == 0 else 0
	# resolve_spell is only ever called for the currently-acting player (turn-gated by every
	# caller), so _state.opponent() always reflects caster_pid's opponent — generalizes the
	# old "_state.players[1 - caster_pid]" to co-op-PvE (boss) and team battles (lowest-HP
	# enemy-team member) without changing 2-player behavior (opponent() == players[1-idx] there).
	var opponent: PlayerState = _state.opponent()
	var caster: PlayerState = _state.players[caster_pid]
	var power: int = card.spell_power
	var _spell_dmg: int = BattlefieldRules.modify_damage(power, _state.battlefield_biome)
	# Single-target arms resolve their subject once here; `null` means the
	# relevant board was empty, which every arm below treats as a no-op.
	var foe: CardInstance = _pick(explicit_target, opponent)
	var friend: CardInstance = _pick(explicit_target, caster)
	match card.spell_effect:
		"deal_damage_single":
			if explicit_target.get("card", null) == null and explicit_target.get("type", "") == "hero":
				var hero_owner: PlayerState = opponent
				if explicit_target.has("pidx"):
					hero_owner = _state.players[int(explicit_target["pidx"])]
				hero_owner.hero.take_damage(_spell_dmg)
			elif foe == null:
				opponent.hero.take_damage(_spell_dmg)
			else:
				foe.take_damage(_spell_dmg)
				_bury_if_dead(foe, opponent)
		"deal_damage_all", "deal_damage_all_full":
			for t in opponent.board.get_cards():
				t.take_damage(_spell_dmg)
			_sweep_dead(opponent)
			if card.spell_effect == "deal_damage_all_full":
				opponent.hero.take_damage(_spell_dmg)
		"deal_damage_random":
			var targets := opponent.board.get_cards()
			if targets.is_empty():
				opponent.hero.take_damage(_spell_dmg)
			else:
				var hit: CardInstance = targets[randi() % targets.size()]
				hit.take_damage(_spell_dmg)
				_bury_if_dead(hit, opponent)
		"debuff_attack":
			for t in opponent.board.get_cards():
				t.attack = maxi(0, t.attack - power)
		"destroy_low_hp":
			for t in opponent.board.get_cards().duplicate():
				if t.health <= power:
					opponent.board.remove_card(t)
					opponent.discard.append(t)
		"resurrect_last":
			_revive_last_minion(caster)
		"heal_single":
			if friend != null:
				friend.health = mini(friend.max_health, friend.health + power)
		"heal_all":
			for t in caster.board.get_cards():
				t.health = mini(t.max_health, t.health + power)
		"shield_minion":
			if friend != null:
				friend.apply_status("armor", friend.get_status_value("armor") + power)
		"buff_attack":
			if friend != null:
				friend.attack += power
		"lifesteal_hit":
			if foe != null:
				foe.take_damage(_spell_dmg)
				caster.hero.health = mini(caster.hero.max_health, caster.hero.health + _spell_dmg)
				_bury_if_dead(foe, opponent)
		"mana_drain":
			opponent.hero.mana = maxi(0, opponent.hero.mana - power)
		"curse_minion":
			if foe != null:
				foe.attack = maxi(0, foe.attack - power)
				foe.health -= _spell_dmg
				_bury_if_dead(foe, opponent)
		"draw_card":
			for _i in range(power):
				caster.draw_card()
		"bless_slot", "ward_slot":
			var slot: int = caster.board.first_empty_slot()
			if slot >= 0:
				if card.spell_effect == "bless_slot":
					caster.board.enhance_slot(slot, "atk_bonus", power)
				else:
					caster.board.enhance_slot(slot, "shroud", 1)
		"extra_turn":
			extra_turn_granted = true
		"destroy_all_draw_3":
			for p: PlayerState in [_state.players[0], _state.players[1]]:
				for t in p.board.get_cards().duplicate():
					p.board.remove_card(t)
					p.discard.append(t)
			for _i in range(3):
				caster.draw_card()
		# ── 20 new effects (TID-279) ──────────────────────────────────────
		"deal_damage_hero":
			opponent.hero.take_damage(_spell_dmg)
		"apply_poison_single":
			if foe != null:
				foe.apply_status("poison", power)
		"apply_poison_all":
			for t in opponent.board.get_cards():
				t.apply_status("poison", power)
		"grant_surge":
			if friend != null:
				_grant(friend, Keywords.SURGE)
				friend.summoning_sick = false
		"double_attack":
			if friend != null:
				friend.attack_count = 1
				friend.summoning_sick = false
		"buff_attack_all":
			for t in caster.board.get_cards():
				t.attack += power
		"heal_hero":
			caster.hero.heal(power)
		"armor_hero":
			caster.hero.apply_status("armor", power)
		"grant_ward":
			if friend != null:
				_grant(friend, Keywords.WARD)
		"grant_shroud":
			if friend != null:
				_grant(friend, Keywords.SHROUD)
				friend.shroud_active = true
		"grant_ward_all":
			for t in caster.board.get_cards():
				_grant(t, Keywords.WARD)
		"bind_minion":
			if foe != null:
				foe.keywords.clear()
				foe.shroud_active = false
		"buff_health_all":
			for t in caster.board.get_cards():
				t.health += power
				t.max_health += power
		"enemy_discard":
			opponent.hand.shuffle()
			for _i in range(mini(power, opponent.hand.size())):
				opponent.discard.append(opponent.hand.pop_back())
		"freeze_single":
			if foe != null:
				foe.apply_status("freeze", 1)
		"freeze_all":
			for t in opponent.board.get_cards():
				t.apply_status("freeze", 1)
		"drain_hero":
			opponent.hero.take_damage(_spell_dmg)
			caster.hero.heal(_spell_dmg)
		"stun_single":
			if foe != null:
				foe.apply_status("stun", power)
				foe.out_of_play = power
		"summon_token":
			var tmpl: Dictionary = CardRegistry.get_template("skeleton")
			if not tmpl.is_empty():
				for _i in range(power):
					if caster.board.is_full():
						break
					var token := CardInstance.new(tmpl)
					token.summoning_sick = true
					caster.board.add_card(token)
		# ── Co-op PvE support cards (GID-100) ────────────────────────────────
		"ally_heal_hero":
			_ally(explicit_target, caster_pid).hero.heal(power)
		"ally_grant_ward_board":
			for t in _ally(explicit_target, caster_pid).board.get_cards():
				_grant(t, Keywords.WARD)
		"ally_buff_minion_all":
			for t in _ally(explicit_target, caster_pid).board.get_cards():
				t.attack += power
				t.health += power
				t.max_health += power
		"ally_grant_mana":
			var ally_hero := _ally(explicit_target, caster_pid).hero
			ally_hero.mana = mini(ally_hero.mana + power, ally_hero.max_mana)
		"ally_revive":
			_revive_last_minion(_ally(explicit_target, caster_pid))
	if capture_tracker != null and caster_pid == 0:
		var _ct_board_after: int = _state.players[1].board.get_cards().size()
		capture_tracker.note_spell_resolved(0, _ct_board_before, _ct_board_after)

## Drains pending_auto_spells for the given player and resolves each.
## Called after any draw event (opening hand, turn draw).
func flush_auto_spells(player_idx: int) -> void:
	var player: PlayerState = _state.players[player_idx]
	while not player.pending_auto_spells.is_empty():
		var card: CardInstance = player.pending_auto_spells.pop_front() as CardInstance
		resolve_spell(card, player_idx)
