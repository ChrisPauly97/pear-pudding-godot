## Pure wire helper for the co-op Endless Spire alternating draft (GID-106 / TID-390).
##
## Mirrors LootRoll.gd's style: RefCounted, static functions, JSON-primitive payloads,
## fully-defaulted garbage-tolerant decoders. The authority broadcasts a draft-start
## prompt (3 card options + whose turn it is), the active picker's client submits a
## plain card_idx (no wire helper needed — mirrors submit_loot_roll_choice's
## plain-RPC-params precedent), and the authority broadcasts the resolved choice +
## the next picker's turn.
##
## Callers: preload("res://game_logic/net/SpireDraftSync.gd"). No scene dependencies.
extends RefCounted


# ---------------------------------------------------------------------------
# Wire format — authority -> all: open a draft prompt for a floor.
# ---------------------------------------------------------------------------

## Pack the draft-start broadcast. `options` are card template ids (3, floor-weighted).
static func encode_draft_start(
		floor: int, options: Array, active_picker_token: String,
		active_picker_name: String) -> Dictionary:
	var opts: Array = []
	for o in options:
		opts.append(str(o))
	return {
		"floor": int(floor),
		"options": opts,
		"active_picker_token": str(active_picker_token),
		"active_picker_name": str(active_picker_name),
	}


## Unpack a draft-start payload. Garbage/missing fields fall back to safe defaults.
static func decode_draft_start(payload: Variant) -> Dictionary:
	if not (payload is Dictionary):
		return {"floor": 0, "options": [], "active_picker_token": "", "active_picker_name": "Player"}
	var options: Variant = payload.get("options", [])
	var opts: Array = []
	if options is Array:
		for o in options:
			opts.append(str(o))
	return {
		"floor": int(payload.get("floor", 0)),
		"options": opts,
		"active_picker_token": str(payload.get("active_picker_token", "")),
		"active_picker_name": str(payload.get("active_picker_name", "Player")),
	}


# ---------------------------------------------------------------------------
# Wire format — authority -> all: the resolved pick + next picker's turn.
# ---------------------------------------------------------------------------

static func encode_draft_choice(
		card_id: String, next_active_picker_token: String,
		next_active_picker_name: String) -> Array:
	return [str(card_id), str(next_active_picker_token), str(next_active_picker_name)]


## Unpack a draft-choice broadcast. Garbage/short payload -> all-empty defaults
## (ignored by callers when card_id is blank).
static func decode_draft_choice(payload: Variant) -> Dictionary:
	if not (payload is Array) or payload.size() < 1:
		return {"card_id": "", "next_active_picker_token": "", "next_active_picker_name": "Player"}
	return {
		"card_id": str(payload[0]),
		"next_active_picker_token": str(payload[1]) if payload.size() > 1 else "",
		"next_active_picker_name": str(payload[2]) if payload.size() > 2 else "Player",
	}
