## Pure wire-format helpers for PvP card-battle networking (GID-091).
##
## Callers: preload("res://game_logic/net/BattleNetProtocol.gd")
## No scene dependencies — fully unit-testable without a live connection.
##
## Two payload families:
##  1. Intents — the client sends one human action to the host (reliable RPC).
##  2. State mirror — the host broadcasts the full canonical GameState.to_dict()
##     back to the client, wrapped with a monotonic `seq`.
##
## All payloads are JSON-primitive Dictionaries so they survive ENet RPC
## serialization. The host is authoritative: addressing is positional against the
## host's canonical state (hand_index, board slot index), never instance ids.
extends RefCounted

const VERSION: int = 1

# --- Intent type identifiers ---
const INTENT_PLAY_CARD_AT_SLOT: String = "play_card_at_slot"
const INTENT_PLAY_SPELL: String = "play_spell"
const INTENT_ATTACK: String = "attack"
const INTENT_END_TURN: String = "end_turn"
const INTENT_HERO_POWER: String = "hero_power"
const INTENT_POTION: String = "potion"
const INTENT_SURRENDER: String = "surrender"

# target_slot sentinel: an attack aimed at the enemy hero rather than a minion.
const TARGET_HERO: int = -1


# ---------------------------------------------------------------------------
# Intent encoders (client -> host)
# ---------------------------------------------------------------------------

## Play a minion from hand into a specific board slot.
static func encode_play_card_at_slot(hand_index: int, slot_idx: int) -> Dictionary:
	return {"v": VERSION, "type": INTENT_PLAY_CARD_AT_SLOT, "hand_index": hand_index, "slot_idx": slot_idx}


## Play a spell from hand. `target` is {} for untargeted, else {"side": int, "slot": int}.
## In N-player co-op battles, `target` may include `"pidx": int` to identify which ally's
## board/hero is targeted (defaults to -1 = boss/primary opponent).
static func encode_play_spell(hand_index: int, target: Dictionary = {}) -> Dictionary:
	return {"v": VERSION, "type": INTENT_PLAY_SPELL, "hand_index": hand_index, "target": target.duplicate()}


## Attack with a board minion. target_slot: -1 (TARGET_HERO) = enemy hero, 0..4 = enemy board slot.
## target_pidx: -1 = default opponent; in co-op, a non-negative value selects a specific ally as target.
static func encode_attack(attacker_slot: int, target_slot: int, target_pidx: int = -1) -> Dictionary:
	return {
		"v": VERSION, "type": INTENT_ATTACK,
		"attacker_slot": attacker_slot, "target_slot": target_slot,
		"target_pidx": target_pidx,
	}


## End the sender's turn.
static func encode_end_turn() -> Dictionary:
	return {"v": VERSION, "type": INTENT_END_TURN}


## Use the hero power. `target` is {} for untargeted, else {"side": int, "slot": int}.
## effect_type/effect_value carry the sender's own skill effect, since the host
## does not know the client's unlocked skills and must apply it authoritatively.
static func encode_hero_power(target: Dictionary = {}, effect_type: String = "", effect_value: int = 0) -> Dictionary:
	return {
		"v": VERSION, "type": INTENT_HERO_POWER, "target": target.duplicate(),
		"effect_type": effect_type, "effect_value": effect_value,
	}


## Use a consumable potion identified by potion_id.
static func encode_potion(potion_id: String) -> Dictionary:
	return {"v": VERSION, "type": INTENT_POTION, "potion_id": potion_id}


## Surrender / flee the battle (becomes a forfeit loss for the sender).
static func encode_surrender() -> Dictionary:
	return {"v": VERSION, "type": INTENT_SURRENDER}


# ---------------------------------------------------------------------------
# Intent decoder (host side)
# ---------------------------------------------------------------------------

## Decode any intent payload into a fully-defaulted dict. Garbage or unknown
## input yields type == "" so callers can safely no-op. Never throws.
## target_pidx: -1 = default opponent (boss in co-op, or only opponent in PvP/solo).
static func decode_intent(payload: Variant) -> Dictionary:
	var out: Dictionary = {
		"type": "",
		"hand_index": -1,
		"slot_idx": -1,
		"attacker_slot": -1,
		"target_slot": TARGET_HERO,
		"target_pidx": -1,
		"target": {},
		"potion_id": "",
		"effect_type": "",
		"effect_value": 0,
	}
	if not (payload is Dictionary):
		return out
	var d: Dictionary = payload
	var t: String = str(d.get("type", ""))
	match t:
		INTENT_PLAY_CARD_AT_SLOT:
			out["type"] = t
			out["hand_index"] = int(d.get("hand_index", -1))
			out["slot_idx"] = int(d.get("slot_idx", -1))
		INTENT_PLAY_SPELL:
			out["type"] = t
			out["hand_index"] = int(d.get("hand_index", -1))
			var tgt: Variant = d.get("target", {})
			out["target"] = (tgt as Dictionary).duplicate() if tgt is Dictionary else {}
		INTENT_ATTACK:
			out["type"] = t
			out["attacker_slot"] = int(d.get("attacker_slot", -1))
			out["target_slot"] = int(d.get("target_slot", TARGET_HERO))
			out["target_pidx"] = int(d.get("target_pidx", -1))
		INTENT_END_TURN:
			out["type"] = t
		INTENT_HERO_POWER:
			out["type"] = t
			var htgt: Variant = d.get("target", {})
			out["target"] = (htgt as Dictionary).duplicate() if htgt is Dictionary else {}
			out["effect_type"] = str(d.get("effect_type", ""))
			out["effect_value"] = int(d.get("effect_value", 0))
		INTENT_POTION:
			out["type"] = t
			out["potion_id"] = str(d.get("potion_id", ""))
		INTENT_SURRENDER:
			out["type"] = t
		_:
			pass  # unknown type → safe empty default
	return out


# ---------------------------------------------------------------------------
# Full-state mirror (host -> client)
# ---------------------------------------------------------------------------

## Wrap a GameState.to_dict() with a monotonic sequence number for the broadcast.
static func encode_state(state_dict: Dictionary, seq: int) -> Dictionary:
	return {"v": VERSION, "seq": seq, "state": state_dict.duplicate(true)}


## Unwrap a mirror payload. Returns {valid, seq, state}; valid == false on garbage.
static func decode_state(payload: Variant) -> Dictionary:
	if not (payload is Dictionary):
		return {"valid": false, "seq": -1, "state": {}}
	var d: Dictionary = payload
	if not d.has("state"):
		return {"valid": false, "seq": -1, "state": {}}
	var raw_state: Variant = d.get("state", {})
	if not (raw_state is Dictionary):
		return {"valid": false, "seq": -1, "state": {}}
	return {"valid": true, "seq": int(d.get("seq", 0)), "state": raw_state}
